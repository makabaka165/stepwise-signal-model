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

if (-not (Get-Command xvlog -ErrorAction SilentlyContinue) -or
    -not (Get-Command xelab -ErrorAction SilentlyContinue) -or
    -not (Get-Command xsim -ErrorAction SilentlyContinue)) {
    Write-UnavailableSummary -Path $summaryPath
    Write-Host "Vivado XSim tools unavailable. Summary written with unavailable status."
    exit 0
}

vivado -mode batch -source sim/run_xsim_step14_1_axis.tcl
