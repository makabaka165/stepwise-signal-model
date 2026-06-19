@echo off
setlocal
set "SCRIPT_DIR=%~dp0"
set "STEP_DIR=%SCRIPT_DIR%.."
where vivado >nul 2>nul
if errorlevel 1 (
  echo UNAVAILABLE: vivado was not found on PATH. Run Vivado settings64.bat or use Vivado Tcl Shell.
  powershell -NoProfile -ExecutionPolicy Bypass -Command "$d=(Resolve-Path '%STEP_DIR%').Path; $p=Join-Path $d 'results_step13_fpga_soc_dbf_boundary/rtl_fulln_sim/step13_4_fulln_xsim_summary.csv'; New-Item -ItemType Directory -Force -Path (Split-Path -Parent $p) | Out-Null; Set-Content -LiteralPath $p -Encoding ASCII -Value @('metric,value','tool_xvlog_found,false','tool_xelab_found,false','tool_xsim_found,false','simulation_status,unavailable','formal_result_claimed,false','note,vivado_not_available_run_settings64_or_vivado_shell')"
  exit /b 3
)
pushd "%STEP_DIR%"
vivado -mode batch -source sim\run_xsim_step13_4_fulln.tcl
set "RC=%ERRORLEVEL%"
popd
exit /b %RC%
