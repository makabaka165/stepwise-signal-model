@echo off
setlocal
cd /d "%~dp0\.."
where xvlog >nul 2>nul
if errorlevel 1 goto unavailable
where xelab >nul 2>nul
if errorlevel 1 goto unavailable
where xsim >nul 2>nul
if errorlevel 1 goto unavailable
vivado -mode batch -source sim/run_xsim_step14_1_axis.tcl
exit /b %ERRORLEVEL%

:unavailable
if not exist results_step14_dbf_ip_soc_integration\axis_sim mkdir results_step14_dbf_ip_soc_integration\axis_sim
(
echo metric,value
echo tool_xvlog_found,false
echo tool_xelab_found,false
echo tool_xsim_found,false
echo compile_status,unavailable
echo elaboration_status,unavailable
echo simulation_status,unavailable
echo tb_summary_created,false
echo axis_output_csv_created,false
echo formal_result_claimed,false
echo dma_validation_flag,false
echo ps_validation_flag,false
echo board_validation_flag,false
) > results_step14_dbf_ip_soc_integration\axis_sim\step14_1_axis_xsim_summary.csv
echo Vivado XSim tools unavailable. Summary written with unavailable status.
exit /b 0
