$ErrorActionPreference = 'Stop'
$infraRoot = Split-Path -Parent $PSScriptRoot
Set-Location $infraRoot
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

$siteLine = Get-Content '.env' |
    Where-Object { $_ -match '^SITE_NAME=' } |
    Select-Object -First 1
$siteName = if ($siteLine) {
    ($siteLine -split '=', 2)[1].Trim()
} else {
    'asoud.localhost'
}

Invoke-Compose exec -T backend bench --site $siteName migrate
$result = Invoke-Compose exec -T backend `
    bench --site $siteName execute asoud_hr.acceptance.run_hr_acceptance
$text = $result -join "`n"
if ($text -notmatch '["'']status["'']\s*:\s*["'']passed["'']') {
    throw 'ASOUD HR metadata acceptance did not pass.'
}
Invoke-Compose exec -T frontend curl -fsS http://localhost:8080/api/method/ping
Write-Host 'ASOUD HR technical gate passed.'
