param([switch]$SkipKodi,[string]$AdbArchivePath)
$ErrorActionPreference='Stop'
[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12
$deps=Get-Content -LiteralPath (Join-Path $PSScriptRoot 'DEPENDENCIES.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$payload=Get-Content -LiteralPath (Join-Path $PSScriptRoot 'PAYLOAD.json') -Raw -Encoding UTF8 | ConvertFrom-Json
function Assert-Hash([string]$Path,[string]$Expected){
  if(!(Test-Path -LiteralPath $Path) -or (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash -ne $Expected){throw "SHA256校验失败或文件不存在：$Path"}
}
$existing=Join-Path $PSScriptRoot 'checksums.json'
if(Test-Path -LiteralPath $existing){
  foreach($entry in (Get-Content -LiteralPath $existing -Raw -Encoding UTF8 | ConvertFrom-Json)){
    if($entry.file -match '(^[\\/]|:|(^|[\\/])\.\.([\\/]|$))'){throw '不安全的校验文件路径。'}
    Assert-Hash (Join-Path $PSScriptRoot $entry.file) $entry.sha256
  }
}
Assert-Hash (Join-Path $PSScriptRoot 'payload/LivingRoom.apk') $payload.sha256
$cache=Join-Path $PSScriptRoot '.cache'
$toolsDir=Join-Path $PSScriptRoot 'tools'
New-Item -ItemType Directory -Force $cache,$toolsDir | Out-Null
$needAdb=$false
foreach($entry in $deps.adb.files){
  $target=Join-Path $toolsDir $entry.name
  if(!(Test-Path -LiteralPath $target) -or (Get-FileHash -LiteralPath $target).Hash -ne $entry.sha256){$needAdb=$true}
}
if($needAdb){
  $archive=Join-Path $cache 'platform-tools.zip'
  if($AdbArchivePath){$archive=(Resolve-Path -LiteralPath $AdbArchivePath).Path}
  elseif(!(Test-Path -LiteralPath $archive)){
    Write-Host '从Google官方源下载ADB；不修改设备。'
    $temp=$archive+'.download'
    Invoke-WebRequest -UseBasicParsing -Uri $deps.adb.url -OutFile $temp -TimeoutSec 120
    Assert-Hash $temp $deps.adb.sha256
    Move-Item -LiteralPath $temp -Destination $archive -Force
  }
  Assert-Hash $archive $deps.adb.sha256
  Add-Type -AssemblyName System.IO.Compression.FileSystem
  $zip=[IO.Compression.ZipFile]::OpenRead($archive)
  try {
    foreach($entry in $deps.adb.files){
      $item=$zip.GetEntry('platform-tools/'+$entry.name)
      if(!$item){throw "官方工具包缺少 $($entry.name)"}
      $target=Join-Path $toolsDir $entry.name
      [IO.Compression.ZipFileExtensions]::ExtractToFile($item,$target,$true)
      Assert-Hash $target $entry.sha256
    }
  } finally {$zip.Dispose()}
}
if(!$SkipKodi){
  $target=Join-Path $PSScriptRoot 'payload/Kodi.apk'
  if(!(Test-Path -LiteralPath $target)){
    Write-Host '从Kodi官方源下载可选播放器，约65MiB。'
    $temp=$target+'.download'
    Invoke-WebRequest -UseBasicParsing -Uri $deps.kodi.url -OutFile $temp -TimeoutSec 300
    Assert-Hash $temp $deps.kodi.sha256
    Move-Item -LiteralPath $temp -Destination $target -Force
  }
  Assert-Hash $target $deps.kodi.sha256
}
# Hash only managed program files; never absorb backups or arbitrary local files.
$files=@(Get-ChildItem -LiteralPath $PSScriptRoot -File | Where-Object {$_.Extension -in @('.ps1','.cmd','.md') -or $_.Name -in @('DEPENDENCIES.json','PAYLOAD.json')})
$files+=@(Get-ChildItem -LiteralPath $toolsDir -File | Where-Object {$_.Name -in @($deps.adb.files.name)})
$files+=Get-Item -LiteralPath (Join-Path $PSScriptRoot 'payload/LivingRoom.apk')
$kodiPath=Join-Path $PSScriptRoot 'payload/Kodi.apk'
if(Test-Path -LiteralPath $kodiPath){Assert-Hash $kodiPath $deps.kodi.sha256;$files+=Get-Item -LiteralPath $kodiPath}
$entries=@(foreach($file in $files){[ordered]@{file=$file.FullName.Substring($PSScriptRoot.Length+1).Replace('\','/');sha256=(Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash}})
$entries | Sort-Object file | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $existing -Encoding UTF8
Write-Host '文件准备及SHA256校验完成。未连接或修改电视盒子。' -ForegroundColor Green
