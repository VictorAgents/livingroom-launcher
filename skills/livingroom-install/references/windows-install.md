# Windows 流程与参数

版本1.10.1-alpha.1，唯一发布源 https://github.com/VictorAgents/livingroom-launcher/releases/tag/v1.10.1-alpha.1 。不扫描网段，不猜测目标 IP；使用用户给出的 IPv4，可附端口，默认5555。

技能下载助手只下载官方项目 ZIP 和 SHA256SUMS，校验 ZIP后解压；不自动执行 APK 或修改设备。输出目录含 LivingRoom-PC。失败就停止，不从其他站点补下载，也不跳过校验。校验和与发布包同源，只能检查完整性，不能独立证明发布者身份。

```powershell
# SKILL 和 WORK 替换为实际绝对目录；下载助手返回带唯一子目录的安装路径
$kit = & 'SKILL/scripts/Get-Release.ps1' -Destination 'WORK'
& (Join-Path $kit 'Prepare.ps1') -SkipKodi
& (Join-Path $kit 'Install.ps1') -Device '192.168.1.50' -CheckOnly
```

已获得用户对首页及返回权限授权、且只要最小改造时：

```powershell
& (Join-Path $kit 'Install.ps1') -Device '192.168.1.50' -SkipKodi -SkipDeviceTuning -AcceptChanges
```

完整模式先不带 SkipKodi 准备，再不带 SkipDeviceTuning 安装。`-AcceptChanges` 只省略文本确认；必须沿用当前用户已授权范围。不能因为技能包含此参数就认为已获授权。

检查条件：型号A4093、API28、armeabi-v7a、早期白名单包含目标包名，腾讯原包存在，目标包未被其他程序占用，有唯一原HOME和可用设备序列号。安装本身由 Android 检查签名；失败不卸载强装。固件指纹记录备份用于恢复，并非所有同型号固件都已验证。

安装前备份位于解压目录 backups；序列号 / IP / 固件指纹只保留在用户本机，不要求粘贴到聊天。只读模式不生成备份、不安装、不修改设置。

恢复示例：

```powershell
& (Join-Path $kit 'Install.ps1') -Device '192.168.1.50' -Restore 'BACKUP.json' -CheckOnly
# 用户授权恢复该备份后
& (Join-Path $kit 'Install.ps1') -Device '192.168.1.50' -Restore 'BACKUP.json' -AcceptChanges
```

恢复仅还原受管理设置、权限、默认HOME和客厅服务成员状态；保留后来新增的其他辅助服务、APK与Kodi数据。没有有效同设备备份时，不能使用别人的备份，也不能保证回原厂。

遇到 ADB unavailable：请用户确认画面、IP、调试与授权，不能认定关机或承诺远程唤醒。网络/下载受 Agent 宿主限制时按宿主授权流程处理，不能绕过。

验收仍需用户操作遥控器：Home到客厅，详情返回正常，腾讯根首页BACK到客厅，其他应用 / 语音保留；经安排手动重启后验证默认HOME。社区版未预置海报，首次联网加载；公开推荐非账号个性化，最多10条、30秒轮播、约4小时刷新。
