param([Parameter(Mandatory=$true)][string]$ApkPath)
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$r=Get-Content (Join-Path $root 'RELEASE.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$dist=Join-Path $root 'dist'
New-Item -ItemType Directory -Force $dist | Out-Null
$apkName='LivingRoom-'+$r.version+'.apk'
$apkTarget=Join-Path $dist $apkName
if((Resolve-Path -LiteralPath $ApkPath).Path -ne $apkTarget){Copy-Item -LiteralPath $ApkPath -Destination $apkTarget}
$payload=[ordered]@{version=$r.version;versionCode=$r.versionCode;sha256=(Get-FileHash -LiteralPath $apkTarget).Hash}
$payload | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $root 'installer/PAYLOAD.json') -Encoding UTF8
$stage=Join-Path $root ('.cache/package-'+[guid]::NewGuid().ToString('N'))
$kit=Join-Path $stage 'LivingRoom-PC'
New-Item -ItemType Directory -Force (Join-Path $kit 'payload') | Out-Null
foreach($file in (Get-ChildItem -LiteralPath (Join-Path $root 'installer') -File)){
 if($file.Extension -in @('.ps1','.cmd','.md') -or $file.Name -in @('DEPENDENCIES.json','PAYLOAD.json')){Copy-Item -LiteralPath $file.FullName -Destination $kit}
}
Copy-Item -LiteralPath $apkTarget -Destination (Join-Path $kit 'payload/LivingRoom.apk')
Copy-Item -LiteralPath (Join-Path $root 'LICENSE') -Destination $kit
Copy-Item -LiteralPath (Join-Path $root 'THIRD_PARTY.md') -Destination $kit
Compress-Archive -LiteralPath $kit -DestinationPath (Join-Path $dist ('LivingRoom-PC-'+$r.version+'.zip')) -Force
Compress-Archive -LiteralPath (Join-Path $root 'skills/livingroom-install') -DestinationPath (Join-Path $dist ('livingroom-install-skill-'+$r.version+'.zip')) -Force
$source=Join-Path $dist ('LivingRoom-source-'+$r.version+'.zip')
# Explicit source allowlist; never archive repository root or local build/cache trees.
$sourceStage=Join-Path $stage 'LivingRoom-source'
New-Item -ItemType Directory -Force $sourceStage | Out-Null
New-Item -ItemType Directory -Force (Join-Path $sourceStage 'app') | Out-Null
Copy-Item -LiteralPath (Join-Path $root 'app/src') -Destination (Join-Path $sourceStage 'app') -Recurse
Copy-Item -LiteralPath (Join-Path $root 'app/build.gradle') -Destination (Join-Path $sourceStage 'app')
foreach($name in @('docs','skills','scripts','tests','.github')){Copy-Item -LiteralPath (Join-Path $root $name) -Destination $sourceStage -Recurse}
New-Item -ItemType Directory -Force (Join-Path $sourceStage 'installer') | Out-Null
foreach($file in (Get-ChildItem -LiteralPath (Join-Path $root 'installer') -File)){
 if($file.Extension -in @('.ps1','.cmd','.md') -or $file.Name -in @('DEPENDENCIES.json','PAYLOAD.json')){Copy-Item -LiteralPath $file.FullName -Destination (Join-Path $sourceStage 'installer')}
}
foreach($name in @('README.md','AGENTS.md','LICENSE','THIRD_PARTY.md','CONTRIBUTING.md','SECURITY.md','RELEASE.json','build.gradle','settings.gradle','gradle.properties','.gitignore','.gitattributes')){Copy-Item -LiteralPath (Join-Path $root $name) -Destination $sourceStage}
Compress-Archive -LiteralPath $sourceStage -DestinationPath $source -Force
$names=@($apkName,('LivingRoom-PC-'+$r.version+'.zip'),('livingroom-install-skill-'+$r.version+'.zip'),('LivingRoom-source-'+$r.version+'.zip'))
$lines=foreach($name in $names){(Get-FileHash -LiteralPath (Join-Path $dist $name)).Hash.ToLowerInvariant()+'  '+$name}
[IO.File]::WriteAllLines((Join-Path $dist 'SHA256SUMS'),$lines,[Text.UTF8Encoding]::new($false))
Get-ChildItem -LiteralPath $dist -File | Select-Object Name,Length
