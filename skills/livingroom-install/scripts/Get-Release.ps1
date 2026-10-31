param([Parameter(Mandatory=$true)][string]$Destination)
$ErrorActionPreference='Stop'
[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12
$tag='v1.10.1-alpha.1'
$name='LivingRoom-PC-1.10.1-alpha.1.zip'
$base='https://github.com/VictorAgents/livingroom-launcher/releases/download/'+$tag
New-Item -ItemType Directory -Force $Destination | Out-Null
$destinationRoot=(Resolve-Path -LiteralPath $Destination).Path
$stage=Join-Path $destinationRoot ('livingroom-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force $stage | Out-Null
$sums=Join-Path $stage 'SHA256SUMS'
Invoke-WebRequest -UseBasicParsing -Uri ($base+'/SHA256SUMS') -OutFile $sums -TimeoutSec 60
$pattern='(?im)^([a-f0-9]{64})  '+[regex]::Escape($name)+'\s*$'
$match=[regex]::Matches((Get-Content -LiteralPath $sums -Raw -Encoding UTF8),$pattern)
if($match.Count -ne 1){throw '发布校验文件缺失或有重复项目，停止。'}
$archive=Join-Path $stage $name
Invoke-WebRequest -UseBasicParsing -Uri ($base+'/'+$name) -OutFile $archive -TimeoutSec 180
if((Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash -ne $match[0].Groups[1].Value){throw '下载校验失败，未解压或运行。'}
Expand-Archive -LiteralPath $archive -DestinationPath $stage
Write-Host 'Release下载校验通过。尚未连接或修改设备。' -ForegroundColor Green
Write-Output (Join-Path $stage 'LivingRoom-PC')
