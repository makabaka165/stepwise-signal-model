@echo off
setlocal
set SCRIPT_DIR=%~dp0
powershell -ExecutionPolicy Bypass -File "%SCRIPT_DIR%run_reference_bd_strategy_sweep.ps1"
exit /b %ERRORLEVEL%
