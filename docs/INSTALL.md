# 安装与恢复

## 先准备

- 仅针对兼容条件确认的 A4093 / API28 / armeabi-v7a。安装器不以外壳相同作为充分条件。
- 电脑与盒子同一可互通局域网；用户在电视设置中开启 ADB 调试并允许当前电脑。
- 使用项目固定 Release，校验 SHA256SUMS。校验文件用于发现下载损坏；不能代替对发布账号的信任。
- 首次安装会授权按键过滤与使用情况访问，用于腾讯根首页返回。原语音及其他辅助服务保留。默认完整模式还调整下表设置。

## 完整模式具体改什么

| 项目 | 动作 | 恢复依据 |
| --- | --- | --- |
| 客厅 | `adb install -r`，不强制降级 / 卸载 | APK 保留，恢复不还原 APK 版本 |
| Kodi | 不存在时安装官方版本，已存在则保留 | 不清除媒体库或账号 |
| 默认 HOME | `cmd package set-home-activity --user 0` | 原默认组件 |
| 使用情况 | 客厅 `GET_USAGE_STATS=allow` | 原模式 |
| 辅助服务 | 追加客厅服务并启用总开关 | 还原自身成员资格，保留后来新增服务 |
| 广告入口 | `com.tianci.ad` disable-user | 原 enabled 状态 |
| 推广悬浮窗 | `com.skyworthdigital.ottstatsv2` 的悬浮窗 AppOp 为 ignore | 原模式，仅按包处理 |
| 屏保 | secure 中三个 screensaver 开关置 0 | 原值；原不存在则删除键 |
| 自动熄屏 | system `screen_off_timeout=2147483647` ms | 原值，手动电源键仍有效 |

不禁用整个统计系统包，不改腾讯播放器，不替换厂商应用，不更改白名单，不写只读分区。不能据此保证所有推广消失。

## 命令行与 Agent

在完整解压的安装目录执行，IP 替换为用户确认的盒子地址：

```powershell
# 准备 ADB，不下载 Kodi；此步只写电脑文件
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Prepare.ps1 -SkipKodi
# 只读检查，不安装、不创建设备设置备份
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Install.ps1 -Device 192.168.1.50 -CheckOnly
# 最小改造：安装首页及返回适配，不安装Kodi，不调整广告/屏保/熄屏
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Install.ps1 -Device 192.168.1.50 -SkipKodi -SkipDeviceTuning
```

普通完整安装：`Prepare.ps1`（无 SkipKodi）后执行 `Install.ps1 -Device <IP>`。

`-AcceptChanges` 用于 Agent / 无交互执行，跳过输入 INSTALL 或 RESTORE。**仅在用户已明确授权相应功能与权限后使用**；它不是自动授权。检查模式仍始终不写设备。安装和恢复都先读回目标身份；遇到错误即停，不能转为卸载、强装或绕过检查。

```powershell
# 已明确授权后的最小改造
.\Install.ps1 -Device 192.168.1.50 -SkipKodi -SkipDeviceTuning -AcceptChanges
# 按指定备份只读检查恢复条件
.\Install.ps1 -Device 192.168.1.50 -Restore .\backups\YOUR-BACKUP.json -CheckOnly
# 已明确授权恢复时
.\Install.ps1 -Device 192.168.1.50 -Restore .\backups\YOUR-BACKUP.json -AcceptChanges
```

准备脚本需要 Release 随附的 `payload/LivingRoom.apk`；源码 checkout 请先构建并将相同版本 APK 放到该位置。不要从不明来源补齐文件。默认不在 Git 保存安装载荷、下载工具和电脑本机备份。

## 恢复与失败处理

每次实际安装先保存序列号、固件指纹、HOME、受管理设置及权限到本机 `backups/`。失败保留此文件；不自动卸载或清空数据。

`Restore.cmd` 会列出备份，核对序列号和固件指纹后要求输入 RESTORE。没有属于该设备的备份就不要用其他设备备份替代。恢复最初状态通常选择首次改造前的备份；当前已经改造的机器生成的是改造后快照。

恢复只处理本工具管理的状态，不是固件完整镜像、应用数据备份或 APK 降级工具。它不会恢复原生开机视频，因为本工具从未改它。

## 实物验收

1. Home 键进入客厅；应用区顺序正确，未安装应用不显示。
2. 影视卡片和原图加载，30 秒切换；离开首页停止，回到首页重新计时。
3. 腾讯详情正常返回，腾讯根首页按实体 BACK 回到客厅；其他应用正常返回。
4. 确认原语音辅助服务仍可使用，Kodi 可启动。
5. 提前告知用户并在用户方便时手动重启，检查默认 HOME 仍正确。截图和设置回读不能代替本步骤。

ADB `input keyevent` 不能代替实体遥控器验收辅助服务的硬件按键过滤。

## 排障

- **连接超时**：确认画面、IP 和调试开关；ADB 离线不等于已关机。首次授权需电视上的用户确认。
- **不兼容 / 包名冲突**：停止，保留原应用，不临时更名、修改白名单或卸载厂商程序。
- **签名不匹配**：停止。自行构建的 debug APK 无法升级社区签名包；不要自动卸载已有版本。
- **已安装但开机还是腾讯**：确认默认 HOME 和固件兼容信息。新固件可能另有启动约束，不以“APP 能打开”当成功。
- **权限未生效**：保留错误，使用原备份恢复；不要批量覆盖所有辅助服务。
- **Kodi 扫描 0%**：此安装器不配置资料库和刮削器。先区分 SMB 文件读取与外部元数据源连通性；扫描有进度也不等于实际匹配成功。
