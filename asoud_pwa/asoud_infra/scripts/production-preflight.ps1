param(
    [string]$EnvironmentFile = '.env.production',
    [switch]$AllowLocalhost
)

$ErrorActionPreference = 'Stop'
$infraRoot = Split-Path -Parent $PSScriptRoot
$environmentPath = Join-Path $infraRoot $EnvironmentFile

if (-not (Test-Path -LiteralPath $environmentPath)) {
    throw "Production environment file not found: $environmentPath"
}

$values = @{}
Get-Content -LiteralPath $environmentPath | ForEach-Object {
    if ($_ -match '^\s*([^#][^=]+)=(.*)$') {
        $values[$matches[1].Trim()] = $matches[2].Trim()
    }
}

$required = 'SITE_NAME','ASOUD_DOMAIN','TLS_EMAIL','ASOUD_IMAGE',
    'ASOUD_IMAGE_TAG','DB_ROOT_PASSWORD','ADMIN_PASSWORD','REDIS_PASSWORD'
foreach ($name in $required) {
    if (-not $values.ContainsKey($name) -or [string]::IsNullOrWhiteSpace($values[$name])) {
        throw "$name is required."
    }
    if ($values[$name] -match 'replace-|changeme|example-secret') {
        throw "$name still contains a placeholder."
    }
}
if (-not $AllowLocalhost -and (
    $values['ASOUD_DOMAIN'] -match 'localhost|example\.' -or
    $values['SITE_NAME'] -match 'localhost|example\.'
)) {
    throw 'Production domain and Site name must not be localhost or an example domain.'
}
if ($values['ASOUD_IMAGE_TAG'] -match 'latest|dev') {
    throw 'Production image must use an immutable release tag, never latest/dev.'
}
if ($values['DB_ROOT_PASSWORD'].Length -lt 20 -or $values['REDIS_PASSWORD'].Length -lt 20) {
    throw 'Database and Redis secrets must contain at least 20 characters.'
}

Push-Location $infraRoot
try {
    docker compose -f compose.yaml -f compose.production.yaml `
        --env-file $EnvironmentFile config --quiet
    if ($LASTEXITCODE -ne 0) {
        throw 'Merged production Compose configuration is invalid.'
    }
} finally {
    Pop-Location
}

Write-Host 'ASOUD ERP production preflight passed. No deployment was performed.'
