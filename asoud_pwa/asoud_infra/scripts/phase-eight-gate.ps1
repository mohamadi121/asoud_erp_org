param(
    [switch]$ReuseFlutterPackages,
    [switch]$SkipRestoreDrill
)

$ErrorActionPreference = 'Stop'
$infraRoot = Split-Path -Parent $PSScriptRoot
$phaseSixGate = Join-Path $PSScriptRoot 'phase-six-gate.ps1'
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

& $phaseSixGate -ReuseFlutterPackages:$ReuseFlutterPackages
if ($LASTEXITCODE -ne 0) {
    throw 'Phase-one through phase-six regression gate failed.'
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
        bench --site $siteName execute asoud_iran.phase_eight_acceptance.run_phase_eight_acceptance
    Invoke-Compose exec -T backend `
        bench --site $siteName execute asoud_iran.phase_eight_acceptance.run_phase_eight_acceptance

    $baseUrl = 'http://localhost:8080'
    $managerSession = New-Object Microsoft.PowerShell.Commands.WebRequestSession
    $null = Invoke-RestMethod -Uri "$baseUrl/api/method/login" -Method Post `
        -WebSession $managerSession `
        -Body @{ usr = 'company.manager@asoud.test'; pwd = $demoPassword }
    $reportQuery = @{
        company = 'ASOUD Demo Trading'
        branch = 'ASOUD Demo Trading-HQ'
        report_type = 'trial_balance'
        from_date = '2026-03-21'
        to_date = '2027-05-31'
    }
    $queryString = ($reportQuery.GetEnumerator() | ForEach-Object {
        [Uri]::EscapeDataString($_.Key) + '=' + [Uri]::EscapeDataString($_.Value)
    }) -join '&'
    $report = Invoke-RestMethod `
        -Uri "$baseUrl/api/method/asoud_iran.api.standard_accounting_report?$queryString" `
        -Method Get -WebSession $managerSession
    if (
        $report.message.schema_version -ne '1.0' -or
        $report.message.checksum.Length -ne 64 -or
        $report.message.totals.period_debit -ne $report.message.totals.period_credit
    ) {
        throw 'HTTP canonical trial-balance contract did not reconcile.'
    }
    foreach ($format in @('csv', 'xlsx', 'pdf')) {
        $download = Invoke-WebRequest `
            -Uri "$baseUrl/api/method/asoud_iran.api.export_accounting_report?$queryString&file_format=$format" `
            -Method Get -WebSession $managerSession -UseBasicParsing
        if ($download.StatusCode -ne 200 -or $download.RawContentLength -lt 100) {
            throw "HTTP $format accounting export is invalid."
        }
    }

    $limitedSession = New-Object Microsoft.PowerShell.Commands.WebRequestSession
    $null = Invoke-RestMethod -Uri "$baseUrl/api/method/login" -Method Post `
        -WebSession $limitedSession `
        -Body @{ usr = 'accountant@asoud.test'; pwd = $demoPassword }
    $denied = $false
    try {
        $null = Invoke-RestMethod `
            -Uri "$baseUrl/api/method/asoud_iran.api.standard_accounting_report?$queryString" `
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
        throw 'Forbidden-company HTTP report was not denied.'
    }
    Invoke-Compose exec -T frontend curl -fsS http://localhost:8080/api/method/ping
} finally {
    $demoPassword = $null
    Pop-Location
}

if (-not $SkipRestoreDrill) {
    & $restoreDrill
    if ($LASTEXITCODE -ne 0) {
        throw 'Isolated backup/restore drill failed.'
    }
}

Write-Host 'ASOUD ERP phase-eight reporting and pilot-readiness gate passed.'
