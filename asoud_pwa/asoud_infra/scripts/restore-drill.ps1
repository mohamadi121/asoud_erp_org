param(
    [string]$SourceSite
)

$ErrorActionPreference = 'Stop'
$infraRoot = Split-Path -Parent $PSScriptRoot
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

Push-Location $infraRoot
try {
    if (-not $SourceSite) {
        $siteLine = Get-Content '.env' |
            Where-Object { $_ -match '^SITE_NAME=' } |
            Select-Object -First 1
        $SourceSite = if ($siteLine) {
            ($siteLine -split '=', 2)[1].Trim()
        } else {
            'asoud.localhost'
        }
    }
    $rootLine = Get-Content '.env' |
        Where-Object { $_ -match '^DB_ROOT_PASSWORD=' } |
        Select-Object -First 1
    if (-not $rootLine) {
        throw 'DB_ROOT_PASSWORD is missing from .env.'
    }
    $rootPassword = ($rootLine -split '=', 2)[1].Trim()
    $targetSite = 'asoud-restore-' + [Guid]::NewGuid().ToString('N') + '.localhost'
    if ($targetSite -notmatch '^asoud-restore-[0-9a-f]{32}\.localhost$') {
        throw 'Generated restore target is unsafe.'
    }

    $sourceFingerprint = Invoke-ComposeCapture exec -T backend `
        bench --site $SourceSite execute `
        asoud_iran.restore_verification.restoration_fingerprint
    Invoke-Compose exec -T backend bench --site $SourceSite backup --with-files --compress
    $backupRoot = "/home/frappe/frappe-bench/sites/$SourceSite/private/backups"
    $databaseBackup = Invoke-ComposeCapture exec -T backend bash -lc `
        "ls -1t '$backupRoot'/*-database.sql.gz | head -n 1"
    $publicBackup = Invoke-ComposeCapture exec -T backend bash -lc `
        "ls -1t '$backupRoot'/*-files.tgz | head -n 1"
    $privateBackup = Invoke-ComposeCapture exec -T backend bash -lc `
        "ls -1t '$backupRoot'/*-private-files.tgz | head -n 1"
    if (
        -not $databaseBackup.StartsWith($backupRoot) -or
        -not $publicBackup.StartsWith($backupRoot) -or
        -not $privateBackup.StartsWith($backupRoot)
    ) {
        throw 'Backup paths escaped the expected site backup directory.'
    }

    try {
        Invoke-Compose exec -T backend bench new-site $targetSite `
            --mariadb-user-host-login-scope='%' `
            --admin-password ([Guid]::NewGuid().ToString('N')) `
            --db-root-username root `
            --db-root-password $rootPassword
        Invoke-Compose exec -T backend bench --site $targetSite restore `
            $databaseBackup `
            --with-public-files $publicBackup `
            --with-private-files $privateBackup `
            --db-root-username root `
            --db-root-password $rootPassword `
            --force
        Invoke-Compose exec -T backend bench --site $targetSite migrate
        $restoredFingerprint = Invoke-ComposeCapture exec -T backend `
            bench --site $targetSite execute `
            asoud_iran.restore_verification.restoration_fingerprint
        if ($sourceFingerprint -ne $restoredFingerprint) {
            throw "Restored fingerprint mismatch.`nSource: $sourceFingerprint`nRestored: $restoredFingerprint"
        }
    } finally {
        if ($targetSite -match '^asoud-restore-[0-9a-f]{32}\.localhost$') {
            Invoke-Compose exec -T backend bench drop-site $targetSite `
                --db-root-username root `
                --db-root-password $rootPassword `
                --force `
                --no-backup
        }
    }
} finally {
    $rootPassword = $null
    Pop-Location
}

Write-Host 'ASOUD ERP backup and isolated restore drill passed.'
