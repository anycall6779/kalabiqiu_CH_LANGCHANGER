$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$script:FontCacheBegin = '; BEGIN CALABIYAU_KO_PATCH_FONT_CACHE'
$script:FontCacheEnd = '; END CALABIYAU_KO_PATCH_FONT_CACHE'
$script:FontCacheChunk = "`r`n$script:FontCacheBegin`r`n[SystemSettings]`r`nSlate.Font.CacheFontRawData=true`r`nSlate.Font.CacheFontRawDataMaxSizeInMB=32`r`n$script:FontCacheEnd`r`n"

function Get-KoPatchSha256 {
    param([Parameter(Mandatory)][string]$LiteralPath)
    return (Get-FileHash -LiteralPath $LiteralPath -Algorithm SHA256).Hash
}

function Get-CalabiyauGameRoot {
    param([Parameter(Mandatory)][string]$StartPath)
    $candidate = (Resolve-Path -LiteralPath $StartPath).Path
    while ($candidate) {
        $versionFile = Join-Path $candidate 'Version.txt'
        $pakDirectory = Join-Path $candidate 'PM\Content\Paks'
        if ((Test-Path -LiteralPath $versionFile -PathType Leaf) -and
            (Test-Path -LiteralPath $pakDirectory -PathType Container)) {
            return $candidate
        }
        $parent = Split-Path -Parent $candidate
        if (!$parent -or $parent -eq $candidate) {
            break
        }
        $candidate = $parent
    }
    throw 'Calabiyau game root was not found. Put this repository inside the game installation directory.'
}

function Assert-CalabiyauStopped {
    $running = @(Get-CalabiyauRunningProcesses)
    if ($running.Count -gt 0) {
        $details = ($running | ForEach-Object { "$($_.ProcessName) PID=$($_.Id)" }) -join ', '
        throw "Close Calabiyau before changing localization or font settings: $details"
    }
}

function Get-CalabiyauRunningProcesses {
    return @(Get-Process -Name 'Calabiyau-Win64-Shipping', 'Calabiyau', 'Strinova-Win64-Shipping', 'Strinova' -ErrorAction SilentlyContinue)
}

function Get-CalabiyauEngineIniPath {
    $localAppData = [Environment]::GetFolderPath('LocalApplicationData')
    return Join-Path $localAppData 'Calabiyau\Saved\Config\WindowsNoEditor\Engine.ini'
}

function Write-Utf8NoBomAtomic {
    param(
        [Parameter(Mandatory)][string]$LiteralPath,
        [Parameter(Mandatory)][string]$Text
    )
    $directory = Split-Path -Parent $LiteralPath
    New-Item -ItemType Directory -Path $directory -Force | Out-Null
    $temporary = Join-Path $directory ((Split-Path -Leaf $LiteralPath) + ".ko_patch_$([guid]::NewGuid().ToString('N')).tmp")
    $replaceBackup = $temporary + '.replace_backup'
    try {
        [System.IO.File]::WriteAllText($temporary, $Text, [System.Text.UTF8Encoding]::new($false))
        if (Test-Path -LiteralPath $LiteralPath) {
            [System.IO.File]::Replace($temporary, $LiteralPath, $replaceBackup, $true)
        } else {
            Move-Item -LiteralPath $temporary -Destination $LiteralPath
        }
    } finally {
        if (Test-Path -LiteralPath $temporary) {
            Remove-Item -LiteralPath $temporary -Force
        }
        if (Test-Path -LiteralPath $replaceBackup) {
            Remove-Item -LiteralPath $replaceBackup -Force
        }
    }
}

function Test-KoFontCacheOverride {
    param([Parameter(Mandatory)][string]$EngineIni)
    if (!(Test-Path -LiteralPath $EngineIni)) {
        return $false
    }
    $text = [System.IO.File]::ReadAllText($EngineIni)
    $beginCount = ([regex]::Matches($text, [regex]::Escape($script:FontCacheBegin))).Count
    $endCount = ([regex]::Matches($text, [regex]::Escape($script:FontCacheEnd))).Count
    if ($beginCount -eq 0 -and $endCount -eq 0) {
        return $false
    }
    if ($beginCount -ne 1 -or $endCount -ne 1 -or !$text.Contains($script:FontCacheChunk)) {
        throw 'The managed Korean font-cache block was changed. Refusing an unsafe automatic edit.'
    }
    return $true
}

