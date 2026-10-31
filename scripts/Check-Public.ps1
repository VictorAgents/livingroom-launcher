$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$files=@(& git -C $root ls-files)
if($LASTEXITCODE -ne 0 -or !$files.Count){throw '先在独立公开仓库中暂存明确文件，再检查。'}
$blocked='(?i)(^|/)(backups|logs|work|tools|payload|dist|\.cache|\.gradle|build|user-audio)(/|$)|\.(p12|jks|keystore|apk|bin|log)$'
$bad=@($files | Where-Object {$_ -match $blocked})
if($bad.Count){throw ('不应公开的文件路径：'+($bad -join ', '))}
$personalPattern='(?i)192\.168\.199\.|(?:[0-9a-f]{2}:){5}[0-9a-f]{2}|D:\\AgentsWorkspace|C:\\Users\\[^\\\s]+|gh[pousr]_[A-Za-z0-9]{20,}|-----BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY-----'
foreach($name in $files){
 if($name -match '\.(png|jpg|jpeg|gif)$'){continue}
 $value=Get-Content -LiteralPath (Join-Path $root $name) -Raw -Encoding UTF8
 if($value -match $personalPattern){throw "发现私人标识、路径或密钥模式：$name"}
}
Write-Host ("PASS: reviewed tracked allowlist, {0} files; no private paths, identifiers, signing files, binaries or device logs matched." -f $files.Count)
