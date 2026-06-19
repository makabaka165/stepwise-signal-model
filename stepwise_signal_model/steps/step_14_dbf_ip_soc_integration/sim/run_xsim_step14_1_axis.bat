@echo off
setlocal
cd /d "%~dp0\.."

set SIMDIR=results_step14_dbf_ip_soc_integration\axis_sim
set SUMMARY=%SIMDIR%\step14_1_axis_xsim_summary.csv
if not exist "%SIMDIR%" mkdir "%SIMDIR%"

where xvlog >nul 2>nul
if errorlevel 1 goto unavailable
where xelab >nul 2>nul
if errorlevel 1 goto unavailable
where xsim >nul 2>nul
if errorlevel 1 goto unavailable

call xvlog -sv ..\step_13_fpga_soc_dbf_boundary\rtl\dbf_complex_mac.v ..\step_13_fpga_soc_dbf_boundary\rtl\dbf_beam_accum_core.v ..\step_13_fpga_soc_dbf_boundary\rtl\dbf_z24_quantizer.v ..\step_13_fpga_soc_dbf_boundary\rtl\dbf_core_z24.v ..\step_13_fpga_soc_dbf_boundary\rtl\dbf_core_z24_bparallel.v rtl\dbf_w_provider_rom.v rtl\dbf_axis_z_serializer.v rtl\dbf_axis_datapath.v rtl\dbf_axis_system_top.v tb\tb_dbf_axis_system_top.v
if errorlevel 1 (
    call :write_summary true true true fail not_run not_run
    exit /b %ERRORLEVEL%
)

call xelab tb_dbf_axis_system_top -debug typical -s step14_1_axis_sim
if errorlevel 1 (
    call :write_summary true true true pass fail not_run
    exit /b %ERRORLEVEL%
)

call xsim step14_1_axis_sim -tclbatch sim/xsim_step14_1_run_all.tcl
if errorlevel 1 (
    call :write_summary true true true pass pass fail
    exit /b %ERRORLEVEL%
)

if not exist "%SIMDIR%\step14_1_axis_tb_summary.csv" (
    call :write_summary true true true pass pass fail
    exit /b 1
)
if not exist "%SIMDIR%\step14_1_axis_output.csv" (
    call :write_summary true true true pass pass fail
    exit /b 1
)

findstr /x /c:"axis_tb_pass_flag,true" "%SIMDIR%\step14_1_axis_tb_summary.csv" >nul
if errorlevel 1 (
    call :write_summary true true true pass pass fail
    exit /b 1
)

call :write_summary true true true pass pass pass
exit /b 0

:unavailable
call :write_summary false false false unavailable unavailable unavailable
echo Vivado XSim tools unavailable. Summary written with unavailable status.
exit /b 0

:write_summary
set XVLOG_FOUND=%~1
set XELAB_FOUND=%~2
set XSIM_FOUND=%~3
set COMPILE_STATUS=%~4
set ELAB_STATUS=%~5
set SIM_STATUS=%~6
set TB_SUMMARY=false
set AXIS_OUTPUT=false
if exist "%SIMDIR%\step14_1_axis_tb_summary.csv" set TB_SUMMARY=true
if exist "%SIMDIR%\step14_1_axis_output.csv" set AXIS_OUTPUT=true
(
echo metric,value
echo tool_xvlog_found,%XVLOG_FOUND%
echo tool_xelab_found,%XELAB_FOUND%
echo tool_xsim_found,%XSIM_FOUND%
echo compile_status,%COMPILE_STATUS%
echo elaboration_status,%ELAB_STATUS%
echo simulation_status,%SIM_STATUS%
echo tb_summary_created,%TB_SUMMARY%
echo axis_output_csv_created,%AXIS_OUTPUT%
echo formal_result_claimed,false
echo dma_validation_flag,false
echo ps_validation_flag,false
echo board_validation_flag,false
) > "%SUMMARY%"
exit /b 0
