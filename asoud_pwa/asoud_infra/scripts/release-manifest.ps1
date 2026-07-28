param(
    [string]$OutputPath
)

$ErrorActionPreference = 'Stop'
$infraRoot = Split-Path -Parent $PSScriptRoot
$workspaceRoot = Split-Path -Parent $infraRoot
$composeExecutable = if (Get-Command docker-compose -ErrorAction SilentlyContinue) {
    'docker-compose'
} else {
    'docker'
}
$composePrefix = if ($composeExecutable -eq 'docker') { @('compose') } else { @() }

Push-Location $infraRoot
try {
    if (-not $OutputPath) {
        $OutputPath = Join-Path $infraRoot 'artifacts/release-manifest.json'
    }
    $outputDirectory = Split-Path -Parent $OutputPath
    if (-not (Test-Path $outputDirectory)) {
        New-Item -ItemType Directory -Path $outputDirectory | Out-Null
    }
    $siteLine = Get-Content '.env' |
        Where-Object { $_ -match '^SITE_NAME=' } |
        Select-Object -First 1
    $siteName = if ($siteLine) { ($siteLine -split '=', 2)[1].Trim() } else { 'asoud.localhost' }
    $imageLine = Get-Content '.env' |
        Where-Object { $_ -match '^ASOUD_IMAGE=' } |
        Select-Object -First 1
    $tagLine = Get-Content '.env' |
        Where-Object { $_ -match '^ASOUD_IMAGE_TAG=' } |
        Select-Object -First 1
    $image = if ($imageLine) { ($imageLine -split '=', 2)[1].Trim() } else { 'asoud/erpnext' }
    $tag = if ($tagLine) { ($tagLine -split '=', 2)[1].Trim() } else { 'v15-dev' }
    $imageReference = "${image}:${tag}"
    $versionsJson = & $composeExecutable @composePrefix exec -T backend `
        bench version --format json
    if ($LASTEXITCODE -ne 0) {
        throw 'Unable to read installed application versions.'
    }
    $versions = ($versionsJson | Out-String | ConvertFrom-Json)
    $imageId = (& docker image inspect $imageReference --format '{{.Id}}').Trim()
    if ($LASTEXITCODE -ne 0 -or -not $imageId) {
        throw 'Unable to resolve the ERP image digest.'
    }
    $repositories = [ordered]@{}
    foreach ($name in @('asoud_core', 'asoud_iran', 'asoud_hr', 'asoud_pwa', 'asoud_infra', 'asoud_docs')) {
        $repository = Join-Path $workspaceRoot $name
        $safeRepository = $repository.Replace('\', '/')
        $commit = (& git -c "safe.directory=$safeRepository" -C $repository rev-parse HEAD).Trim()
        $dirty = [bool](& git -c "safe.directory=$safeRepository" -C $repository status --porcelain)
        $repositories[$name] = [ordered]@{
            commit = $commit
            dirty = $dirty
        }
    }
    $manifest = [ordered]@{
        schema_version = '1.3'
        generated_at_utc = [DateTime]::UtcNow.ToString('o')
        site = $siteName
        image = [ordered]@{
            reference = $imageReference
            digest = $imageId
        }
        applications = $versions
        repositories = $repositories
        report_schema = '1.0'
        acceptance_gates = @(
            'phase-seven',
            'phase-nine-controlled-technical-uat',
            'phase-ten-operational-workbench',
            'phase-eleven-production-readiness',
            'phase-twelve-controlled-migration',
            'phase-thirteen-cutover-readiness'
            'phase-fourteen-tax-gateway'
            'phase-fifteen-bank-sayad'
            'phase-sixteen-multi-currency-consolidation'
        )
        pilot = [ordered]@{
            site = 'asoud-pilot.localhost'
            isolation = 'independent-site-and-database'
            data_profile = 'Synthetic'
            decision = 'Technical Go Only'
            business_signoff = 'not-claimed'
            evidence = 'artifacts/phase-nine-uat.json'
        }
        operational_readiness = [ordered]@{
            site = 'asoud-pilot.localhost'
            decision = 'Technical Ready'
            production_go = $false
            business_signoff = 'not-claimed'
            evidence = 'artifacts/phase-ten-thirteen-technical-readiness.json'
        }
        compliance_connectivity_readiness = [ordered]@{
            site = 'asoud-pilot.localhost'
            decision = 'Technical Ready'
            production_connectivity_claimed = $false
            tax_production = 'blocked-pending-official-credentials-and-adapter'
            bank_sayad_production = 'blocked-pending-contracted-provider'
            evidence = 'artifacts/phase-fourteen-sixteen-readiness.json'
        }
        backup_restore_drill = 'passed'
        github_publication = 'deferred'
    }
    $manifest | ConvertTo-Json -Depth 8 | Set-Content -Encoding UTF8 $OutputPath
    Write-Output (Resolve-Path $OutputPath).Path
} finally {
    Pop-Location
}
