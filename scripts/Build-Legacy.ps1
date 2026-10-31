param(
 [Parameter(Mandatory=$true)][string]$ToolsRoot,
 [Parameter(Mandatory=$true)][string]$JavaExe,
 [string]$SigningKey,
 [string]$KeyAlias='livingroom'
)
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$release=Get-Content (Join-Path $root 'RELEASE.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$main=Join-Path $root 'app/src/main'
$stage=Join-Path $root ('.cache/legacy-'+[guid]::NewGuid().ToString('N'))
$out=Join-Path $root 'dist'
New-Item -ItemType Directory -Force $stage,$out,(Join-Path $stage 'classes') | Out-Null
$ToolsRoot=(Resolve-Path -LiteralPath $ToolsRoot).Path
$JavaExe=(Resolve-Path -LiteralPath $JavaExe).Path
foreach($name in @('ecj.jar','android-28.jar','build-tools/dx.jar','build-tools/aapt.exe','build-tools/zipalign.exe','build-tools/apksigner.jar')){if(!(Test-Path -LiteralPath (Join-Path $ToolsRoot $name))){throw "工具缺失：$name"}}
function Check-Step([string]$Name){if($LASTEXITCODE -ne 0){throw "$Name failed: $LASTEXITCODE"}}
$sources=@(Get-ChildItem (Join-Path $main 'java') -Recurse -Filter '*.java' | ForEach-Object FullName)
& $JavaExe -jar (Join-Path $ToolsRoot 'ecj.jar') -1.7 -encoding UTF-8 -classpath (Join-Path $ToolsRoot 'android-28.jar') -d (Join-Path $stage 'classes') @sources
Check-Step 'Java compile'
& $JavaExe -cp (Join-Path $ToolsRoot 'build-tools/dx.jar') com.android.dx.command.Main --dex "--output=$(Join-Path $stage 'classes.dex')" (Join-Path $stage 'classes')
Check-Step 'DEX'
[xml]$manifest=Get-Content (Join-Path $main 'AndroidManifest.xml') -Raw -Encoding UTF8
$ns='http://schemas.android.com/apk/res/android'
$manifest.manifest.SetAttribute('package',[string]$release.package)
$manifest.manifest.SetAttribute('versionCode',$ns,[string]$release.versionCode) | Out-Null
$manifest.manifest.SetAttribute('versionName',$ns,[string]$release.version) | Out-Null
$sdk=$manifest.CreateElement('uses-sdk')
$sdk.SetAttribute('minSdkVersion',$ns,'21') | Out-Null
$sdk.SetAttribute('targetSdkVersion',$ns,'28') | Out-Null
$manifest.manifest.PrependChild($sdk) | Out-Null
$manifest.Save((Join-Path $stage 'AndroidManifest.xml'))
foreach($folder in @('res','assets')){Copy-Item -LiteralPath (Join-Path $main $folder) -Destination $stage -Recurse}
Copy-Item -LiteralPath (Join-Path $ToolsRoot 'android-28.jar') -Destination $stage
Push-Location $stage
try {
 & (Join-Path $ToolsRoot 'build-tools/aapt.exe') package -f -M AndroidManifest.xml -I android-28.jar -S res -A assets -F unsigned.apk
 Check-Step 'APK resources'
 Add-Type -AssemblyName System.IO.Compression.FileSystem
 $zip=[IO.Compression.ZipFile]::Open((Join-Path $stage 'unsigned.apk'),[IO.Compression.ZipArchiveMode]::Update)
 try {[IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip,(Join-Path $stage 'classes.dex'),'classes.dex') | Out-Null}finally{$zip.Dispose()}
 & (Join-Path $ToolsRoot 'build-tools/zipalign.exe') -f 4 unsigned.apk aligned.apk
 Check-Step 'Zip alignment'
} finally {Pop-Location}
$output=Join-Path $out ('LivingRoom-'+$release.version+'.apk')
if($SigningKey){
 if(!$env:LIVINGROOM_KEYSTORE_PASSWORD){throw 'Set LIVINGROOM_KEYSTORE_PASSWORD in the local environment.'}
 & $JavaExe -jar (Join-Path $ToolsRoot 'build-tools/apksigner.jar') sign --ks $SigningKey --ks-key-alias $KeyAlias --ks-pass env:LIVINGROOM_KEYSTORE_PASSWORD --out $output (Join-Path $stage 'aligned.apk')
 Check-Step 'Signing'
 & $JavaExe -jar (Join-Path $ToolsRoot 'build-tools/apksigner.jar') verify --verbose $output
 Check-Step 'Signature verification'
}else{
 $output=Join-Path $out ('LivingRoom-'+$release.version+'-unsigned.apk')
 Copy-Item -LiteralPath (Join-Path $stage 'aligned.apk') -Destination $output
}
Get-FileHash -LiteralPath $output -Algorithm SHA256
