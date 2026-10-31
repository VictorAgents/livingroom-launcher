# 客厅安装器

请完整解压 Release PC ZIP，再双击 Check.cmd / Install.cmd。首次准备需联网，下载 Google 官方 ADB；完整模式还会下载官方 Kodi。每项都有固定校验值。Prepare.ps1 不连接电视。

盒子需亮屏并开启 ADB；首次电视端允许连接由用户确认。输入实际 IP 后检查兼容性，实际安装前输入 INSTALL；原设置保存在本机 backups。Restore.cmd 选择同设备备份并输入 RESTORE。

默认会设客厅为 HOME，启用腾讯返回适配需要的使用情况访问与按键过滤，保留其他辅助服务，并管理已确认广告入口 / 屏保 / 熄屏。无须这些可选调整时，使用 Install.ps1 -SkipDeviceTuning。不需要 Kodi 时，Prepare.ps1 与 Install.ps1 都加 -SkipKodi。

Agent 只有在用户明确授权相关功能后才使用 -AcceptChanges。工具不 Root、不刷机、不重写白名单、不清除数据、不自动重启。不同固件可能不兼容，失败后停止，不卸载强装。

详细步骤与验收边界：https://github.com/VictorAgents/livingroom-launcher/blob/main/docs/INSTALL.md
