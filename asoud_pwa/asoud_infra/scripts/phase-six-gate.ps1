param(
    [switch]$ReuseFlutterPackages
)

$ErrorActionPreference = 'Stop'
$infraRoot = Split-Path -Parent $PSScriptRoot
$phaseFiveGate = Join-Path $PSScriptRoot 'phase-five-gate.ps1'
$composeExecutable = if (Get-Command docker-compose -ErrorAction SilentlyContinue) {
    'docker-compose'
} else {
    'docker'
}
$composePrefix = if ($composeExecutable -eq 'docker') { @('compose') } else { @() }

function Invoke-Compose {
    & $composeExecutable @composePrefix @args
    if ($LASTEXITCODE -ne 0) {
        throw "Docker Compose command failed: $($args -join ' ')"
    }
}

& $phaseFiveGate -ReuseFlutterPackages:$ReuseFlutterPackages
if ($LASTEXITCODE -ne 0) {
    throw 'Phase-one through phase-five regression gate failed.'
}

Push-Location $infraRoot
try {
    $siteLine = Get-Content '.env' |
        Where-Object { $_ -match '^SITE_NAME=' } |
        Select-Object -First 1
    $siteName = if ($siteLine) { ($siteLine -split '=', 2)[1].Trim() } else { 'asoud.localhost' }

    Invoke-Compose exec -T backend `
        bench --site $siteName execute asoud_core.phase_six_acceptance.run_phase_six_acceptance
    Invoke-Compose exec -T backend `
        bench --site $siteName execute asoud_core.phase_six_acceptance.run_phase_six_acceptance
    Invoke-Compose exec -T frontend curl -fsS http://localhost:8080/api/method/ping
} finally {
    Pop-Location
}

Write-Host 'ASOUD ERP phase-six treasury gate passed twice without duplicate records.'
