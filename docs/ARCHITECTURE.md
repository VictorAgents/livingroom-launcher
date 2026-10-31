# 原理与维护边界

## 整体过程，用白话说

1. 用户开启盒子的维修接口 ADB，电脑读取型号、应用、系统设置与页面日志。
2. 写一个独立 Android 首页，显示大背景、影视卡片和应用入口；播放仍交给原视频网站应用。
3. 识别固件的默认桌面筛选条件，将 APP 作为允许的 HOME 候选安装，再设默认首页。
4. 解决腾讯根首页吞返回键：用户授权后，用辅助服务接收 BACK，用使用情况事件判断当前是否根页面。
5. 对明确识别的广告、屏保和悬浮窗入口分别处理，每项记录原值，提供恢复。
6. 真实重启、实体遥控器和画面检查分别验收，保留公开技术说明与本机私有备份。

## 白名单在哪里

它是 Android SettingsProvider 中的键，不是“把 APK 搬进一个白名单目录”。基线固件读到：

```text
settings get secure enable_launcher_components
com.skyworthdigital.sky2dlauncher/com.android.provision/com.ktcp.launcher

settings get system com.skyworthdigital.homewhitelist
com.xiaopaitech.supportsdk,com.xiaopaitech.wallpaperlauncher
```

追加自制包名曾在当前会话有效，但开机恢复厂商原值；较晚的第二层白名单又会使启动先进入腾讯。最终确认早期列表中的 `com.skyworthdigital.sky2dlauncher` 未安装对应应用，才使用这个包名。

APP 在 `/data/app/.../base.apk`，Java namespace 仍是 `cn.arthur.livingroom`。Manifest 声明 MAIN / HOME / DEFAULT，包管理器设置默认：

```text
cmd package set-home-activity --user 0 com.skyworthdigital.sky2dlauncher/cn.arthur.livingroom.HomeActivity
```

最终方案不追加或覆盖白名单，不写系统分区，不取得 Root 或官方签名。别的固件若同包名已占用，必须停止；不能覆盖或卸载它。启动广播延迟拉起方案已弃用，没有留在当前代码中。

## 遥控器返回

`OpenHomeActivity` 是普通应用列表入口，明确跳转真正的 HOME，避免从“我的应用”打开时任务栈混乱。

`TencentBackService` 只在物理 BACK 按下时增量读取 UsageEvents，第一次从估计本次开机时间开始；内存仅保留当前包名 / 页面名 / 查询时间。当前为腾讯以下根类、且默认 HOME 是客厅，才处理成对 DOWN / UP 并打开客厅：

```text
com.ktcp.launcher.activity.LauncherHomeSingleTaskActivity
com.ktcp.launcher.activity.LauncherHomeNormalActivity
com.ktcp.launcher.activity.LauncherHomeExclusiveTaskActivity
```

详情、播放器、其他应用和其他按键放行。辅助服务不请求窗口内容；不保存 / 上传使用历史。系统 usage access 能力本身比当前用途更宽，因此安装时必须清楚说明。原 Tencent voice 服务及其他服务合并保留。

## 推荐、图片与轮播

Java 直接通过 HTTPS 读取腾讯公开频道。电影优先，再精选、电视剧、动漫、综艺、纪录片。解析服务器输出的 `focus` 数据字段，JSON-LD 作为补充；只解析字符串，不执行网页 JavaScript，不访问账号私有推荐。按影片 URL 去重，最多 10 条；服务仅返回更少有效条目时也可能少于 10 条。

新进程尝试刷新，活跃首页每 15 秒检查到期状态，约 4 小时刷新；失败保留旧内容，约 1 小时后重试。后台不持久运行定时任务。Feed 和图片留在应用本地缓存；不是推送，也不保证与腾讯电视首页实时一致。

30 秒轮播是 UI 计时器，独立于网络刷新。用户按键重置计时；影片行焦点与海报同步；“查看”按钮有焦点时避免自动换片；离开首页暂停。图片 URL 仅允许 HTTPS 腾讯相关图片域名，解码优先 1920 宽、ARGB8888。PosterCard 裁剪所有子内容，边框保留在外侧，防止矩形海报越过圆角。

社区版仅保留 10 条公开 URL 元数据，不预置第三方海报文件。首次联网后加载图片，后续可使用已有缓存。截图为预置海报的历史实机版本，参见 VALIDATION.md。

## 当前未解决项

- 原生开机短视频仅做过只读调查与本机备份，未替换，不能宣称已支持。
- 待机 ADB 失联原因未确定，网络不可达时不能靠 ADB 保证唤醒。
- 国内 Kodi 刮削器历史接口出现过 HTTP403；此仓库没有修复其第三方服务。
- 第二台原始盒子和其他固件完整部署尚未验证。
