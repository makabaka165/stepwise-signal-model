@echo off
setlocal
set "SCRIPT_DIR=%~dp0"
set "STEP_DIR=%SCRIPT_DIR%.."
where vivado >nul 2>nul
if errorlevel 1 (
  echo UNAVAILABLE: vivado was not found on PATH. Run Vivado settings64.bat or use Vivado Tcl Shell.
  powershell -NoProfile -ExecutionPolicy Bypass -Command "$d=(Resolve-Path '%STEP_DIR%').Path; $p=Join-Path $d 'results_step13_fpga_soc_dbf_boundary/rtl_sim/step13_dbf_rtl_sim_summary.csv'; New-Item -ItemType Directory -Force -Path (Split-Path -Parent $p) | Out-Null; Set-Content -LiteralPath $p -Encoding ASCII -Value @('metric,value','simulation_status,unavailable','overall_simulation_status,unavailable','tool_xvlog_found,false','tool_xelab_found,false','tool_xsim_found,false','dbf_complex_mac_smoke,not_run','dbf_core_accum_smoke,not_run','dbf_z24_quantizer_smoke,not_run','dbf_core_z24_smoke,not_run','raw_accumulator_status,not_run','z24_quantizer_status,not_run','dbf_core_accum_output_csv_created,false','dbf_core_z24_output_csv_created,false','formal_result_claimed,false','scope,DBF accumulator plus Z24 shift-round-saturate output datapath','z24_shift_round_saturate_implemented,true','rz_gcache_ml_topk_c05_implemented,false','rz_gcache_ml_topk_c05_cpu_soc_responsibility,true','note,vivado_not_available_run_settings64_or_vivado_shell')"
  exit /b 3
)
pushd "%STEP_DIR%"
vivado -mode batch -source sim\run_xsim_dbf_smoke.tcl
set "RC=%ERRORLEVEL%"
popd
exit /b %RC%
