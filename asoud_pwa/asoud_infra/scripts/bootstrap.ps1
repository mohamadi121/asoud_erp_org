$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot
$composeExecutable = if (Get-Command docker-compose -ErrorAction SilentlyContinue) {
    'docker-compose'
} else {
    'docker'
}
$composePrefix = if ($composeExecutable -eq 'docker') { @('compose') } else { @() }
function Invoke-Compose { & $composeExecutable @composePrefix @args }
function Assert-NativeSuccess([string]$operation) {
    if ($LASTEXITCODE -ne 0) { throw "$operation failed with exit code $LASTEXITCODE." }
}

if (-not (Test-Path '.env')) {
    Copy-Item '.env.example' '.env'
    Write-Warning 'Created .env. Replace all change-me values before continuing.'
    exit 1
}

if (Select-String -Path '.env' -Pattern 'change-me' -Quiet) {
    throw 'Replace all change-me values in .env before starting the stack.'
}

Invoke-Compose config --quiet
Assert-NativeSuccess 'Compose configuration validation'
Invoke-Compose build backend
Assert-NativeSuccess 'ERPNext image build'
Invoke-Compose up -d db redis-cache redis-queue configurator
Assert-NativeSuccess 'Infrastructure/configurator startup'

$siteLine = Get-Content '.env' | Where-Object { $_ -match '^SITE_NAME=' } | Select-Object -First 1
$siteName = if ($siteLine) { ($siteLine -split '=', 2)[1].Trim() } else { 'asoud.localhost' }
Invoke-Compose run --rm --no-deps backend bash -lc "test -f sites/$siteName/site_config.json"
if ($LASTEXITCODE -ne 0) {
    Invoke-Compose --profile setup run --rm create-site
    if ($LASTEXITCODE -ne 0) { throw 'Site creation failed.' }
}

Invoke-Compose up -d backend websocket queue-short queue-long scheduler frontend
Assert-NativeSuccess 'Application service startup'
Invoke-Compose exec -T backend bench --site $siteName migrate
Assert-NativeSuccess 'Site migration'
Invoke-Compose exec -T backend bench --site $siteName list-apps
Assert-NativeSuccess 'Installed app verification'
Write-Host "ASOUD ERP is ready at http://localhost:8080 (site: $siteName)"
