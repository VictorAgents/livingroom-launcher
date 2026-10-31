$ErrorActionPreference='Stop'
$folder=Join-Path $PSScriptRoot 'backups'
if(!(Test-Path -LiteralPath $folder)){throw '没有找到备份。请先找到原安装时生成的backups文件夹。'}
$files=@(Get-ChildItem -LiteralPath $folder -Filter '*.json' -File | Sort-Object LastWriteTime)
if(!$files.Count){throw '没有可用备份。'}
Write-Host '选择要恢复的备份（多次安装时，最早备份通常最接近原始状态）：'
for($i=0;$i -lt $files.Count;$i++){Write-Host ('[{0}] {1}' -f ($i+1),$files[$i].Name)}
$number=Read-Host '输入编号'
if($number -notmatch '^\d+$' -or [int]$number -lt 1 -or [int]$number -gt $files.Count){throw '编号无效。'}
& (Join-Path $PSScriptRoot 'Install.ps1') -Restore $files[[int]$number-1].FullName
