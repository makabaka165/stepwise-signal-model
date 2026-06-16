@echo off
setlocal
set "SCRIPT_DIR=%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%run_iverilog_dbf_smoke.ps1" %*
exit /b %ERRORLEVEL%
