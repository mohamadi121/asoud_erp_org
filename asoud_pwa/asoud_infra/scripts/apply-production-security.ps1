param(
    [Parameter(Mandatory = $true)]
    [string]$Site,
    [Parameter(Mandatory = $true)]
    [string]$Origin
)

$ErrorActionPreference = 'Stop'
if ($Site -match 'localhost|[^a-zA-Z0-9.-]') {
    throw 'Production Site must be a safe non-localhost DNS name.'
}
if ($Origin -notmatch '^https://') {
    throw 'Production Origin must use HTTPS.'
}

$infraRoot = Split-Path -Parent $PSScriptRoot
Push-Location $infraRoot
try {
    docker compose exec -T backend bench --site $Site set-config developer_mode 0
    if ($LASTEXITCODE -ne 0) { throw 'Could not disable developer mode.' }
    docker compose exec -T backend bench --site $Site set-config host_name $Origin
    if ($LASTEXITCODE -ne 0) { throw 'Could not set canonical HTTPS origin.' }
    $result = docker compose exec -T backend bench --site $Site execute `
        asoud_core.services.production.apply_security_baseline `
        --kwargs "{'origin':'$Origin'}"
    if ($LASTEXITCODE -ne 0 -or $result -notmatch '"status": "applied"') {
        throw "Production security baseline failed: $result"
    }
    docker compose exec -T backend bench --site $Site clear-cache
    if ($LASTEXITCODE -ne 0) { throw 'Cache clear failed.' }
} finally {
    Pop-Location
}

Write-Host 'ASOUD ERP production security baseline applied.'
