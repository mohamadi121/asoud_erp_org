param(
    [switch]$ReuseFlutterPackages,
    [switch]$SkipRegressionGate
)

$ErrorActionPreference = 'Stop'
$infraRoot = Split-Path -Parent $PSScriptRoot
$phaseSevenGate = Join-Path $PSScriptRoot 'phase-seven-gate.ps1'
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

if ($pilotSite -ne 'asoud-pilot.localhost') {
    throw 'Pilot site safety invariant failed.'
}
if (-not $SkipRegressionGate) {
    & $phaseSevenGate -ReuseFlutterPackages:$ReuseFlutterPackages
    if ($LASTEXITCODE -ne 0) {
        throw 'Phase-one through phase-eight plus phase-seven regression gate failed.'
    }
}

Push-Location $infraRoot
try {
    $rootLine = Get-Content '.env' |
        Where-Object { $_ -match '^DB_ROOT_PASSWORD=' } |
        Select-Object -First 1
    if (-not $rootLine) {
        throw 'DB_ROOT_PASSWORD is missing from .env.'
    }
    $rootPassword = ($rootLine -split '=', 2)[1].Trim()
    $pilotPassword = 'Asoud!' + [Guid]::NewGuid().ToString('N')
    $siteExists = Invoke-ComposeCapture exec -T backend bash -lc `
        "if [ -d '/home/frappe/frappe-bench/sites/$pilotSite' ]; then printf yes; else printf no; fi"
    if ($siteExists -eq 'no') {
        Invoke-Compose exec -T backend bench new-site $pilotSite `
            --mariadb-user-host-login-scope='%' `
            --admin-password $pilotPassword `
            --db-root-username root `
            --db-root-password $rootPassword `
            --install-app erpnext
        Invoke-Compose exec -T backend bench --site $pilotSite install-app asoud_core
        Invoke-Compose exec -T backend bench --site $pilotSite install-app asoud_iran
        Invoke-Compose exec -T backend bench --site $pilotSite set-config developer_mode 0
    }
    Invoke-Compose exec -T backend bench --site $pilotSite migrate
    $firstRun = Invoke-ComposeCapture exec -T -e "ASOUD_DEMO_PASSWORD=$pilotPassword" backend `
        bench --site $pilotSite execute asoud_core.phase_nine_acceptance.run_controlled_pilot
    $secondRun = Invoke-ComposeCapture exec -T backend `
        bench --site $pilotSite execute asoud_core.phase_nine_acceptance.run_controlled_pilot
    if (
        $firstRun -notmatch '"status": "passed"' -or
        $firstRun -notmatch '"data_profile": "Synthetic"' -or
        $firstRun -notmatch '"decision": "Technical Go Only"' -or
        $secondRun -notmatch '"idempotency": "passed"'
    ) {
        throw "Controlled pilot contract failed.`nFirst: $firstRun`nSecond: $secondRun"
    }
    Invoke-Compose exec -T backend curl -fsS -H "Host: $pilotSite" `
        http://localhost:8000/api/method/ping

    $artifactRoot = Join-Path $infraRoot 'artifacts'
    New-Item -ItemType Directory -Force -Path $artifactRoot | Out-Null
    [ordered]@{
        schema_version = '1.0'
        generated_at_utc = [DateTime]::UtcNow.ToString('o')
        site = $pilotSite
        isolation = 'independent-site-and-database'
        data_profile = 'Synthetic'
        business_signoff = 'not-claimed'
        decision = 'Technical Go Only'
        first_run = ($firstRun | ConvertFrom-Json)
        repeat_run = ($secondRun | ConvertFrom-Json)
    } | ConvertTo-Json -Depth 20 |
        Set-Content -Encoding UTF8 -Path (Join-Path $artifactRoot 'phase-nine-uat.json')
} finally {
    $rootPassword = $null
    $pilotPassword = $null
    Pop-Location
}

& $restoreDrill -SourceSite $pilotSite
if ($LASTEXITCODE -ne 0) {
    throw 'Pilot-site isolated backup/restore drill failed.'
}

Write-Host 'ASOUD ERP phase-nine controlled synthetic pilot and technical UAT passed.'
