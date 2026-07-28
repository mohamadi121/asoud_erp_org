param(
    [switch]$ReuseFlutterPackages,
    [switch]$SkipRegressionGate,
    [switch]$SkipRestoreDrill
)

$ErrorActionPreference = 'Stop'
$infraRoot = Split-Path -Parent $PSScriptRoot
$phaseNine = Join-Path $PSScriptRoot 'phase-nine-pilot.ps1'
$restoreDrill = Join-Path $PSScriptRoot 'restore-drill.ps1'
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
    & $phaseNine -ReuseFlutterPackages:$ReuseFlutterPackages
    if ($LASTEXITCODE -ne 0) {
        throw 'Regression through controlled phase-nine failed.'
    }
}

Push-Location $infraRoot
try {
    $previousEnvironment = @{
        ASOUD_DOMAIN = $env:ASOUD_DOMAIN
        TLS_EMAIL = $env:TLS_EMAIL
        ASOUD_IMAGE = $env:ASOUD_IMAGE
        ASOUD_IMAGE_TAG = $env:ASOUD_IMAGE_TAG
        REDIS_PASSWORD = $env:REDIS_PASSWORD
    }
    $env:ASOUD_DOMAIN = 'erp.acceptance.invalid'
    $env:TLS_EMAIL = 'ops@acceptance.invalid'
    $env:ASOUD_IMAGE = 'asoud/erpnext'
    $env:ASOUD_IMAGE_TAG = 'v0.10.0'
    $env:REDIS_PASSWORD = 'phase-gate-only-not-a-real-secret'
    & $composeExecutable @composePrefix -f compose.yaml `
        -f compose.production.yaml config --quiet
    if ($LASTEXITCODE -ne 0) {
        throw 'Production Compose overlay validation failed.'
    }
    foreach ($name in $previousEnvironment.Keys) {
        if ($null -eq $previousEnvironment[$name]) {
            Remove-Item -Path "Env:$name" -ErrorAction SilentlyContinue
        } else {
            Set-Item -Path "Env:$name" -Value $previousEnvironment[$name]
        }
    }
    Invoke-Compose exec -T backend bench --site $pilotSite migrate
    $first = Invoke-ComposeCapture exec -T backend bench --site $pilotSite execute `
        asoud_core.phase_ten_thirteen_acceptance.run_acceptance
    $second = Invoke-ComposeCapture exec -T backend bench --site $pilotSite execute `
        asoud_core.phase_ten_thirteen_acceptance.run_acceptance
    if (
        $first -notmatch '"status": "passed"' -or
        $first -notmatch '"migration_decision": "Technical Ready"' -or
        $first -notmatch '"cutover_decision": "Technical Ready"' -or
        $first -notmatch '"production_go": false' -or
        $second -notmatch '"status": "passed"'
    ) {
        throw "Phase 10-13 technical acceptance failed.`nFirst: $first`nSecond: $second"
    }
    Invoke-Compose exec -T backend curl -fsS -H "Host: $pilotSite" `
        http://localhost:8000/api/method/ping

    $artifactRoot = Join-Path $infraRoot 'artifacts'
    New-Item -ItemType Directory -Force -Path $artifactRoot | Out-Null
    [ordered]@{
        schema_version = '1.0'
        generated_at_utc = [DateTime]::UtcNow.ToString('o')
        site = $pilotSite
        decision = 'Technical Ready'
        production_go = $false
        business_signoff = 'not-claimed'
        first_run = ($first | ConvertFrom-Json)
        repeat_run = ($second | ConvertFrom-Json)
    } | ConvertTo-Json -Depth 20 |
        Set-Content -Encoding UTF8 -Path `
            (Join-Path $artifactRoot 'phase-ten-thirteen-technical-readiness.json')
} finally {
    Pop-Location
}

if (-not $SkipRestoreDrill) {
    & $restoreDrill -SourceSite $pilotSite
    if ($LASTEXITCODE -ne 0) {
        throw 'Phase 10-13 restore drill failed.'
    }
}

Write-Host 'ASOUD ERP phases 10-13 technical readiness gate passed.'
