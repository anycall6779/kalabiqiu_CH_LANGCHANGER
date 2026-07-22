$ErrorActionPreference = 'Stop'

$workRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $workRoot 'optimization_common.ps1')
$gameRoot = Get-CalabiyauGameRoot -StartPath $workRoot

$localizationRoot = Join-Path $gameRoot 'PM\Content\Localization'
$target = Join-Path $localizationRoot 'Game\zh-Hans\Game.locres'
$allowedHashes = @(
    '4952F688A36582A76B6A28248D4BA4C3A309C3B2E12ADD736597679835A7DD74',
    'D437B9AA79152009DE29C505E66ED7A78ED626BF893D6953B3480E8AA54B690A',
    '835B5159EB84AA90D0F79E1CC273313BC17FFEE9BEE900E887EF1DD35049FC2F',
    '1DC783691F9CC8EF101E9695650E8BA17580B7D2281CA7B069198E85EC79A728'
)
$engineIni = Get-CalabiyauEngineIniPath

Assert-CalabiyauStopped

$targetExists = Test-Path -LiteralPath $target
$installedHash = if ($targetExists) { Get-KoPatchSha256 -LiteralPath $target } else { $null }
if ($targetExists -and $installedHash -notin $allowedHashes) {
    throw "Refusing to remove an unexpected loose file. SHA256: $installedHash"
}

$timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$backupDir = Join-Path $workRoot "optimization_backups\remove_$timestamp"
New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
$targetBackup = Join-Path $backupDir 'Game.locres.before_remove'
$configBackup = Join-Path $backupDir 'Engine.ini.before_remove'
if ($targetExists) {
    Copy-Item -LiteralPath $target -Destination $targetBackup
}
$configExists = Test-Path -LiteralPath $engineIni
if ($configExists) {
    Copy-Item -LiteralPath $engineIni -Destination $configBackup
}

try {
    $configResult = Remove-KoFontCacheOverride -EngineIni $engineIni
    if ($targetExists) {
        Remove-Item -LiteralPath $target -Force
        if (Test-Path -LiteralPath $target) {
            throw "Loose localization removal failed: $target"
        }
    }
} catch {
    if ($targetExists -and (Test-Path -LiteralPath $targetBackup)) {
        Copy-Item -LiteralPath $targetBackup -Destination $target -Force
    }
    if ($configExists -and (Test-Path -LiteralPath $configBackup)) {
        Copy-Item -LiteralPath $configBackup -Destination $engineIni -Force
    }
    throw
}

$cleanup = @(
    (Join-Path $localizationRoot 'Game\zh-Hans'),
    (Join-Path $localizationRoot 'Game'),
    $localizationRoot
)
foreach ($directory in $cleanup) {
    if ((Test-Path -LiteralPath $directory) -and
        @(Get-ChildItem -LiteralPath $directory -Force).Count -eq 0) {
        Remove-Item -LiteralPath $directory
    }
}
if ($targetExists) {
    Write-Host "Removed loose localization: $target"
} else {
    Write-Host 'Loose localization was not installed.'
}
if ($configResult.Changed) {
    Write-Host 'Removed the managed 32 MB font-cache override.'
}
Write-Host 'Original packaged Chinese resources were not modified.'
