param(
    [switch]$SkipRegressionGate,
    [switch]$ReuseFlutterPackages,
    [switch]$SkipRestoreDrill
)

$ErrorActionPreference = 'Stop'
$infraRoot = Split-Path -Parent $PSScriptRoot
$pilotSite = 'asoud-pilot.localhost'
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

function Invoke-ComposeCapture {
    $output = & $composeExecutable @composePrefix @args
    if ($LASTEXITCODE -ne 0) {
        throw "Docker Compose command failed: $($args -join ' ')"
    }
    return ($output | Out-String).Trim()
}

if (-not $SkipRegressionGate) {
    & (Join-Path $PSScriptRoot 'phase-ten-thirteen-gate.ps1') `
        -ReuseFlutterPackages:$ReuseFlutterPackages -SkipRestoreDrill
    if ($LASTEXITCODE -ne 0) {
        throw 'Regression through phase thirteen failed.'
    }
}

Push-Location $infraRoot
try {
    Invoke-Compose build backend
    Invoke-Compose up -d
    Invoke-Compose exec -T backend bench --site $pilotSite migrate
    $first = Invoke-ComposeCapture exec -T backend bench --site $pilotSite execute `
        asoud_core.phase_fourteen_sixteen_acceptance.run_acceptance
    $second = Invoke-ComposeCapture exec -T backend bench --site $pilotSite execute `
        asoud_core.phase_fourteen_sixteen_acceptance.run_acceptance
    if ($first -notmatch '"status": "passed"' -or $second -notmatch '"status": "passed"') {
        throw "Phase 14-16 acceptance failed.`nFirst: $first`nSecond: $second"
    }
    $artifactRoot = Join-Path $infraRoot 'artifacts'
    New-Item -ItemType Directory -Force -Path $artifactRoot | Out-Null
    [ordered]@{
        schema_version = '1.0'
        generated_at_utc = [DateTime]::UtcNow.ToString('o')
        site = $pilotSite
        status = 'passed'
        production_connectivity_claimed = $false
        first_run = ($first | ConvertFrom-Json)
        repeat_run = ($second | ConvertFrom-Json)
    } | ConvertTo-Json -Depth 30 |
        Set-Content -Encoding UTF8 -Path `
            (Join-Path $artifactRoot 'phase-fourteen-sixteen-readiness.json')
} finally {
    Pop-Location
}

if (-not $SkipRestoreDrill) {
    & (Join-Path $PSScriptRoot 'restore-drill.ps1') -SourceSite $pilotSite
    if ($LASTEXITCODE -ne 0) {
        throw 'Phase 14-16 restore drill failed.'
    }
}

Write-Host 'ASOUD ERP phases 14-16 technical gate passed.'
