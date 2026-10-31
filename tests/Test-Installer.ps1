$ErrorActionPreference='Stop'
$root=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$folder=Join-Path $root ('.cache/mock-kit-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force $folder | Out-Null
Copy-Item -LiteralPath (Join-Path $root 'installer/Install.ps1') -Destination $folder
@(@{file='Install.ps1';sha256=(Get-FileHash (Join-Path $folder 'Install.ps1')).Hash}) | ConvertTo-Json | Set-Content (Join-Path $folder 'checksums.json') -Encoding UTF8
$path=Join-Path $folder 'Install.ps1'
$source=Get-Content -LiteralPath $path -Raw
$tokens=$null;$errors=$null
$ast=[Management.Automation.Language.Parser]::ParseInput($source,[ref]$tokens,[ref]$errors)
if($errors.Count){throw ($errors -join "`n")}
$node=$ast.Find({param($n) $n -is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq 'AdbCall'},$true)
$fake=@'
function AdbCall([string[]]$Arguments){
 if($Arguments[0] -eq 'connect'){return 'already connected to 192.168.1.50:5555'}
 if($Arguments[-1] -eq 'get-state'){return 'device'}
 if($Arguments -contains 'install'){
   $script:writes.Add('install') | Out-Null
   if($script:failInstall){return 'Failure [INSTALL_FAILED_UPDATE_INCOMPATIBLE]'}
   if($Arguments[-1] -match 'Kodi.apk'){$script:kodi=$true}else{$script:installed=$true}
   return 'Success'
 }
 $command=$Arguments[-1]
 switch -Regex ($command){
 '^getprop ro.product.model$' {return $script:model}
 '^getprop ro.build.version.sdk$' {return '28'}
 '^getprop ro.product.cpu.abi$' {return 'armeabi-v7a'}
 '^getprop ro.build.fingerprint$' {return 'fixture-firmware'}
 '^getprop ro.serialno$' {return 'fixture-serial'}
 '^pm path (.+)$' {
   $name=$Matches[1]
   if($name -eq 'org.xbmc.kodi' -and !$script:kodi){return ''}
   if($name -eq 'com.skyworthdigital.sky2dlauncher' -and !$script:installed){return ''}
   return 'package:/data/app/fixture/base.apk'
 }
 '^dumpsys package com.skyworthdigital.sky2dlauncher$' {if($script:collision){return 'other.Activity'};return 'cn.arthur.livingroom.HomeActivity'}
 '^dumpsys package com.tianci.ad$' {return ('User 0: installed=true hidden=false enabled='+$script:ad)}
 '^settings get (\w+) (\S+)$' {return $script:settings[($Matches[1]+'/'+$Matches[2])]}
 '^settings put (\w+) (\S+) (.+)$' {$script:writes.Add($command)|Out-Null;$script:settings[($Matches[1]+'/'+$Matches[2])]=$Matches[3];return ''}
 '^settings delete (\w+) (\S+)$' {$script:writes.Add($command)|Out-Null;$script:settings[($Matches[1]+'/'+$Matches[2])]='null';return ''}
 '^cmd package resolve-activity' {return $script:currentHome}
 '^cmd package set-home-activity --user 0 (.+)$' {$script:writes.Add($command)|Out-Null;$script:currentHome=$Matches[1];return 'Success'}
 '^cmd appops get (\S+) (\S+)$' {return ($Matches[2]+': '+$script:ops[$Matches[2]])}
 '^cmd appops set (\S+) (\S+) (\S+)$' {$script:writes.Add($command)|Out-Null;$script:ops[$Matches[2]]=$Matches[3];return ''}
 '^pm (\S+) --user 0 com.tianci.ad$' {$script:writes.Add($command)|Out-Null;$script:ad=@{'default-state'=0;'enable'=1;'disable'=2;'disable-user'=3;'disable-until-used'=4}[$Matches[1]];return 'Package state changed'}
 '^input keyevent 3$' {$script:writes.Add($command)|Out-Null;return ''}
 default {throw "Unmocked command: $command"}
 }
}
'@
$source=$source.Substring(0,$node.Extent.StartOffset)+$fake+$source.Substring($node.Extent.EndOffset)
$source=$source.Replace('$PSScriptRoot',("'"+$folder.Replace("'","''")+"'"))
$testBackupDir=Join-Path $folder ('backups-'+[guid]::NewGuid().ToString('N'))
$source=$source.Replace("`$backupDir=Join-Path '$folder' 'backups'",("`$backupDir='"+$testBackupDir+"'"))
$run=[scriptblock]::Create($source)
function Read-Host([string]$Prompt){if($Prompt -match 'RESTORE'){return 'RESTORE'};return 'INSTALL'}
function Reset-Fixture {
 $script:model='A4093';$script:installed=$false;$script:kodi=$false;$script:ad=0;$script:collision=$false;$script:failInstall=$false
 $script:currentHome='com.ktcp.launcher/.activity.LauncherMainActivity'
 $script:writes=New-Object 'System.Collections.Generic.List[string]'
 $script:ops=@{'GET_USAGE_STATS'='default';'SYSTEM_ALERT_WINDOW'='default'}
 $script:settings=@{'secure/enable_launcher_components'='com.skyworthdigital.sky2dlauncher/com.android.provision/com.ktcp.launcher';'secure/enabled_accessibility_services'='voice/.VoiceService';'secure/accessibility_enabled'='1';'secure/screensaver_enabled'='1';'secure/screensaver_activate_on_dock'='null';'secure/screensaver_activate_on_sleep'='1';'system/screen_off_timeout'='240000'}
}
function Assert($Condition,[string]$Message){if(!$Condition){throw "ASSERT: $Message"}}
Reset-Fixture
& $run -Device '192.168.1.50' -CheckOnly
Assert ($script:writes.Count -eq 0) 'CheckOnly must not mutate'
& $run -Device '192.168.1.50'
Assert ($script:installed -and $script:kodi) 'Launcher and Kodi installed'
Assert ($script:currentHome -eq 'com.skyworthdigital.sky2dlauncher/cn.arthur.livingroom.HomeActivity') 'Default HOME'
Assert ($script:settings['secure/enabled_accessibility_services'].Contains('voice/.VoiceService')) 'Voice service preserved'
Assert ($script:settings['system/screen_off_timeout'] -eq '2147483647') 'Tuning applied'
$backup=(Get-ChildItem -LiteralPath $testBackupDir -Filter '*.json' | Select-Object -First 1).FullName
$script:settings['secure/enabled_accessibility_services']+=':new/.Service'
& $run -Device '192.168.1.50' -Restore $backup
Assert ($script:currentHome -eq 'com.ktcp.launcher/.activity.LauncherMainActivity') 'Original HOME restored'
Assert ($script:settings['secure/screensaver_activate_on_dock'] -eq 'null') 'Absent key restored by deletion'
Assert ($script:settings['secure/enabled_accessibility_services'] -eq 'voice/.VoiceService:new/.Service') 'Restore preserves later services'
Assert ($script:ops['GET_USAGE_STATS'] -eq 'default' -and $script:ad -eq 0) 'Permission and package states restored'
Reset-Fixture;$script:model='DifferentBox';$rejected=$false
try{& $run -Device '192.168.1.50' -CheckOnly}catch{$rejected=$true}
Assert ($rejected -and $script:writes.Count -eq 0) 'Incompatible box rejected before writes'
Reset-Fixture;$script:installed=$true;$script:collision=$true;$rejected=$false
try{& $run -Device '192.168.1.50' -CheckOnly}catch{$rejected=$true}
Assert ($rejected -and $script:writes.Count -eq 0) 'Occupied package rejected'
Reset-Fixture;$script:failInstall=$true;$rejected=$false
try{& $run -Device '192.168.1.50'}catch{$rejected=$true}
Assert ($rejected -and $script:writes.Count -eq 1 -and $script:writes[0] -eq 'install') 'Install failure must stop before permission/settings mutations'
Write-Host 'PASS: readonly, install, restore, absent keys, service preservation, incompatible firmware, package collision, install failure.' -ForegroundColor Green
Reset-Fixture
function Read-Host([string]$Prompt){throw 'Unexpected interactive prompt in authorized agent mode'}
& $run -Device '192.168.1.50' -CheckOnly -AcceptChanges
Assert ($script:writes.Count -eq 0) 'Agent check remains read-only'
& $run -Device '192.168.1.50' -SkipKodi -SkipDeviceTuning -AcceptChanges
Assert ($script:installed -and !$script:kodi) 'Agent minimal install skips Kodi'
Assert ($script:settings['system/screen_off_timeout'] -eq '240000') 'Agent minimal install preserves power settings'
Write-Host 'PASS: authorized noninteractive agent mode and minimal scope.' -ForegroundColor Green
