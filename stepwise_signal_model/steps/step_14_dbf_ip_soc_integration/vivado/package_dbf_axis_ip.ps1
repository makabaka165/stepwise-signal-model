$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$step14Dir = Resolve-Path (Join-Path $scriptDir "..")
Set-Location $step14Dir

$vivado = Get-Command vivado -ErrorAction SilentlyContinue
if (-not $vivado) {
    $settings = $env:VIVADO_SETTINGS64
    if ($settings -and (Test-Path $settings)) {
        cmd /c "call `"$settings`" && vivado -mode batch -source vivado/package_dbf_axis_ip.tcl"
        exit $LASTEXITCODE
    }
    $resultDir = Join-Path $step14Dir "results_step14_dbf_ip_soc_integration\ip_package"
    New-Item -ItemType Directory -Force -Path $resultDir | Out-Null
    @(
        "metric,value",
        "vivado_version,unavailable",
        "fpga_part,unavailable",
        "fpga_part_source,unavailable",
        "reference_device_only,false",
        "ip_vlnv,user.org:radar:dbf_axis:1.0",
        "component_xml_created,false",
        "ip_package_integrity_pass_flag,false",
        "integrity_error_count,0",
        "integrity_warning_count,0",
        "s_axis_y_recognized_flag,false",
        "m_axis_z_recognized_flag,false",
        "aclk_recognized_flag,false",
        "aresetn_recognized_flag,false",
        "axis_clock_association_pass_flag,false",
        "reset_polarity_pass_flag,false",
        "packaged_hdl_file_count,0",
        "packaged_w_mem_file_count,0",
        "absolute_path_scan_pass_flag,false",
        "formal_result_claimed,false",
        "blocker_if_any,vivado_unavailable"
    ) | Set-Content -Encoding ASCII -Path (Join-Path $resultDir "step14_2_ip_package_summary.csv")
    Write-Host "Vivado unavailable. Package summary written with unavailable status."
    exit 0
}

& $vivado.Source -mode batch -source vivado/package_dbf_axis_ip.tcl
exit $LASTEXITCODE
