$ErrorActionPreference = 'Stop'

$workRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $workRoot 'optimization_common.ps1')
. (Join-Path $workRoot 'version_patch_common.ps1')
$gameRoot = Get-CalabiyauGameRoot -StartPath $workRoot
$version = Get-CalabiyauInstalledVersion -GameRoot $gameRoot
$package = Get-KoPatchManifestForVersion -WorkRoot $workRoot -Version $version -AllowMissing
if ($null -eq $package) {
    $target = Join-Path $gameRoot 'PM\Content\Localization\Game\zh-Hans\Game.locres'
    & (Join-Path $workRoot 'prepare_version_update.ps1') | Out-Host
    $builder = Join-Path $workRoot 'build_detected_version_patch.ps1'
    $localBuildConfig = Join-Path $workRoot 'config\aes_keys.json'
    if ((Test-Path -LiteralPath $builder -PathType Leaf) -and
        (Test-Path -LiteralPath $localBuildConfig -PathType Leaf)) {
        Assert-CalabiyauStopped
        & $builder
        $package = Get-KoPatchManifestForVersion -WorkRoot $workRoot -Version $version
    } else {
        $stale = if (Test-Path -LiteralPath $target -PathType Leaf) {
            " A loose LOCRES from an older build is present; close the game and run .\remove_patch.ps1 before continuing."
        } else {
            ''
        }
        throw "China version $version was detected automatically, but this repository has no matching versions\$version package.$stale"
    }
}
$blockedPak = Join-Path $gameRoot 'PM\Content\Paks\Game_Patch_WindowsNoEditor_999_P.pak'
if (Test-Path -LiteralPath $blockedPak) {
    throw 'The unsigned PAK is blocked by the game master signature table. Run remove_patch.ps1 first.'
}
& (Join-Path $workRoot 'install_loose_patch.ps1')
