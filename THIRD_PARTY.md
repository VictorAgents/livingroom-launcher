# 第三方内容与来源

- **腾讯视频**：公开网页 https://v.qq.com/channel/movie 等频道提供片名、简介、图片 URL 及详情链接。无腾讯 SDK / 账号令牌。海报、影视资料和相关商标归各自权利人，不由 GPL 授权；仓库不分发预置海报原始文件。README 内实机截图用于说明软件界面。公开源站变更可能导致推荐不可用。
- **第三方应用图标**：运行时通过 Android 包管理器获取已安装应用图标，仓库不包含对应应用安装文件。截图里的商标归原权利人。
- **Kodi**：可选下载官方21.3 ARMV7A，来源 https://mirrors.kodi.tv/releases/android/arm/kodi-21.3-Omega-armeabi-v7a.apk 。校验见 installer/DEPENDENCIES.json。项目不修改或随包重分发 Kodi；许可与源码见 https://github.com/xbmc/xbmc 。
- **Android Platform Tools**：用户准备阶段从 https://dl.google.com/android/repository/ 下载；元数据 https://dl.google.com/android/repository/repository2-1.xml 。取用 adb.exe、两项 DLL 和 NOTICE.txt，许可随官方工具提供。本仓库不提交工具二进制。SDK 许可 https://developer.android.com/studio/terms 。
- **Android / 构建依赖**：由开发者通过各自官方 SDK / Maven 源取得，遵循相应许可。仓库不含厂商固件或反编译得到的厂商代码。

这是独立的非官方社区项目，不代表腾讯、创维、Apple 或 Kodi 官方，也未将第三方商标作为项目自身标识。
