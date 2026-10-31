param(
  [string]$Device,
  [switch]$CheckOnly,
  [switch]$VerifyFilesOnly,
  [switch]$SkipKodi,
  [switch]$SkipDeviceTuning,
  [string]$Restore,
  [switch]$AcceptChanges
)
$ErrorActionPreference='Stop'
$adb=Join-Path $PSScriptRoot 'tools\adb.exe'
$pkg='com.skyworthdigital.sky2dlauncher'
$targetHome="$pkg/cn.arthur.livingroom.HomeActivity"
$service="$pkg/cn.arthur.livingroom.TencentBackService"
$manifest=Get-Content -LiteralPath (Join-Path $PSScriptRoot 'checksums.json') -Raw -Encoding UTF8 | ConvertFrom-Json
foreach($entry in $manifest){
  $file=Join-Path $PSScriptRoot $entry.file
  if(!(Test-Path -LiteralPath $file) -or (Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash -ne $entry.sha256){throw "文件缺失或校验失败：$($entry.file)。请重新解压完整安装包。"}
}
Write-Host '安装文件校验通过。' -ForegroundColor Green
if($VerifyFilesOnly){return}
if(!$Device){$Device=(Read-Host '请输入电视盒子的 IPv4 地址（例如 192.168.1.50）').Trim()}
if($Device -notmatch '^(\d{1,3}(?:\.\d{1,3}){3})(?::(\d{1,5}))?$'){throw '地址格式错误，请输入盒子的局域网 IPv4 地址，可附带 :5555。'}
$ip=$Matches[1];$port=$Matches[2]
if(@($ip.Split('.') | Where-Object {[int]$_ -gt 255}).Count -gt 0){throw 'IPv4 地址不合法。'}
if(!$port){$port='5555'}
if([int]$port -lt 1 -or [int]$port -gt 65535){throw '端口不合法。'}
$Device=$ip+':'+$port
function AdbCall([string[]]$Arguments){
  $ErrorActionPreference='Continue' # ADB daemon startup writes normal messages to stderr on Windows PowerShell 5.1.
  $result=@(& $adb @Arguments 2>&1)
  if($LASTEXITCODE -ne 0){throw ($result -join "`n")}
  return ($result -join "`n").Trim()
}
function Shell([string]$Command){AdbCall @('-s',$Device,'shell',$Command)}
function Apply([string]$Command){
  $out=Shell $Command
  if($out -match '(?im)^(Error:|Exception|java\.|Security exception|Failure\s*\[)|Permission denial|Permission denied|Unknown command|not found'){throw "配置失败：$Command`n$out"}
  return $out
}
function Setting([string]$Table,[string]$Key){Shell "settings get $Table $Key"}
function WriteSetting([string]$Table,[string]$Key,[string]$Value){
  if(!$Value -or $Value -eq 'null'){Apply "settings delete $Table $Key" | Out-Null}
  else {Apply "settings put $Table $Key $Value" | Out-Null}
  if((Setting $Table $Key) -ne $(if(!$Value){'null'}else{$Value})){throw "设置回读不一致：$Key"}
}
function HomeComponent {
  $lines=(Shell 'cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME') -split "`n"
  $component=@($lines | Where-Object {$_ -match '^[A-Za-z0-9_.]+/[A-Za-z0-9_.$]+$'})
  if($component.Count -ne 1){throw '无法明确识别原默认桌面，停止配置。'}
  return $component[0].Trim()
}
function HasPackage([string]$Name){(Shell "pm path $Name") -match '^package:'}
function AppOpMode([string]$Name,[string]$Op){
  $raw=Shell "cmd appops get $Name $Op"
  if($raw -match ($Op+':\s*(allow|ignore|deny|default|foreground)')){return $Matches[1]}
  if($raw -match 'No operations\.|No operations\s|Unknown package'){return 'default'}
  throw "无法读取 $Name 的 $Op 原状态：$raw"
}
$connection=AdbCall @('connect',$Device)
Write-Host $connection
if($connection -notmatch '(already connected to|connected to)'){throw '连接失败。确认盒子亮屏、IP正确，关闭再开启ADB调试。'}
$state=AdbCall @('-s',$Device,'get-state')
if($state -ne 'device'){throw '设备未授权。请在电视上允许这台电脑调试后重新运行。'}
$model=Shell 'getprop ro.product.model'
$sdk=Shell 'getprop ro.build.version.sdk'
$abi=Shell 'getprop ro.product.cpu.abi'
$fingerprint=Shell 'getprop ro.build.fingerprint'
Write-Host "设备：$model；Android API $sdk；$abi"

if($Restore){
  $backup=Get-Content -LiteralPath $Restore -Raw -Encoding UTF8 | ConvertFrom-Json
  if($backup.schema -ne 1 -or $backup.serial -ne (Shell 'getprop ro.serialno') -or $backup.fingerprint -ne $fingerprint){throw '备份不属于当前设备及固件，不能恢复。'}
  if($backup.home -notmatch '^[A-Za-z0-9_.]+/[A-Za-z0-9_.$]+$'){throw '备份中的原桌面信息不合法。'}
  if($backup.usageMode -notmatch '^(allow|ignore|deny|default|foreground)$' -or ($backup.overlayMode -and $backup.overlayMode -notmatch '^(allow|ignore|deny|default|foreground)$')){throw '备份权限模式不合法。'}
  if($null -ne $backup.adEnabled -and [string]$backup.adEnabled -notmatch '^[0-4]$'){throw '备份组件状态不合法。'}
  if([string]$backup.accessibilityEnabled -notmatch '^(0|1|null)$'){throw '备份辅助服务总开关不合法。'}
  foreach($setting in $backup.settings){
    if(($setting.table -eq 'secure' -and $setting.key -match '^screensaver_(enabled|activate_on_dock|activate_on_sleep)$') -or ($setting.table -eq 'system' -and $setting.key -eq 'screen_off_timeout')){
      if([string]$setting.value -notmatch '^(null|[0-9]+)$'){throw '备份设置值不合法。'}
    }else{throw '备份包含本工具不管理的设置。'}
  }
  Write-Host "将恢复备份：$Restore（保留客厅和Kodi，不清除应用数据）。"
  if($CheckOnly){Write-Host '只读检查完成；未更改设备。';return}
  if(!$AcceptChanges -and (Read-Host '输入 RESTORE 恢复此设备的原设置') -cne 'RESTORE'){Write-Host '已取消';return}
  Apply ('cmd package set-home-activity --user 0 '+$backup.home) | Out-Null
  # Only revert our service membership. Preserve services subsequently added by the user.
  $current=@((Setting 'secure' 'enabled_accessibility_services') -split ':' | Where-Object {$_ -and $_ -ne 'null' -and $_ -ne $service})
  if($backup.ourServiceEnabled){$current+=$service}
  if($current.Count){WriteSetting 'secure' 'enabled_accessibility_services' ($current -join ':');WriteSetting 'secure' 'accessibility_enabled' '1'}
  else {WriteSetting 'secure' 'enabled_accessibility_services' 'null';WriteSetting 'secure' 'accessibility_enabled' $backup.accessibilityEnabled}
  if(HasPackage $pkg){Apply "cmd appops set $pkg GET_USAGE_STATS $($backup.usageMode)" | Out-Null}
  if($backup.tuning){
    foreach($setting in $backup.settings){WriteSetting $setting.table $setting.key $setting.value}
    if($null -ne $backup.adEnabled){
      $commands=@('default-state','enable','disable','disable-user','disable-until-used')
      Apply ('pm '+$commands[[int]$backup.adEnabled]+' --user 0 com.tianci.ad') | Out-Null
    }
    if($backup.overlayMode){Apply "cmd appops set com.skyworthdigital.ottstatsv2 SYSTEM_ALERT_WINDOW $($backup.overlayMode)" | Out-Null}
  }
  Apply 'input keyevent 3' | Out-Null
  if((HomeComponent) -ne $backup.home){throw '恢复后默认桌面回读不一致。'}
  Write-Host '原设置恢复完成；APK仍保留。' -ForegroundColor Green
  return
}

# Same model alone is insufficient: validate the actual early HOME whitelist.
$whitelist=Setting 'secure' 'enable_launcher_components'
if($model -ne 'A4093' -or $sdk -ne '28' -or $abi -ne 'armeabi-v7a' -or @($whitelist -split '/' | Where-Object {$_ -eq $pkg}).Count -ne 1){throw '不是已验证的A4093/Android9/32位固件配置，停止自动改造；没有安装或修改设置。'}
if(!(HasPackage 'com.ktcp.launcher')){throw '未发现已适配的腾讯原桌面，停止。'}
$installed=HasPackage $pkg
if($installed){
  $existing=Shell "dumpsys package $pkg"
  if($existing -notmatch 'cn\.arthur\.livingroom\.HomeActivity'){throw '白名单包名已被其他应用占用，停止，不能覆盖。'}
}
$originalHome=HomeComponent
$serial=Shell 'getprop ro.serialno'
if(!$serial -or $serial -eq 'unknown'){throw '没有可用的设备序列号，不能可靠区分备份，停止自动配置。'}
$services=Setting 'secure' 'enabled_accessibility_services'
$settingKeys=@(@('secure','screensaver_enabled'),@('secure','screensaver_activate_on_dock'),@('secure','screensaver_activate_on_sleep'),@('system','screen_off_timeout'))
$settings=@(foreach($key in $settingKeys){[ordered]@{table=$key[0];key=$key[1];value=(Setting $key[0] $key[1])}})
$adEnabled=$null
if(HasPackage 'com.tianci.ad'){
  $dump=Shell 'dumpsys package com.tianci.ad'
  if($dump -notmatch 'User 0:[^\r\n]*\benabled=([0-4])'){throw '无法读取广告组件原启用状态，停止。'}
  $adEnabled=[int]$Matches[1]
}
$overlayMode=$null
if(HasPackage 'com.skyworthdigital.ottstatsv2'){$overlayMode=AppOpMode 'com.skyworthdigital.ottstatsv2' 'SYSTEM_ALERT_WINDOW'}
$usageMode='default'
if($installed){$usageMode=AppOpMode $pkg 'GET_USAGE_STATS'}
$snapshot=[ordered]@{schema=1;time=(Get-Date).ToString('o');device=$Device;serial=$serial;model=$model;fingerprint=$fingerprint;home=$originalHome;launcherWasInstalled=$installed;ourServiceEnabled=(@($services -split ':') -contains $service);accessibilityEnabled=(Setting 'secure' 'accessibility_enabled');usageMode=$usageMode;tuning=(!$SkipDeviceTuning);settings=$settings;adEnabled=$adEnabled;overlayMode=$overlayMode}
Write-Host '兼容检查通过。将安装社区版客厅，设为默认HOME，启用腾讯返回适配。'
Write-Host '返回适配需要按键过滤和使用情况访问权限，仅识别腾讯根首页；不读取屏幕、不保存或上传使用记录。'
if(!$SkipKodi){Write-Host 'Kodi仅在未安装时安装，不导入网络硬盘账号。'}
if(!$SkipDeviceTuning){Write-Host '完整模式：关闭已验证广告组件的入口及统计组件悬浮窗权限、关闭系统屏保、延长自动熄屏。不是去除所有播放器广告。'}
if($CheckOnly){Write-Host '只读检查通过；未安装APK、未备份或修改设备设置。' -ForegroundColor Green;return}
if(!$AcceptChanges -and (Read-Host '确认上述功能及权限后，输入 INSTALL 开始') -cne 'INSTALL'){Write-Host '已取消';return}
$backupDir=Join-Path $PSScriptRoot 'backups'
New-Item -ItemType Directory -Force $backupDir | Out-Null
$backupPath=Join-Path $backupDir (($Device -replace ':','_')+'-'+(Get-Date -Format 'yyyyMMdd-HHmmss')+'.json')
$snapshot | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $backupPath -Encoding UTF8
Write-Host "原设置备份：$backupPath" -ForegroundColor Cyan
try {
  Write-Host '[1/5] 安装客厅（不降级、不卸载现有版本）'
  $out=AdbCall @('-s',$Device,'install','-r',(Join-Path $PSScriptRoot 'payload\LivingRoom.apk'))
  if($out -notmatch '(?m)^Success\s*$'){throw $out}
  Write-Host '[2/5] 配置Kodi'
  if(!$SkipKodi -and !(HasPackage 'org.xbmc.kodi')){
    $out=AdbCall @('-s',$Device,'install',(Join-Path $PSScriptRoot 'payload\Kodi.apk'))
    if($out -notmatch '(?m)^Success\s*$'){throw $out}
  }
  Write-Host '[3/5] 配置腾讯返回适配，保留原有语音等辅助服务'
  Apply "cmd appops set $pkg GET_USAGE_STATS allow" | Out-Null
  $list=@((Setting 'secure' 'enabled_accessibility_services') -split ':' | Where-Object {$_ -and $_ -ne 'null' -and $_ -ne $service})
  $list+=$service
  WriteSetting 'secure' 'enabled_accessibility_services' ($list -join ':')
  WriteSetting 'secure' 'accessibility_enabled' '1'
  Write-Host '[4/5] 配置默认首页与可选设备设置'
  if(!$SkipDeviceTuning){
    if($null -ne $adEnabled){Apply 'pm disable-user --user 0 com.tianci.ad' | Out-Null}
    if($overlayMode){Apply 'cmd appops set com.skyworthdigital.ottstatsv2 SYSTEM_ALERT_WINDOW ignore' | Out-Null}
    foreach($key in $settingKeys){WriteSetting $key[0] $key[1] $(if($key[1] -eq 'screen_off_timeout'){'2147483647'}else{'0'})}
  }
  Apply "cmd package set-home-activity --user 0 $targetHome" | Out-Null
  Apply 'input keyevent 3' | Out-Null
  Write-Host '[5/5] 回读验证'
  if((HomeComponent) -ne $targetHome){throw '系统未接受默认桌面设置。'}
  if((AppOpMode $pkg 'GET_USAGE_STATS') -ne 'allow'){throw '使用情况访问授权未生效。'}
  if(@((Setting 'secure' 'enabled_accessibility_services') -split ':') -notcontains $service){throw '返回辅助服务未启用。'}
  Write-Host '安装及设置回读完成。请用遥控器验证Kodi、腾讯返回，并在方便时手动重启验证默认首页。' -ForegroundColor Green
  Write-Host '本工具没有重启盒子。新固件的开机行为仍需实际验证。'
} catch {
  Write-Host "未全部完成：$($_.Exception.Message)" -ForegroundColor Red
  Write-Host "保留备份：$backupPath。可双击 Restore.cmd 按此备份恢复；不会自动卸载应用或清除数据。" -ForegroundColor Yellow
  throw
}
