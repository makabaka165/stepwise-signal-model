@echo off
setlocal
cd /d "%~dp0\.."

where vivado >nul 2>nul
if not errorlevel 1 (
    call vivado -mode batch -source vivado/validate_dbf_axis_ip.tcl
    exit /b %ERRORLEVEL%
)

if defined VIVADO_SETTINGS64 if exist "%VIVADO_SETTINGS64%" (
    call "%VIVADO_SETTINGS64%"
    call vivado -mode batch -source vivado/validate_dbf_axis_ip.tcl
    exit /b %ERRORLEVEL%
)

if not exist results_step14_dbf_ip_soc_integration\ip_package mkdir results_step14_dbf_ip_soc_integration\ip_package
if not exist results_step14_dbf_ip_soc_integration\ip_xsim mkdir results_step14_dbf_ip_soc_integration\ip_xsim
if not exist results_step14_dbf_ip_soc_integration\ip_synth mkdir results_step14_dbf_ip_soc_integration\ip_synth
(
echo metric,value
echo ip_catalog_registration_pass_flag,false
echo ipdef_count,0
echo ipdef_vlnv,user.org:radar:dbf_axis:1.0
echo create_ip_pass_flag,false
echo generate_target_pass_flag,false
echo generated_module_name,dbf_axis_0
echo simulation_target_generated_flag,false
echo synthesis_target_generated_flag,false
echo formal_result_claimed,false
echo blocker_if_any,vivado_unavailable
) > results_step14_dbf_ip_soc_integration\ip_package\step14_2_ip_catalog_summary.csv
(
echo metric,value
echo tool_vivado_found,false
echo tool_xvlog_found,false
echo tool_xelab_found,false
echo tool_xsim_found,false
echo ip_catalog_registration_pass_flag,false
echo create_ip_pass_flag,false
echo generate_simulation_target_pass_flag,false
echo compile_status,unavailable
echo elaboration_status,unavailable
echo simulation_status,unavailable
echo packaged_ip_tb_summary_created,false
echo packaged_ip_output_csv_created,false
echo packaged_ip_xsim_pass_flag,false
echo formal_result_claimed,false
echo blocker_if_any,vivado_unavailable
) > results_step14_dbf_ip_soc_integration\ip_xsim\step14_2_packaged_ip_xsim_summary.csv
(
echo metric,value
echo vivado_version,unavailable
echo fpga_part,unavailable
echo fpga_part_source,unavailable
echo reference_device_only,false
echo clock_MHz,200
echo clock_period_ns,5.000
echo packaged_ip_ooc_synthesis_status,unavailable
echo LUT,0
echo FF,0
echo DSP,0
echo BRAM18,0
echo BRAM36,0
echo URAM,0
echo distributed_RAM,0
echo WNS_ns,NA
echo timing_200MHz_met_flag,false
echo w_memory_inferred_flag,false
echo formal_result_claimed,false
echo implementation_closure_claimed,false
echo board_validation_flag,false
echo blocker_if_any,vivado_unavailable
) > results_step14_dbf_ip_soc_integration\ip_synth\step14_2_packaged_ip_ooc_synthesis_summary.csv
echo Vivado unavailable. Validation summaries written with unavailable status.
exit /b 0
