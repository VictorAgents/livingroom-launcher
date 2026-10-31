# 构建与发布

## 标准工具链

JDK17、Gradle8.9、Android SDK Platform28、Build Tools34.0.0，执行 `gradle :app:assembleDebug`。Gradle 插件固定为8.7.3；依赖仅来自 Google / Maven Central / Gradle 插件仓库。首次构建需联网。

CI 进行 debug 编译及 Windows 模拟安装回归。Debug 证书不是社区发布证书，不能用于覆盖正式 Release。

## 已有维护工具链

`scripts/Build-Legacy.ps1` 接收外部 `ToolsRoot`（含 ecj.jar、android-28.jar、build-tools/{dx.jar,aapt.exe,zipalign.exe,apksigner.jar}）、JavaExe 和可选签名文件路径。工具从合法官方来源自行准备，不包含在仓库中。

```powershell
# 密码只在本机环境中设置，不提交文件，也不要把真实值贴到聊天
$env:LIVINGROOM_KEYSTORE_PASSWORD = '<local secret>'
.\scripts\Build-Legacy.ps1 -ToolsRoot C:\Android\livingroom-tools -JavaExe C:\Java\bin\java.exe -SigningKey C:\Private\release.p12
```

未传 SigningKey 时生成未签名 APK；不能直接安装。工具会从 RELEASE.json 生成旧 aapt 需要的 Manifest 版本字段，源 Manifest 与 Gradle 共用同一 Java / res / assets。原工具需要相对 ASCII 参数，脚本在临时构建目录内处理，支持中文项目路径。

发布者必须持续使用原发布签名；既有私钥仅在本机保管，绝不加入 Git 或上传 CI。自建签名是独立分发线，遇到冲突停止，不卸载他人版本。

## 发布包

```powershell
.\scripts\Package-Release.ps1 -ApkPath C:\Build\LivingRoom.apk
```

产物位于 `dist/`：签名 APK、PC ZIP、Agent skill ZIP、SHA256SUMS。PC ZIP 不含 ADB / Kodi 二进制：Prepare.ps1 按 DEPENDENCIES.json 从官方源下载。载荷版本要与 RELEASE.json 一致；打包脚本不替你签名。

公开前运行 `scripts/Check-Public.ps1`，检查明确的 Git 文件清单，确认所有截图无隐私。设备备份和调试记录留在原维护项目，不复制到此仓库。不要用 `git add` 指向原项目根目录。