function Add-KoFontCacheOverride {
    param([Parameter(Mandatory)][string]$EngineIni)
    if (!(Test-Path -LiteralPath $EngineIni)) {
        throw "Engine.ini is missing: $EngineIni"
    }
    if (Test-KoFontCacheOverride -EngineIni $EngineIni) {
        return [pscustomobject]@{
            Changed = $false
            BeforeSha256 = Get-KoPatchSha256 -LiteralPath $EngineIni
            AfterSha256 = Get-KoPatchSha256 -LiteralPath $EngineIni
        }
    }

    $text = [System.IO.File]::ReadAllText($EngineIni)
    $unmanagedFontSettings = [regex]::Matches(
        $text,
        '(?im)^\s*Slate\.Font\.(CacheFontRawData(?:MaxSizeInMB)?)\s*=\s*([^;\r\n]+)'
    )
    if ($unmanagedFontSettings.Count -gt 0) {
        $rawData = $unmanagedFontSettings | Where-Object { $_.Groups[1].Value -ieq 'CacheFontRawData' }
        $maxSize = $unmanagedFontSettings | Where-Object { $_.Groups[1].Value -ieq 'CacheFontRawDataMaxSizeInMB' }
        $rawDataMatch = if (@($rawData).Count) { @($rawData)[-1] } else { $null }
        $maxSizeMatch = if (@($maxSize).Count) { @($maxSize)[-1] } else { $null }
        if ($rawDataMatch -and $rawDataMatch.Groups[2].Value.Trim() -ieq 'false') {
            throw 'Engine.ini explicitly disables the font raw-data cache. Refusing to override it.'
        }
        if ($maxSizeMatch) {
            $parsedSize = 0
            if (![int]::TryParse($maxSizeMatch.Groups[2].Value.Trim(), [ref]$parsedSize) -or $parsedSize -lt 32) {
                throw 'Engine.ini has an unmanaged font-cache size below 32 MB. Refusing to override it.'
            }
            $existingHash = Get-KoPatchSha256 -LiteralPath $EngineIni
            return [pscustomobject]@{
                Changed = $false
                BeforeSha256 = $existingHash
                AfterSha256 = $existingHash
            }
        }
        throw 'Engine.ini has unsupported unmanaged Slate font-cache settings. Refusing to override them.'
    }
    $before = Get-KoPatchSha256 -LiteralPath $EngineIni
    Write-Utf8NoBomAtomic -LiteralPath $EngineIni -Text ($text + $script:FontCacheChunk)
    if (!(Test-KoFontCacheOverride -EngineIni $EngineIni)) {
        throw 'Font-cache override verification failed.'
    }
    return [pscustomobject]@{
        Changed = $true
        BeforeSha256 = $before
        AfterSha256 = Get-KoPatchSha256 -LiteralPath $EngineIni
    }
}

function Remove-KoFontCacheOverride {
    param([Parameter(Mandatory)][string]$EngineIni)
    if (!(Test-Path -LiteralPath $EngineIni)) {
        return [pscustomobject]@{ Changed = $false; AfterSha256 = $null }
    }
    if (!(Test-KoFontCacheOverride -EngineIni $EngineIni)) {
        return [pscustomobject]@{
            Changed = $false
            AfterSha256 = Get-KoPatchSha256 -LiteralPath $EngineIni
        }
    }
    $text = [System.IO.File]::ReadAllText($EngineIni)
    $updated = $text.Replace($script:FontCacheChunk, '')
    if ($updated -eq $text -or $updated.Contains($script:FontCacheBegin) -or $updated.Contains($script:FontCacheEnd)) {
        throw 'Managed font-cache block removal verification failed.'
    }
    Write-Utf8NoBomAtomic -LiteralPath $EngineIni -Text $updated
    return [pscustomobject]@{
        Changed = $true
        AfterSha256 = Get-KoPatchSha256 -LiteralPath $EngineIni
    }
}

function Copy-VerifiedFileAtomic {
    param(
        [Parameter(Mandatory)][string]$Source,
        [Parameter(Mandatory)][string]$Destination,
        [Parameter(Mandatory)][string]$ExpectedSha256
    )
    $directory = Split-Path -Parent $Destination
    New-Item -ItemType Directory -Path $directory -Force | Out-Null
    $temporary = Join-Path $directory ((Split-Path -Leaf $Destination) + ".ko_patch_$([guid]::NewGuid().ToString('N')).tmp")
    try {
        Copy-Item -LiteralPath $Source -Destination $temporary
        $temporaryHash = Get-KoPatchSha256 -LiteralPath $temporary
        if ($temporaryHash -ne $ExpectedSha256) {
            throw "Temporary file hash mismatch: $temporaryHash"
        }
        Move-Item -LiteralPath $temporary -Destination $Destination -Force
        $installedHash = Get-KoPatchSha256 -LiteralPath $Destination
        if ($installedHash -ne $ExpectedSha256) {
            throw "Installed file hash mismatch: $installedHash"
        }
    } finally {
        if (Test-Path -LiteralPath $temporary) {
            Remove-Item -LiteralPath $temporary -Force
        }
    }
}
