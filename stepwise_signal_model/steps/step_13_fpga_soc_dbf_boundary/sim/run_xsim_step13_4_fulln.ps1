param()

$ErrorActionPreference = "Stop"

function Get-Step13Root {
    $scriptDir = Split-Path -Parent $PSCommandPath
    if ((Split-Path -Leaf $scriptDir) -ieq "sim") {
        return (Resolve-Path (Join-Path $scriptDir "..")).Path
    }
    return (Resolve-Path (Get-Location)).Path
}

$stepDir = Get-Step13Root
if (-not (Test-Path (Join-Path $stepDir "rtl")) -or
    -not (Test-Path (Join-Path $stepDir "tb")) -or
    -not (Test-Path (Join-Path $stepDir "sim"))) {
    Write-Error "Run from the Step13 DBF directory or its sim directory."
}

$vivadoCmd = Get-Command vivado -ErrorAction SilentlyContinue
if ($null -eq $vivadoCmd) {
    $summaryPath = Join-Path $stepDir "results_step13_fpga_soc_dbf_boundary/rtl_fulln_sim/step13_4_fulln_xsim_summary.csv"
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $summaryPath) | Out-Null
    Set-Content -LiteralPath $summaryPath -Encoding ASCII -Value @(
        "metric,value",
        "tool_xvlog_found,false",
        "tool_xelab_found,false",
        "tool_xsim_found,false",
        "simulation_status,unavailable",
        "formal_result_claimed,false",
        "note,vivado_not_available_run_settings64_or_vivado_shell"
    )
    Write-Host "UNAVAILABLE: vivado was not found on PATH."
    exit 3
}

Push-Location $stepDir
try {
    & $vivadoCmd.Source -mode batch -source "sim/run_xsim_step13_4_fulln.tcl"
    $exitCode = $LASTEXITCODE
} finally {
    Pop-Location
}

if ($exitCode -ne 0) {
    Write-Host "FAIL: Step13.4 Vivado XSim returned exit code $exitCode."
    exit $exitCode
}

Write-Host "Step13.4 Vivado XSim full-N DBF smoke completed."
