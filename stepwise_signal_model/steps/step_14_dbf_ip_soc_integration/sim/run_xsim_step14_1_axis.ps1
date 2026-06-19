$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$step14Dir = Resolve-Path (Join-Path $scriptDir "..")
Set-Location $step14Dir

$simDir = Join-Path $step14Dir "results_step14_dbf_ip_soc_integration\axis_sim"
New-Item -ItemType Directory -Force -Path $simDir | Out-Null
$summaryPath = Join-Path $simDir "step14_1_axis_xsim_summary.csv"

function Write-UnavailableSummary {
    param([string]$Path)
    @(
        "metric,value",
        "tool_xvlog_found,false",
        "tool_xelab_found,false",
        "tool_xsim_found,false",
        "compile_status,unavailable",
        "elaboration_status,unavailable",
        "simulation_status,unavailable",
        "tb_summary_created,false",
        "axis_output_csv_created,false",
        "formal_result_claimed,false",
        "dma_validation_flag,false",
        "ps_validation_flag,false",
        "board_validation_flag,false"
    ) | Set-Content -Encoding ASCII -Path $Path
}

$xvlogCmd = Get-Command xvlog -ErrorAction SilentlyContinue
$xelabCmd = Get-Command xelab -ErrorAction SilentlyContinue
$xsimCmd = Get-Command xsim -ErrorAction SilentlyContinue

if (-not $xvlogCmd -or -not $xelabCmd -or -not $xsimCmd) {
    Write-UnavailableSummary -Path $summaryPath
    Write-Host "Vivado XSim tools unavailable. Summary written with unavailable status."
    exit 0
}

function Write-XsimSummary {
    param(
        [string]$CompileStatus,
        [string]$ElaborationStatus,
        [string]$SimulationStatus
    )
    $tbSummary = Test-Path (Join-Path $simDir "step14_1_axis_tb_summary.csv")
    $axisOutput = Test-Path (Join-Path $simDir "step14_1_axis_output.csv")
    @(
        "metric,value",
        "tool_xvlog_found,true",
        "tool_xelab_found,true",
        "tool_xsim_found,true",
        "compile_status,$CompileStatus",
        "elaboration_status,$ElaborationStatus",
        "simulation_status,$SimulationStatus",
        "tb_summary_created,$($tbSummary.ToString().ToLower())",
        "axis_output_csv_created,$($axisOutput.ToString().ToLower())",
        "formal_result_claimed,false",
        "dma_validation_flag,false",
        "ps_validation_flag,false",
        "board_validation_flag,false"
    ) | Set-Content -Encoding ASCII -Path $summaryPath
}

function Test-TbPassFlag {
    $tbSummaryPath = Join-Path $simDir "step14_1_axis_tb_summary.csv"
    if (-not (Test-Path $tbSummaryPath)) {
        return $false
    }

    $passLine = Get-Content $tbSummaryPath | Where-Object { $_ -match "^axis_tb_pass_flag," } | Select-Object -First 1
    return ($passLine -match "^axis_tb_pass_flag,true$")
}

$files = @(
    "..\step_13_fpga_soc_dbf_boundary\rtl\dbf_complex_mac.v",
    "..\step_13_fpga_soc_dbf_boundary\rtl\dbf_beam_accum_core.v",
    "..\step_13_fpga_soc_dbf_boundary\rtl\dbf_z24_quantizer.v",
    "..\step_13_fpga_soc_dbf_boundary\rtl\dbf_core_z24.v",
    "..\step_13_fpga_soc_dbf_boundary\rtl\dbf_core_z24_bparallel.v",
    "rtl\dbf_w_provider_rom.v",
    "rtl\dbf_axis_z_serializer.v",
    "rtl\dbf_axis_datapath.v",
    "rtl\dbf_axis_system_top.v",
    "tb\tb_dbf_axis_system_top.v"
)

& $xvlogCmd.Source -sv @files
if ($LASTEXITCODE -ne 0) {
    Write-XsimSummary -CompileStatus "fail" -ElaborationStatus "not_run" -SimulationStatus "not_run"
    exit $LASTEXITCODE
}

& $xelabCmd.Source tb_dbf_axis_system_top -debug typical -s step14_1_axis_sim
if ($LASTEXITCODE -ne 0) {
    Write-XsimSummary -CompileStatus "pass" -ElaborationStatus "fail" -SimulationStatus "not_run"
    exit $LASTEXITCODE
}

& $xsimCmd.Source step14_1_axis_sim -tclbatch "sim/xsim_step14_1_run_all.tcl"
$simExit = $LASTEXITCODE
if ($simExit -ne 0) {
    Write-XsimSummary -CompileStatus "pass" -ElaborationStatus "pass" -SimulationStatus "fail"
    exit $simExit
}

if (-not (Test-Path (Join-Path $simDir "step14_1_axis_tb_summary.csv")) -or
    -not (Test-Path (Join-Path $simDir "step14_1_axis_output.csv"))) {
    Write-XsimSummary -CompileStatus "pass" -ElaborationStatus "pass" -SimulationStatus "fail"
    exit 1
}

if (-not (Test-TbPassFlag)) {
    Write-XsimSummary -CompileStatus "pass" -ElaborationStatus "pass" -SimulationStatus "fail"
    exit 1
}

Write-XsimSummary -CompileStatus "pass" -ElaborationStatus "pass" -SimulationStatus "pass"
