$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$step14Dir = Resolve-Path (Join-Path $scriptDir "..")
Set-Location $step14Dir

$vivado = Get-Command vivado -ErrorAction SilentlyContinue
if (-not $vivado) {
    $settings = $env:VIVADO_SETTINGS64
    if ($settings -and (Test-Path $settings)) {
        cmd /c "call `"$settings`" && vivado -mode batch -source vivado/validate_dbf_axis_ip.tcl"
        exit $LASTEXITCODE
    }

    $pkgDir = Join-Path $step14Dir "results_step14_dbf_ip_soc_integration\ip_package"
    $xsimDir = Join-Path $step14Dir "results_step14_dbf_ip_soc_integration\ip_xsim"
    $synthDir = Join-Path $step14Dir "results_step14_dbf_ip_soc_integration\ip_synth"
    New-Item -ItemType Directory -Force -Path $pkgDir | Out-Null
    New-Item -ItemType Directory -Force -Path $xsimDir | Out-Null
    New-Item -ItemType Directory -Force -Path $synthDir | Out-Null
    @(
        "metric,value",
        "ip_catalog_registration_pass_flag,false",
        "ipdef_count,0",
        "ipdef_vlnv,user.org:radar:dbf_axis:1.0",
        "create_ip_pass_flag,false",
        "generate_target_pass_flag,false",
        "generated_module_name,dbf_axis_0",
        "simulation_target_generated_flag,false",
        "synthesis_target_generated_flag,false",
        "formal_result_claimed,false",
        "blocker_if_any,vivado_unavailable"
    ) | Set-Content -Encoding ASCII -Path (Join-Path $pkgDir "step14_2_ip_catalog_summary.csv")
    @(
        "metric,value",
        "tool_vivado_found,false",
        "tool_xvlog_found,false",
        "tool_xelab_found,false",
        "tool_xsim_found,false",
        "ip_catalog_registration_pass_flag,false",
        "create_ip_pass_flag,false",
        "generate_simulation_target_pass_flag,false",
        "compile_status,unavailable",
        "elaboration_status,unavailable",
        "simulation_status,unavailable",
        "packaged_ip_tb_summary_created,false",
        "packaged_ip_output_csv_created,false",
        "packaged_ip_xsim_pass_flag,false",
        "formal_result_claimed,false",
        "blocker_if_any,vivado_unavailable"
    ) | Set-Content -Encoding ASCII -Path (Join-Path $xsimDir "step14_2_packaged_ip_xsim_summary.csv")
    @(
        "metric,value",
        "vivado_version,unavailable",
        "fpga_part,unavailable",
        "fpga_part_source,unavailable",
        "reference_device_only,false",
        "clock_MHz,200",
        "clock_period_ns,5.000",
        "packaged_ip_ooc_synthesis_status,unavailable",
        "LUT,0",
        "FF,0",
        "DSP,0",
        "BRAM18,0",
        "BRAM36,0",
        "URAM,0",
        "distributed_RAM,0",
        "WNS_ns,NA",
        "timing_200MHz_met_flag,false",
        "w_memory_inferred_flag,false",
        "formal_result_claimed,false",
        "implementation_closure_claimed,false",
        "board_validation_flag,false",
        "blocker_if_any,vivado_unavailable"
    ) | Set-Content -Encoding ASCII -Path (Join-Path $synthDir "step14_2_packaged_ip_ooc_synthesis_summary.csv")
    Write-Host "Vivado unavailable. Validation summaries written with unavailable status."
    exit 0
}

& $vivado.Source -mode batch -source vivado/validate_dbf_axis_ip.tcl
exit $LASTEXITCODE
