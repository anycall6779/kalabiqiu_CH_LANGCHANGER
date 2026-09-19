[CmdletBinding()]
param([string]$GameRoot='')
$ErrorActionPreference='Stop'; Set-StrictMode -Version Latest
$packageRoot=$PSScriptRoot
function Get-Sha256([string]$path){
  if(!(Test-Path -LiteralPath $path -PathType Leaf)){throw "File not found: $path"}
  $sha=[System.Security.Cryptography.SHA256]::Create()
  try{
    $stream=[System.IO.File]::OpenRead($path)
    try{return ([BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-','')}
    finally{$stream.Dispose()}
  }finally{$sha.Dispose()}
}
function Resolve-GameRoot([string]$packageRoot){
  $p=(Resolve-Path $packageRoot).Path
  for($i=0;$i -lt 6;$i++){
    if((Test-Path (Join-Path $p 'Version.txt')) -or (Test-Path (Join-Path $p 'PM\Binaries\Win64\CalabiyauVideo\version'))){return $p}
    $next=Split-Path $p -Parent; if($next -eq $p){break}; $p=$next
  }
  throw 'Game root could not be located from the patch folder.'
}
if(!$GameRoot){$GameRoot=Resolve-GameRoot $packageRoot}
$GameRoot=(Resolve-Path $GameRoot).Path
$catalog=Get-Content (Join-Path $packageRoot 'patch_catalog.json') -Raw|ConvertFrom-Json
function Get-Version([string]$root){
  foreach($p in @((Join-Path $root 'Version.txt'),(Join-Path $root 'PM\Binaries\Win64\CalabiyauVideo\version'))){
    if(Test-Path $p){$v=(Get-Content $p -Raw).Trim();if($v -match '^\d+(?:\.\d+)*$'){return $v}}
  }; throw 'Game version could not be detected.'
}
$version=Get-Version $GameRoot
$entry=@($catalog.entries)|Where-Object {$_.china_version -eq $version}|Select-Object -First 1
if(!$entry){$known=(@($catalog.entries)|ForEach-Object {$_.china_version}) -join ', ';throw "No prepared localization for detected version $version. Known prepared versions: $known. Refusing to guess or overwrite."}
$payload=Join-Path $packageRoot ($entry.payload -replace '/','\');$locres=Join-Path $GameRoot 'PM\Content\Localization\Game\zh-Hans\Game.locres'
if(!(Test-Path $payload)){throw "Payload missing: $payload"}
if((Get-Sha256 $payload).ToUpperInvariant() -ne $entry.sha256.ToUpperInvariant()){throw 'Payload SHA-256 mismatch.'}
if(Get-Process|Where-Object {$_.ProcessName -match '^(Strinova|Calabiyau|ACE|ACE_.*)$'}){throw 'Game or ACE process is running; close it first.'}
$managed=Join-Path $GameRoot "_ko_patch_work\backups\managed_$version";New-Item -ItemType Directory -Force $managed|Out-Null
if(Test-Path $locres){
  $old=(Get-Sha256 $locres).ToUpperInvariant()
  if($old -ne $entry.sha256.ToUpperInvariant() -and !(Test-Path (Join-Path $managed 'Game.locres.previous'))){Copy-Item $locres (Join-Path $managed 'Game.locres.previous')}
  Set-Content (Join-Path $managed 'previous.sha256') $old -Encoding ascii
}
$locresDir=Split-Path $locres -Parent;New-Item -ItemType Directory -Force $locresDir|Out-Null
$tmp="$locres.$PID.tmp";Copy-Item $payload $tmp -Force
if((Get-Sha256 $tmp).ToUpperInvariant() -ne $entry.sha256.ToUpperInvariant()){Remove-Item $tmp -Force;throw 'Temporary copy hash mismatch.'}
Move-Item $tmp $locres -Force
if((Get-Sha256 $locres).ToUpperInvariant() -ne $entry.sha256.ToUpperInvariant()){throw 'Installed hash verification failed.'}
Set-Content (Join-Path $managed 'installed.sha256') $entry.sha256 -Encoding ascii
Write-Host "Installed prepared localization for detected version $version"
