$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot
$env:DB_ROOT_PASSWORD = 'validation-only'
$env:ADMIN_PASSWORD = 'validation-only'
docker compose -f compose.yaml config --quiet
Write-Host 'Compose configuration is valid.'

