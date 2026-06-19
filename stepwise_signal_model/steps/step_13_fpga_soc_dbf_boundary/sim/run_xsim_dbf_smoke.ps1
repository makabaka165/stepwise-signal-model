param()

$ErrorActionPreference = "Stop"

function Get-Step13Root {
    $scriptDir = Split-Path -Parent $PSCommandPath
    if ((Split-Path -Leaf $scriptDir) -ieq "sim") {
        return (Resolve-Path (Join-Path $scriptDir "..")).Path
    }
    if (Test-Path (Join-Path $scriptDir "rtl")) {
        return (Resolve-Path $scriptDir).Path
    }
    return (Resolve-Path (Get-Location)).Path
}

function Write-XsimSummary {
    param(
        [string]$StepDir,
        [string]$Status,
        [bool]$XvlogFound,
        [bool]$XelabFound,
        [bool]$XsimFound,
        [string]$Note
    )
    $summaryPath = Join-Path $StepDir "results_step13_fpga_soc_dbf_boundary/rtl_sim/step13_dbf_rtl_sim_summary.csv"
    $lines = @(
        "metric,value",
        "simulation_status,$Status",
        "overall_simulation_status,$Status",
        "tool_xvlog_found,$($XvlogFound.ToString().ToLower())",
        "tool_xelab_found,$($XelabFound.ToString().ToLower())",
        "tool_xsim_found,$($XsimFound.ToString().ToLower())",
        "dbf_complex_mac_smoke,not_run",
        "dbf_core_accum_smoke,not_run",
        "dbf_z24_quantizer_smoke,not_run",
        "dbf_core_z24_smoke,not_run",
        "raw_accumulator_status,not_run",
        "z24_quantizer_status,not_run",
        "dbf_core_accum_output_csv_created,false",
        "dbf_core_z24_output_csv_created,false",
        "formal_result_claimed,false",
        "scope,DBF accumulator plus Z24 shift-round-saturate output datapath",
        "z24_shift_round_saturate_implemented,true",
        "rz_gcache_ml_topk_c05_implemented,false",
        "rz_gcache_ml_topk_c05_cpu_soc_responsibility,true",
        "note,$Note"
    )
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $summaryPath) | Out-Null
    Set-Content -LiteralPath $summaryPath -Value $lines -Encoding ASCII
}

$stepDir = Get-Step13Root
if (-not (Test-Path (Join-Path $stepDir "rtl")) -or
    -not (Test-Path (Join-Path $stepDir "tb")) -or
    -not (Test-Path (Join-Path $stepDir "sim"))) {
    Write-Error "Run from the Step13 DBF directory or its sim directory."
}

$xvlogCmd = Get-Command xvlog -ErrorAction SilentlyContinue
$xelabCmd = Get-Command xelab -ErrorAction SilentlyContinue
$xsimCmd = Get-Command xsim -ErrorAction SilentlyContinue
$vivadoCmd = Get-Command vivado -ErrorAction SilentlyContinue

$xvlogFound = $null -ne $xvlogCmd
$xelabFound = $null -ne $xelabCmd
$xsimFound = $null -ne $xsimCmd

if (-not $xvlogFound -or -not $xelabFound -or -not $xsimFound) {
    Write-XsimSummary -StepDir $stepDir -Status "unavailable" `
        -XvlogFound $xvlogFound -XelabFound $xelabFound -XsimFound $xsimFound `
        -Note "xsim_tools_not_available_run_vivado_settings64_or_vivado_shell"
    Write-Host "UNAVAILABLE: xvlog/xelab/xsim was not found on PATH. Run Vivado settings64.bat or use Vivado Tcl Shell."
    exit 3
}

if ($null -eq $vivadoCmd) {
    Write-XsimSummary -StepDir $stepDir -Status "unavailable" `
        -XvlogFound $xvlogFound -XelabFound $xelabFound -XsimFound $xsimFound `
        -Note "vivado_not_available_for_tcl_launcher"
    Write-Host "UNAVAILABLE: vivado was not found on PATH."
    exit 3
}

Push-Location $stepDir
try {
    & $vivadoCmd.Source -mode batch -source "sim/run_xsim_dbf_smoke.tcl"
    $exitCode = $LASTEXITCODE
} finally {
    Pop-Location
}

if ($exitCode -ne 0) {
    Write-Host "FAIL: Vivado xsim smoke returned exit code $exitCode."
    exit $exitCode
}

Write-Host "Step13.3 Vivado xsim DBF smoke completed."
