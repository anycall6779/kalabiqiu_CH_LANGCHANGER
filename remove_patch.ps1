[CmdletBinding()]
param([string]$GameRoot='')
$ErrorActionPreference='Stop';Set-StrictMode -Version Latest
$packageRoot=$PSScriptRoot
function Resolve-GameRoot([string]$packageRoot){$p=(Resolve-Path $packageRoot).Path;for($i=0;$i -lt 6;$i++){if((Test-Path (Join-Path $p 'Version.txt')) -or (Test-Path (Join-Path $p 'PM\Binaries\Win64\CalabiyauVideo\version'))){return $p};$next=Split-Path $p -Parent;if($next -eq $p){break};$p=$next};throw 'Game root could not be located from the patch folder.'}
if(!$GameRoot){$GameRoot=Resolve-GameRoot $packageRoot};$GameRoot=(Resolve-Path $GameRoot).Path
function Get-Version([string]$root){foreach($p in @((Join-Path $root 'Version.txt'),(Join-Path $root 'PM\Binaries\Win64\CalabiyauVideo\version'))){if(Test-Path $p){$v=(Get-Content $p -Raw).Trim();if($v -match '^\d+(?:\.\d+)*$'){return $v}}};throw 'Game version could not be detected.'}
$version=Get-Version $GameRoot;$locres=Join-Path $GameRoot 'PM\Content\Localization\Game\zh-Hans\Game.locres';$managed=Join-Path $GameRoot "_ko_patch_work\backups\managed_$version";$previous=Join-Path $managed 'Game.locres.previous'
if(Get-Process|Where-Object {$_.ProcessName -match '^(Strinova|Calabiyau|ACE|ACE_.*)$'}){throw 'Game or ACE process is running; close it first.'}
if(Test-Path $previous){
  $locresDir=Split-Path $locres -Parent;New-Item -ItemType Directory -Force $locresDir|Out-Null
  $tmp="$locres.$PID.restore.tmp";Copy-Item $previous $tmp -Force;Move-Item $tmp $locres -Force;Write-Host "Restored pre-patch localization for detected version $version";exit 0
}

# Older installs could have been patched before the original file was backed up.
# In that case only remove the loose patch file, so Unreal can fall back to the
# copy bundled in the game's PAK files. Keep the patched file for recovery.
$installedMarker=Join-Path $managed 'installed.sha256'
if(!(Test-Path $locres) -or !(Test-Path $installedMarker)){throw "Managed backup for detected version $version was not found; refusing to guess."}
$currentHash=(Get-FileHash -LiteralPath $locres -Algorithm SHA256).Hash.ToUpperInvariant()
$installedHash=(Get-Content -LiteralPath $installedMarker -Raw).Trim().ToUpperInvariant()
if($currentHash -ne $installedHash){throw "Managed backup for detected version $version was not found, and the current localization file is not the managed patch; refusing to overwrite."}
$recoveryDir=Join-Path $GameRoot '_ko_patch_work\recovery';New-Item -ItemType Directory -Force $recoveryDir|Out-Null
$recovery=Join-Path $recoveryDir "Game.locres.patched_$version"
Move-Item -LiteralPath $locres -Destination $recovery -Force
Write-Host "Removed loose localization patch for version $version"
Write-Host "The patched file was preserved at: $recovery"
Write-Host 'The game should now use its packaged localization file.'
