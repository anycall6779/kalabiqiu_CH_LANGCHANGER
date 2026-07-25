param(
    [switch]$Json
)

$ErrorActionPreference = 'Stop'
$workRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $workRoot 'optimization_common.ps1')
. (Join-Path $workRoot 'version_patch_common.ps1')

$gameRoot = Get-CalabiyauGameRoot -StartPath $workRoot
$status = Get-KoPatchDetectionStatus -GameRoot $gameRoot -WorkRoot $workRoot
$versionWorkRoot = Join-Path $workRoot "version_work\$($status.detected_version)"
New-Item -ItemType Directory -Path $versionWorkRoot -Force | Out-Null

$pakRoot = Join-Path $gameRoot 'PM\Content\Paks'
$pakFiles = @(Get-ChildItem -LiteralPath $pakRoot -Filter '*.pak' -File)
$sigFiles = @(Get-ChildItem -LiteralPath $pakRoot -Filter '*.sig' -File)
$inventoryPath = Join-Path $versionWorkRoot 'package_inventory.csv'
$inventory = @($pakFiles + $sigFiles) |
    Sort-Object Name |
    Select-Object Name, Length, LastWriteTimeUtc
$inventory | Export-Csv -LiteralPath $inventoryPath -NoTypeInformation -Encoding utf8

$nextAction = if ($status.package_found) {
    if ($status.game_running) { 'close_game_then_run_install_patch' } else { 'run_install_patch' }
} elseif ($status.loose_locres_exists) {
    if ($status.game_running) { 'close_game_then_remove_stale_patch_and_build' } else { 'remove_stale_patch_and_build' }
} else {
    if ($status.game_running) { 'close_game_then_build' } else { 'build_current_version_patch' }
}

$report = [ordered]@{
    generated_at = (Get-Date).ToString('o')
    detected_china_version = $status.detected_version
    package_found = $status.package_found
    game_running = $status.game_running
    running_processes = $status.running_processes
    current_loose_locres_sha256 = $status.loose_locres_sha256
    pak_count = $pakFiles.Count
    sig_count = $sigFiles.Count
    inventory = $inventoryPath
    next_action = $nextAction
    safety = 'No PAK, SIG, executable, ACE, or installed localization file was modified.'
}
$reportPath = Join-Path $versionWorkRoot 'update_status.json'
[System.IO.File]::WriteAllText(
    $reportPath,
    ($report | ConvertTo-Json -Depth 5),
    [System.Text.UTF8Encoding]::new($false)
)

if ($Json) {
    $report | ConvertTo-Json -Depth 5
    return
}

Write-Host "Detected China version: $($status.detected_version)"
Write-Host "Matching patch package: $($status.package_found)"
Write-Host "PAK/SIG inventory: $($pakFiles.Count)/$($sigFiles.Count)"
Write-Host "Update status: $reportPath"
Write-Host "Next action: $nextAction"
