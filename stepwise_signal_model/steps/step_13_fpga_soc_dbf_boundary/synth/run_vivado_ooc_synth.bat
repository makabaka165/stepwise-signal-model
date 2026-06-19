@echo off
setlocal
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0run_vivado_ooc_synth.ps1"
exit /b %ERRORLEVEL%
