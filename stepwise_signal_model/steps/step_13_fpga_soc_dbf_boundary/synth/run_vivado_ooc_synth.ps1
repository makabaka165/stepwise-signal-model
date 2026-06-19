param()

$ErrorActionPreference = "Stop"

function Get-Step13Root {
    $scriptDir = Split-Path -Parent $PSCommandPath
    if ((Split-Path -Leaf $scriptDir) -ieq "synth") {
        return (Resolve-Path (Join-Path $scriptDir "..")).Path
    }
    return (Resolve-Path (Get-Location)).Path
}

function Write-UnavailableSummary {
    param(
        [string]$StepDir,
        [string]$Note
    )
    $outDir = Join-Path $StepDir "results_step13_fpga_soc_dbf_boundary/synth"
    New-Item -ItemType Directory -Force -Path $outDir | Out-Null
    $summaryPath = Join-Path $outDir "step13_4_ooc_synthesis_summary.csv"
    Set-Content -LiteralPath $summaryPath -Encoding ASCII -Value @(
        "metric,value",
        "vivado_version,unavailable",
        "fpga_part,unavailable",
        "fpga_part_source,unavailable",
        "reference_device_only,false",
        "clock_MHz,200",
        "clock_period_ns,5",
        "single_lane_synthesis_status,unavailable",
        "b7_synthesis_status,unavailable",
        "ooc_synthesis_pass_flag,false",
        "timing_200MHz_met_flag,false",
        "formal_result_claimed,false",
        "implementation_closure_claimed,false",
        "board_validation_flag,false",
        "blocker_if_any,$Note"
    )
}

$stepDir = Get-Step13Root
if (-not (Test-Path (Join-Path $stepDir "rtl")) -or
    -not (Test-Path (Join-Path $stepDir "synth"))) {
    Write-Error "Run from the Step13 DBF directory or its synth directory."
}

$vivadoCmd = Get-Command vivado -ErrorAction SilentlyContinue
if ($null -eq $vivadoCmd) {
    Write-UnavailableSummary -StepDir $stepDir -Note "vivado_not_available_run_settings64_or_vivado_shell"
    Write-Host "UNAVAILABLE: vivado was not found on PATH."
    exit 3
}

Push-Location $stepDir
try {
    & $vivadoCmd.Source -mode batch -source "synth/run_vivado_ooc_synth.tcl"
    $exitCode = $LASTEXITCODE
} finally {
    Pop-Location
}

if ($exitCode -ne 0) {
    Write-Host "FAIL: Step13.4 Vivado OOC synthesis returned exit code $exitCode."
    exit $exitCode
}

Write-Host "Step13.4 Vivado OOC synthesis completed."
