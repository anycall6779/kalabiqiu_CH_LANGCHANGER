$ErrorActionPreference = 'Stop'

$workRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $workRoot 'optimization_common.ps1')
$gameRoot = Get-CalabiyauGameRoot -StartPath $workRoot

$source = Join-Path $workRoot 'optimized_patch_stage\PM\Content\Localization\Game\zh-Hans\Game.locres'
$targetDir = Join-Path $gameRoot 'PM\Content\Localization\Game\zh-Hans'
$target = Join-Path $targetDir 'Game.locres'
$expectedHash = '835B5159EB84AA90D0F79E1CC273313BC17FFEE9BEE900E887EF1DD35049FC2F'
$previousPatchHash = 'D437B9AA79152009DE29C505E66ED7A78ED626BF893D6953B3480E8AA54B690A'
$standardHash = '4952F688A36582A76B6A28248D4BA4C3A309C3B2E12ADD736597679835A7DD74'
$blockedPak = Join-Path $gameRoot 'PM\Content\Paks\Game_Patch_WindowsNoEditor_999_P.pak'
$engineIni = Get-CalabiyauEngineIniPath
$statePath = Join-Path $workRoot 'optimization_state.json'

Assert-CalabiyauStopped

$version = (Get-Content -LiteralPath (Join-Path $gameRoot 'Version.txt') -Raw).Trim()
if ($version -ne '775419') {
    throw "This one-time loose patch targets China version 775419; installed version is $version."
}
if (Test-Path -LiteralPath $blockedPak) {
    throw "Remove the unsigned PAK first: $blockedPak"
}
if (!(Test-Path -LiteralPath $source)) {
    throw "Optimized Game.locres is missing: $source"
}
$sourceHash = Get-KoPatchSha256 -LiteralPath $source
if ($sourceHash -ne $expectedHash) {
    throw "Optimized Game.locres hash mismatch: $sourceHash"
}

$targetWasPresent = Test-Path -LiteralPath $target
$previousTargetHash = if ($targetWasPresent) { Get-KoPatchSha256 -LiteralPath $target } else { $null }
if (Test-Path -LiteralPath $target) {
    if ($previousTargetHash -notin @($expectedHash, $previousPatchHash, $standardHash)) {
        throw "Refusing to overwrite an unexpected loose file. SHA256: $previousTargetHash"
    }
}

$timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$backupDir = Join-Path $workRoot "optimization_backups\$timestamp"
New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
$targetBackup = Join-Path $backupDir 'Game.locres.before'
$configBackup = Join-Path $backupDir 'Engine.ini.before'
$configWasPresent = Test-Path -LiteralPath $engineIni
if ($targetWasPresent) {
    Copy-Item -LiteralPath $target -Destination $targetBackup
}
if ($configWasPresent) {
    Copy-Item -LiteralPath $engineIni -Destination $configBackup
}

try {
    if ($previousTargetHash -ne $expectedHash) {
        Copy-VerifiedFileAtomic -Source $source -Destination $target -ExpectedSha256 $expectedHash
    }
    $configResult = Add-KoFontCacheOverride -EngineIni $engineIni
    $installedHash = Get-KoPatchSha256 -LiteralPath $target

    $state = [ordered]@{
        applied_at = (Get-Date).ToString('o')
        target_version = $version
        delivery = 'translated_only_sparse_loose_locres'
        target = $target
        target_was_present = $targetWasPresent
        previous_target_sha256 = $previousTargetHash
        installed_target_sha256 = $installedHash
        installed_entries = 51553
        installed_bytes = (Get-Item -LiteralPath $target).Length
        engine_ini = $engineIni
        engine_ini_was_present = $configWasPresent
        engine_ini_before_sha256 = $configResult.BeforeSha256
        engine_ini_after_sha256 = $configResult.AfterSha256
        font_cache_mb = 32
        language = 'zh-Hans'
        locale = 'unchanged'
        backup_directory = $backupDir
        pak_or_sig_modified = $false
    }
    $state | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $statePath -Encoding utf8
} catch {
    if ($targetWasPresent -and (Test-Path -LiteralPath $targetBackup)) {
        Copy-Item -LiteralPath $targetBackup -Destination $target -Force
    } elseif (!$targetWasPresent -and (Test-Path -LiteralPath $target)) {
        Remove-Item -LiteralPath $target -Force
    }
    if ($configWasPresent -and (Test-Path -LiteralPath $configBackup)) {
        Copy-Item -LiteralPath $configBackup -Destination $engineIni -Force
    } elseif (!$configWasPresent -and (Test-Path -LiteralPath $engineIni)) {
        Remove-Item -LiteralPath $engineIni -Force
    }
    throw
}

Write-Host "Installed optimized loose localization: $target"
Write-Host "SHA256: $installedHash"
Write-Host 'Entries: 51553 (official Korean plus validated manual Korean; missing entries use native Chinese source fallback)'
Write-Host 'Font raw-data cache: 32 MB'
Write-Host 'Culture remains zh-Hans; Language=ko was not enabled.'
Write-Host 'No PAK, SIG, executable, or ACE file was added or modified.'
