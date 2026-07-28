param(
    [switch]$ReuseFlutterPackages
)

$ErrorActionPreference = 'Stop'

$infraRoot = Split-Path -Parent $PSScriptRoot
$workspaceRoot = Split-Path -Parent $infraRoot
$coreRoot = Join-Path $workspaceRoot 'asoud_core'
$iranRoot = Join-Path $workspaceRoot 'asoud_iran'
$pwaRoot = Join-Path $workspaceRoot 'asoud_pwa'
$composeExecutable = if (Get-Command docker-compose -ErrorAction SilentlyContinue) {
    'docker-compose'
} else {
    'docker'
}
$composePrefix = if ($composeExecutable -eq 'docker') { @('compose') } else { @() }

function Invoke-Checked {
    param(
        [Parameter(Mandatory)]
        [scriptblock]$Command,
        [Parameter(Mandatory)]
        [string]$FailureMessage
    )
    & $Command
    if ($LASTEXITCODE -ne 0) {
        throw $FailureMessage
    }
}

function Invoke-Compose {
    & $composeExecutable @composePrefix @args
    if ($LASTEXITCODE -ne 0) {
        throw "Docker Compose command failed: $($args -join ' ')"
    }
}

Push-Location $coreRoot
try {
    Invoke-Checked { python -m compileall -q asoud_core tests } 'ASOUD Core compilation failed.'
    Invoke-Checked { python -m pytest } 'ASOUD Core unit tests failed.'
} finally {
    Pop-Location
}

Push-Location $iranRoot
try {
    Invoke-Checked { python -m compileall -q asoud_iran tests } 'ASOUD Iran compilation failed.'
    Invoke-Checked { python -m pytest } 'ASOUD Iran unit tests failed.'
} finally {
    Pop-Location
}

Push-Location $pwaRoot
try {
    if (-not $ReuseFlutterPackages) {
        Invoke-Checked { flutter pub get } 'Flutter dependency resolution failed.'
    } elseif (-not (Test-Path '.dart_tool/package_config.json')) {
        throw 'Resolved Flutter packages are unavailable; run without -ReuseFlutterPackages.'
    }
    Invoke-Checked {
        dart format --output=none --set-exit-if-changed lib test
    } 'Dart formatting check failed.'
    Invoke-Checked { flutter analyze --no-pub } 'Flutter analysis failed.'
    Invoke-Checked { flutter test --no-pub } 'Flutter tests failed.'
    Invoke-Checked {
        flutter build web --release --pwa-strategy=none --no-pub
    } 'Flutter web release build failed.'
} finally {
    Pop-Location
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
        bench --site $siteName execute asoud_core.phase_one_acceptance.run_phase_one_acceptance
    Invoke-Compose exec -T backend `
        bench --site $siteName execute asoud_iran.phase_one_acceptance.run_phase_one_acceptance

    $webSession = New-Object Microsoft.PowerShell.Commands.WebRequestSession
    $baseUrl = 'http://localhost:8080'
    $null = Invoke-RestMethod -Uri "$baseUrl/api/method/login" -Method Post `
        -WebSession $webSession `
        -Body @{ usr = 'branch.manager@asoud.test'; pwd = $demoPassword }
    $contexts = Invoke-RestMethod `
        -Uri "$baseUrl/api/method/asoud_core.api.accessible_contexts" `
        -Method Get -WebSession $webSession
    if ($contexts.message.Count -ne 1) {
        throw 'The branch manager must receive exactly one work context.'
    }
    $selected = $contexts.message[0]
    $null = Invoke-RestMethod `
        -Uri "$baseUrl/api/method/asoud_core.api.set_active_context" `
        -Method Post -WebSession $webSession `
        -Body @{ company = $selected.company; branch = $selected.branch }
    $active = Invoke-RestMethod `
        -Uri "$baseUrl/api/method/asoud_core.api.active_context" `
        -Method Get -WebSession $webSession
    if (
        $active.message.company -ne $selected.company -or
        $active.message.branch -ne $selected.branch
    ) {
        throw 'The HTTP active-context round trip failed.'
    }
    Invoke-Compose exec -T frontend curl -fsS http://localhost:8080/api/method/ping
} finally {
    $demoPassword = $null
    Pop-Location
}

Write-Host 'ASOUD ERP phase-one gate passed.'
