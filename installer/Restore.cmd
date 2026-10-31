@echo off
setlocal
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Prepare.ps1" -SkipKodi
if errorlevel 1 goto failed
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Restore.ps1"
:failed
set "RESULT=%ERRORLEVEL%"
echo.
pause
exit /b %RESULT%
