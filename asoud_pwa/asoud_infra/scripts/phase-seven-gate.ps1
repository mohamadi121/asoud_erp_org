param(
    [switch]$ReuseFlutterPackages,
    [switch]$SkipRestoreDrill
)

$ErrorActionPreference = 'Stop'
$infraRoot = Split-Path -Parent $PSScriptRoot
$phaseEightGate = Join-Path $PSScriptRoot 'phase-eight-gate.ps1'
$restoreDrill = Join-Path $PSScriptRoot 'restore-drill.ps1'
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

& $phaseEightGate -ReuseFlutterPackages:$ReuseFlutterPackages -SkipRestoreDrill
if ($LASTEXITCODE -ne 0) {
    throw 'Phase-one through phase-eight regression gate failed.'
}

Push-Location $infraRoot
try {
    $siteLine = Get-Content '.env' |
        Where-Object { $_ -match '^SITE_NAME=' } |
        Select-Object -First 1
    $siteName = if ($siteLine) { ($siteLine -split '=', 2)[1].Trim() } else { 'asoud.localhost' }
    $demoPassword = 'Asoud!' + [Guid]::NewGuid().ToString('N')

    Invoke-Compose exec -T -e "ASOUD_DEMO_PASSWORD=$demoPassword" backend `
        bench --site $siteName execute asoud_core.phase_one_demo.ensure_phase_one_demo
    Invoke-Compose exec -T backend `
        bench --site $siteName execute asoud_core.phase_seven_acceptance.run_phase_seven_acceptance
    Invoke-Compose exec -T backend `
        bench --site $siteName execute asoud_core.phase_seven_acceptance.run_phase_seven_acceptance

    $baseUrl = 'http://localhost:8080'
    $managerSession = New-Object Microsoft.PowerShell.Commands.WebRequestSession
    $null = Invoke-RestMethod -Uri "$baseUrl/api/method/login" -Method Post `
        -WebSession $managerSession `
        -Body @{ usr = 'holding.manager@asoud.test'; pwd = $demoPassword }
    $query = 'holding=ASOUD-DEMO&from_date=2026-03-21&to_date=2027-03-20'
    $report = Invoke-RestMethod `
        -Uri "$baseUrl/api/method/asoud_core.api.holding_consolidation_report?$query" `
        -Method Get -WebSession $managerSession
    if (
        -not $report.message.controls.balanced -or
        $report.message.companies.Count -lt 2 -or
        $report.message.eliminations.Count -lt 2 -or
        $report.message.unmapped.Count -ne 0
    ) {
        throw 'HTTP holding consolidation did not reconcile.'
    }

    $limitedSession = New-Object Microsoft.PowerShell.Commands.WebRequestSession
    $null = Invoke-RestMethod -Uri "$baseUrl/api/method/login" -Method Post `
        -WebSession $limitedSession `
        -Body @{ usr = 'accountant@asoud.test'; pwd = $demoPassword }
    $denied = $false
    try {
        $null = Invoke-RestMethod `
            -Uri "$baseUrl/api/method/asoud_core.api.holding_consolidation_report?$query" `
            -Method Get -WebSession $limitedSession -ErrorAction Stop
    } catch {
        $statusCode = [int]$_.Exception.Response.StatusCode
        if ($statusCode -in @(403, 417)) {
            $denied = $true
        } else {
            throw
        }
    }
    if (-not $denied) {
        throw 'Limited accountant accessed holding consolidation over HTTP.'
    }
    Invoke-Compose exec -T frontend curl -fsS http://localhost:8080/api/method/ping
} finally {
    $demoPassword = $null
    Pop-Location
}

if (-not $SkipRestoreDrill) {
    & $restoreDrill
    if ($LASTEXITCODE -ne 0) {
        throw 'Phase-seven backup/restore drill failed.'
    }
}

Write-Host 'ASOUD ERP phase-seven intercompany and consolidation gate passed.'
