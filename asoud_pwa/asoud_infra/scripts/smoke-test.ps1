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

$siteLine = Get-Content '.env' | Where-Object { $_ -match '^SITE_NAME=' } | Select-Object -First 1
$siteName = if ($siteLine) { ($siteLine -split '=', 2)[1].Trim() } else { 'asoud.localhost' }
$apps = Invoke-Compose exec -T backend bench --site $siteName list-apps
if ($LASTEXITCODE -ne 0) { throw 'Unable to read installed apps.' }
$appsText = $apps -join "`n"
foreach ($required in @('frappe', 'erpnext', 'asoud_core', 'asoud_iran', 'asoud_hr')) {
    if ($appsText -notmatch "(?m)^$required\s") { throw "Required app is not installed: $required" }
}
Invoke-Compose exec -T backend bench --site $siteName migrate
Assert-NativeSuccess 'Site migration'
Invoke-Compose exec -T frontend curl -fsS http://localhost:8080/api/method/ping
Assert-NativeSuccess 'Frontend health endpoint'
Write-Host 'Smoke test passed.'
