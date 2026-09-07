[CmdletBinding()]
param([string]$GameRoot='')
$ErrorActionPreference='Stop';Set-StrictMode -Version Latest
$packageRoot=$PSScriptRoot
function Resolve-GameRoot([string]$packageRoot){$p=(Resolve-Path $packageRoot).Path;for($i=0;$i -lt 6;$i++){if((Test-Path (Join-Path $p 'Version.txt')) -or (Test-Path (Join-Path $p 'PM\Binaries\Win64\CalabiyauVideo\version'))){return $p};$next=Split-Path $p -Parent;if($next -eq $p){break};$p=$next};throw 'Game root could not be located from the patch folder.'}
if(!$GameRoot){$GameRoot=Resolve-GameRoot $packageRoot};$GameRoot=(Resolve-Path $GameRoot).Path
function Get-Version([string]$root){foreach($p in @((Join-Path $root 'Version.txt'),(Join-Path $root 'PM\Binaries\Win64\CalabiyauVideo\version'))){if(Test-Path $p){$v=(Get-Content $p -Raw).Trim();if($v -match '^\d+(?:\.\d+)*$'){return $v}}};throw 'Game version could not be detected.'}
$version=Get-Version $GameRoot;$locres=Join-Path $GameRoot 'PM\Content\Localization\Game\zh-Hans\Game.locres';$previous=Join-Path $GameRoot "_ko_patch_work\backups\managed_$version\Game.locres.previous"
if(Get-Process|Where-Object {$_.ProcessName -match '^(Strinova|Calabiyau|ACE|ACE_.*)$'}){throw 'Game or ACE process is running; close it first.'}
if(!(Test-Path $previous)){throw "Managed backup for detected version $version was not found; refusing to guess."}
$tmp="$locres.$PID.restore.tmp";Copy-Item $previous $tmp -Force;Move-Item $tmp $locres -Force;Write-Host "Restored pre-patch localization for detected version $version"
