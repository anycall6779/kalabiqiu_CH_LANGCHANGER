$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Get-CalabiyauInstalledVersion {
    param([Parameter(Mandatory)][string]$GameRoot)

    $versionPath = Join-Path $GameRoot 'Version.txt'
    if (!(Test-Path -LiteralPath $versionPath -PathType Leaf)) {
        throw "Version.txt is missing: $versionPath"
    }
    $version = [System.IO.File]::ReadAllText($versionPath).Trim()
    if ($version -notmatch '^\d+$') {
        throw "Version.txt does not contain a valid numeric China build ID: '$version'"
    }
    return $version
}

function Get-KoPatchVersionsRoot {
    param([Parameter(Mandatory)][string]$WorkRoot)
    return Join-Path $WorkRoot 'versions'
}

function Get-KoPatchManifestForVersion {
    param(
        [Parameter(Mandatory)][string]$WorkRoot,
        [Parameter(Mandatory)][string]$Version,
        [switch]$AllowMissing
    )

    if ($Version -notmatch '^\d+$') {
        throw "Invalid patch version: '$Version'"
    }

    $versionsRoot = Get-KoPatchVersionsRoot -WorkRoot $WorkRoot
    $versionRoot = Join-Path $versionsRoot $Version
    $manifestPath = Join-Path $versionRoot 'manifest.json'
    if (!(Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
        if ($AllowMissing) {
            return $null
        }
        throw "No patch package exists for China version $Version."
    }

    try {
        $manifest = [System.IO.File]::ReadAllText($manifestPath) | ConvertFrom-Json
    } catch {
        throw "Invalid patch manifest JSON: $manifestPath`n$($_.Exception.Message)"
    }

    if ([string]$manifest.target_version -ne $Version) {
        throw "Manifest target_version does not match its directory. Expected $Version, got '$($manifest.target_version)'."
    }
    if ([string]$manifest.culture -ne 'zh-Hans') {
        throw "Manifest culture must remain zh-Hans: $manifestPath"
    }

    $relativePath = [string]$manifest.locres_relative_path
    if ([string]::IsNullOrWhiteSpace($relativePath) -or [System.IO.Path]::IsPathRooted($relativePath)) {
        throw "Manifest locres_relative_path must be a non-empty relative path: $manifestPath"
    }

    $versionRootFull = [System.IO.Path]::GetFullPath($versionRoot).TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar
    $patchPath = [System.IO.Path]::GetFullPath((Join-Path $versionRoot $relativePath))
    if (!$patchPath.StartsWith($versionRootFull, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Manifest locres_relative_path escapes the version package directory: $relativePath"
    }
    if (!(Test-Path -LiteralPath $patchPath -PathType Leaf)) {
        throw "Version package LOCRES is missing: $patchPath"
    }

    $expectedHash = ([string]$manifest.locres_sha256).ToUpperInvariant()
    if ($expectedHash -notmatch '^[0-9A-F]{64}$') {
        throw "Manifest locres_sha256 is invalid: $manifestPath"
    }
    $actualHash = Get-KoPatchSha256 -LiteralPath $patchPath
    if ($actualHash -ne $expectedHash) {
        throw "Version package LOCRES hash mismatch. Expected $expectedHash, got $actualHash."
    }

    $expectedBytes = [long]$manifest.locres_bytes
    $actualBytes = (Get-Item -LiteralPath $patchPath).Length
    if ($expectedBytes -le 0 -or $actualBytes -ne $expectedBytes) {
        throw "Version package LOCRES size mismatch. Expected $expectedBytes, got $actualBytes."
    }

    return [pscustomobject]@{
        Version = $Version
        VersionRoot = $versionRoot
        ManifestPath = $manifestPath
        Manifest = $manifest
        PatchPath = $patchPath
        Sha256 = $actualHash
        Bytes = $actualBytes
    }
}

function Get-KoPatchKnownHashes {
    param([Parameter(Mandatory)][string]$WorkRoot)

    $hashes = [System.Collections.Generic.List[string]]::new()
    $versionsRoot = Get-KoPatchVersionsRoot -WorkRoot $WorkRoot
    if (Test-Path -LiteralPath $versionsRoot -PathType Container) {
        foreach ($directory in @(Get-ChildItem -LiteralPath $versionsRoot -Directory)) {
            if ($directory.Name -notmatch '^\d+$') {
                continue
            }
            $package = Get-KoPatchManifestForVersion -WorkRoot $WorkRoot -Version $directory.Name
            if (!$hashes.Contains($package.Sha256)) {
                $hashes.Add($package.Sha256)
            }
        }
    }
    return @($hashes)
}

function Get-KoPatchDetectionStatus {
    param(
        [Parameter(Mandatory)][string]$GameRoot,
        [Parameter(Mandatory)][string]$WorkRoot
    )

    $version = Get-CalabiyauInstalledVersion -GameRoot $GameRoot
    $package = Get-KoPatchManifestForVersion -WorkRoot $WorkRoot -Version $version -AllowMissing
    $running = @(Get-CalabiyauRunningProcesses)
    $target = Join-Path $GameRoot 'PM\Content\Localization\Game\zh-Hans\Game.locres'
    $targetExists = Test-Path -LiteralPath $target -PathType Leaf
    $targetHash = if ($targetExists) { Get-KoPatchSha256 -LiteralPath $target } else { $null }

    $action = if ($running.Count -gt 0) {
        if ($null -ne $package) { 'close_game_then_install' } else { 'close_game_then_build' }
    } elseif ($null -ne $package) {
        if ($targetHash -eq $package.Sha256) { 'already_installed' } else { 'install' }
    } else {
        'build_required'
    }

    return [pscustomobject]@{
        detected_version = $version
        package_found = ($null -ne $package)
        package_manifest = if ($null -ne $package) { $package.ManifestPath } else { $null }
        package_sha256 = if ($null -ne $package) { $package.Sha256 } else { $null }
        loose_locres_exists = $targetExists
        loose_locres_sha256 = $targetHash
        game_running = ($running.Count -gt 0)
        running_processes = @($running | ForEach-Object { "$($_.ProcessName) PID=$($_.Id)" })
        action = $action
    }
}
