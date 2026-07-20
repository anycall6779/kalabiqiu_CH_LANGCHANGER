$ErrorActionPreference = 'Stop'

$workRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $workRoot 'optimization_common.ps1')
$gameRoot = Get-CalabiyauGameRoot -StartPath $workRoot
$legacyPak = Join-Path $gameRoot 'PM\Content\Paks\Game_Patch_WindowsNoEditor_999_P.pak'
$legacyHash = '69A1A0B9697E8E7C0D6E13AD58A949D34024E9AF6A6160C0F17402650BE91DB0'

if (Test-Path -LiteralPath $legacyPak) {
    $installedHash = (Get-FileHash -LiteralPath $legacyPak -Algorithm SHA256).Hash
    if ($installedHash -ne $legacyHash) {
        throw "Refusing to remove an unexpected PAK. SHA256: $installedHash"
    }
    Remove-Item -LiteralPath $legacyPak
    Write-Host "Removed blocked unsigned PAK: $legacyPak"
}
& (Join-Path $workRoot 'remove_loose_patch.ps1')
