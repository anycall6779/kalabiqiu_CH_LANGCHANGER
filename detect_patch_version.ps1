param(
    [switch]$Json
)

$ErrorActionPreference = 'Stop'
$workRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $workRoot 'optimization_common.ps1')
. (Join-Path $workRoot 'version_patch_common.ps1')

$gameRoot = Get-CalabiyauGameRoot -StartPath $workRoot
$status = Get-KoPatchDetectionStatus -GameRoot $gameRoot -WorkRoot $workRoot

if ($Json) {
    $status | ConvertTo-Json -Depth 4
    return
}

Write-Host "Detected China version: $($status.detected_version)"
Write-Host "Matching patch package: $($status.package_found)"
Write-Host "Game running: $($status.game_running)"
Write-Host "Next action: $($status.action)"
if ($status.package_manifest) {
    Write-Host "Manifest: $($status.package_manifest)"
}
if ($status.loose_locres_sha256) {
    Write-Host "Current loose LOCRES SHA256: $($status.loose_locres_sha256)"
}
