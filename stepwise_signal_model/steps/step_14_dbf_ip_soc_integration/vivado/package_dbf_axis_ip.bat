@echo off
setlocal
cd /d "%~dp0\.."

where vivado >nul 2>nul
if not errorlevel 1 (
    call vivado -mode batch -source vivado/package_dbf_axis_ip.tcl
    exit /b %ERRORLEVEL%
)

if defined VIVADO_SETTINGS64 if exist "%VIVADO_SETTINGS64%" (
    call "%VIVADO_SETTINGS64%"
    call vivado -mode batch -source vivado/package_dbf_axis_ip.tcl
    exit /b %ERRORLEVEL%
)

if not exist results_step14_dbf_ip_soc_integration\ip_package mkdir results_step14_dbf_ip_soc_integration\ip_package
(
echo metric,value
echo vivado_version,unavailable
echo fpga_part,unavailable
echo fpga_part_source,unavailable
echo reference_device_only,false
echo ip_vlnv,user.org:radar:dbf_axis:1.0
echo component_xml_created,false
echo ip_package_integrity_pass_flag,false
echo integrity_error_count,0
echo integrity_warning_count,0
echo s_axis_y_recognized_flag,false
echo m_axis_z_recognized_flag,false
echo aclk_recognized_flag,false
echo aresetn_recognized_flag,false
echo axis_clock_association_pass_flag,false
echo reset_polarity_pass_flag,false
echo packaged_hdl_file_count,0
echo packaged_w_mem_file_count,0
echo absolute_path_scan_pass_flag,false
echo formal_result_claimed,false
echo blocker_if_any,vivado_unavailable
) > results_step14_dbf_ip_soc_integration\ip_package\step14_2_ip_package_summary.csv
echo Vivado unavailable. Package summary written with unavailable status.
exit /b 0
