$ErrorActionPreference = 'Stop'

$workRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $workRoot 'optimization_common.ps1')
$gameRoot = Get-CalabiyauGameRoot -StartPath $workRoot
$blockedPak = Join-Path $gameRoot 'PM\Content\Paks\Game_Patch_WindowsNoEditor_999_P.pak'
if (Test-Path -LiteralPath $blockedPak) {
    throw 'The unsigned PAK is blocked by the game master signature table. Run remove_patch.ps1 first.'
}
& (Join-Path $workRoot 'install_loose_patch.ps1')
