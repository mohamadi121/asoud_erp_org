param(
    [switch]$ReuseFlutterPackages
)

$ErrorActionPreference = 'Stop'

$infraRoot = Split-Path -Parent $PSScriptRoot
$phaseOneGate = Join-Path $PSScriptRoot 'phase-one-gate.ps1'
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

& $phaseOneGate -ReuseFlutterPackages:$ReuseFlutterPackages
if ($LASTEXITCODE -ne 0) {
    throw 'Phase-one regression gate failed.'
}

Push-Location $infraRoot
try {
    $siteLine = Get-Content '.env' |
        Where-Object { $_ -match '^SITE_NAME=' } |
        Select-Object -First 1
    $siteName = if ($siteLine) {
        ($siteLine -split '=', 2)[1].Trim()
    } else {
        'asoud.localhost'
    }
    $demoPassword = 'Asoud!' + [Guid]::NewGuid().ToString('N')

    Invoke-Compose exec -T -e "ASOUD_DEMO_PASSWORD=$demoPassword" backend `
        bench --site $siteName execute asoud_core.phase_one_demo.ensure_phase_one_demo
    Invoke-Compose exec -T backend `
        bench --site $siteName execute asoud_iran.phase_two_acceptance.run_phase_two_acceptance

    $baseUrl = 'http://localhost:8080'
    $managerSession = New-Object Microsoft.PowerShell.Commands.WebRequestSession
    $null = Invoke-RestMethod -Uri "$baseUrl/api/method/login" -Method Post `
        -WebSession $managerSession `
        -Body @{ usr = 'company.manager@asoud.test'; pwd = $demoPassword }
    $contexts = Invoke-RestMethod `
        -Uri "$baseUrl/api/method/asoud_core.api.accessible_contexts" `
        -Method Get -WebSession $managerSession
    $selected = $contexts.message |
        Where-Object { $_.company -eq 'ASOUD Demo Trading' -and -not $_.branch } |
        Select-Object -First 1
    if (-not $selected) {
        throw 'Company manager has no company-wide phase-two context.'
    }
    $null = Invoke-RestMethod `
        -Uri "$baseUrl/api/method/asoud_core.api.set_active_context" `
        -Method Post -WebSession $managerSession `
        -Body @{ company = $selected.company }
    $settings = Invoke-RestMethod `
        -Uri "$baseUrl/api/method/asoud_iran.api.company_accounting_settings?company=ASOUD%20Demo%20Trading" `
        -Method Get -WebSession $managerSession
    if (
        $settings.message.setup_status -ne 'Completed' -or
        $settings.message.base_currency -ne 'IRR'
    ) {
        throw 'HTTP Iranian accounting settings are incomplete.'
    }
    $chart = Invoke-RestMethod `
        -Uri "$baseUrl/api/method/asoud_iran.api.company_chart_of_accounts?company=ASOUD%20Demo%20Trading" `
        -Method Get -WebSession $managerSession
    if ($chart.message.Count -ne 96) {
        throw 'HTTP chart of accounts does not contain the managed 96-account baseline.'
    }
    $amount = Invoke-RestMethod `
        -Uri "$baseUrl/api/method/asoud_iran.api.convert_amount?value=1250.5&input_unit=TOMAN&output_unit=IRR" `
        -Method Get -WebSession $managerSession
    if ($amount.message.ledger_amount -ne '12505') {
        throw 'HTTP Toman conversion failed.'
    }
    $calendar = Invoke-RestMethod `
        -Uri "$baseUrl/api/method/asoud_iran.api.from_jalali?jalali_date=1405-01-01" `
        -Method Get -WebSession $managerSession
    if ($calendar.message.gregorian -ne '2026-03-21') {
        throw 'HTTP Jalali conversion failed.'
    }
    $balance = Invoke-RestMethod `
        -Uri "$baseUrl/api/method/asoud_iran.api.accounting_trial_balance?company=ASOUD%20Demo%20Trading&from_date=2026-05-01&to_date=2026-05-31" `
        -Method Get -WebSession $managerSession
    $debit = ($balance.message | Measure-Object -Property debit -Sum).Sum
    $credit = ($balance.message | Measure-Object -Property credit -Sum).Sum
    if ([math]::Round($debit, 2) -ne [math]::Round($credit, 2)) {
        throw 'HTTP trial balance does not reconcile.'
    }

    $accountantSession = New-Object Microsoft.PowerShell.Commands.WebRequestSession
    $null = Invoke-RestMethod -Uri "$baseUrl/api/method/login" -Method Post `
        -WebSession $accountantSession `
        -Body @{ usr = 'accountant@asoud.test'; pwd = $demoPassword }
    $permitted = Invoke-RestMethod `
        -Uri "$baseUrl/api/method/asoud_iran.api.company_accounting_settings?company=ASOUD%20Demo%20Services" `
        -Method Get -WebSession $accountantSession
    if ($permitted.message.setup_status -ne 'Completed') {
        throw 'Limited accountant could not read the permitted company.'
    }
    $forbidden = $false
    try {
        $null = Invoke-RestMethod `
            -Uri "$baseUrl/api/method/asoud_iran.api.company_accounting_settings?company=ASOUD%20Demo%20Trading" `
            -Method Get -WebSession $accountantSession
    } catch {
        $forbidden = $true
    }
    if (-not $forbidden) {
        throw 'Limited accountant read a forbidden company through HTTP.'
    }
    Invoke-Compose exec -T frontend curl -fsS http://localhost:8080/api/method/ping
} finally {
    $demoPassword = $null
    Pop-Location
}

Write-Host 'ASOUD ERP phase-two gate passed.'
