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

function Write-SimSummary {
    param(
        [string]$StepDir,
        [string]$Status,
        [bool]$IverilogFound,
        [bool]$VvpFound,
        [string]$Note,
        [bool]$OutputCsvGenerated = $false
    )
    $summaryPath = Join-Path $StepDir "results_step13_fpga_soc_dbf_boundary/rtl_sim/step13_dbf_rtl_sim_summary.csv"
    $lines = @(
        "metric,value",
        "simulation_status,$Status",
        "tool_iverilog_found,$($IverilogFound.ToString().ToLower())",
        "tool_vvp_found,$($VvpFound.ToString().ToLower())",
        "dbf_core_accum_output_csv_generated,$($OutputCsvGenerated.ToString().ToLower())",
        "formal_result_claimed,false",
        "scope,raw DBF accumulator Z = W^H Y",
        "z24_shift_round_saturate_implemented,false",
        "rz_gcache_ml_topk_c05_implemented,false",
        "note,$Note"
    )
    Set-Content -LiteralPath $summaryPath -Value $lines -Encoding ASCII
}

function Invoke-Checked {
    param(
        [string]$StepDir,
        [bool]$IverilogFound,
        [bool]$VvpFound,
        [string]$Exe,
        [string[]]$Args,
        [string]$FailNote
    )
    & $Exe @Args
    if ($LASTEXITCODE -ne 0) {
        Write-SimSummary -StepDir $StepDir -Status "fail" `
            -IverilogFound $IverilogFound -VvpFound $VvpFound -Note $FailNote
        exit $LASTEXITCODE
    }
}

$stepDir = Get-Step13Root
if (-not (Test-Path (Join-Path $stepDir "rtl")) -or
    -not (Test-Path (Join-Path $stepDir "tb")) -or
    -not (Test-Path (Join-Path $stepDir "sim"))) {
    Write-Error "Run from the Step13 DBF directory or its sim directory."
}

$simDir = Join-Path $stepDir "results_step13_fpga_soc_dbf_boundary/rtl_sim"
New-Item -ItemType Directory -Force -Path $simDir | Out-Null

$iverilogCmd = Get-Command iverilog -ErrorAction SilentlyContinue
$vvpCmd = Get-Command vvp -ErrorAction SilentlyContinue
$iverilogFound = $null -ne $iverilogCmd
$vvpFound = $null -ne $vvpCmd

if (-not $iverilogFound -or -not $vvpFound) {
    Write-SimSummary -StepDir $stepDir -Status "unavailable" `
        -IverilogFound $iverilogFound -VvpFound $vvpFound `
        -Note "iverilog_or_vvp_not_available"
    Write-Host "UNAVAILABLE: iverilog or vvp was not found on PATH."
    exit 3
}

$goldenVh = Join-Path $stepDir "results_step13_fpga_soc_dbf_boundary/rtl_golden/step13_dbf_rtl_golden_vectors.vh"
if (-not (Test-Path -LiteralPath $goldenVh)) {
    Write-SimSummary -StepDir $stepDir -Status "unavailable" `
        -IverilogFound $iverilogFound -VvpFound $vvpFound `
        -Note "golden_vectors_not_available"
    Write-Host "UNAVAILABLE: missing results_step13_fpga_soc_dbf_boundary/rtl_golden/step13_dbf_rtl_golden_vectors.vh"
    exit 4
}

$coreOutputCsv = Join-Path $simDir "dbf_core_accum_output.csv"
$simSummary = Join-Path $simDir "step13_dbf_rtl_sim_summary.csv"
Remove-Item -LiteralPath $coreOutputCsv -ErrorAction SilentlyContinue
Remove-Item -LiteralPath $simSummary -ErrorAction SilentlyContinue
Remove-Item -LiteralPath (Join-Path $simDir "tb_dbf_complex_mac.vvp") -ErrorAction SilentlyContinue
Remove-Item -LiteralPath (Join-Path $simDir "tb_dbf_core_accum.vvp") -ErrorAction SilentlyContinue

Push-Location $stepDir
try {
    Invoke-Checked -StepDir $stepDir -IverilogFound $iverilogFound -VvpFound $vvpFound `
        -Exe $iverilogCmd.Source `
        -Args @("-g2001", "-Wall", "-o", "results_step13_fpga_soc_dbf_boundary/rtl_sim/tb_dbf_complex_mac.vvp",
            "rtl/dbf_complex_mac.v", "tb/tb_dbf_complex_mac.v") `
        -FailNote "iverilog_compile_tb_dbf_complex_mac_failed"

    Invoke-Checked -StepDir $stepDir -IverilogFound $iverilogFound -VvpFound $vvpFound `
        -Exe $vvpCmd.Source `
        -Args @("results_step13_fpga_soc_dbf_boundary/rtl_sim/tb_dbf_complex_mac.vvp") `
        -FailNote "vvp_tb_dbf_complex_mac_failed"

    Invoke-Checked -StepDir $stepDir -IverilogFound $iverilogFound -VvpFound $vvpFound `
        -Exe $iverilogCmd.Source `
        -Args @("-g2001", "-Wall", "-I", "results_step13_fpga_soc_dbf_boundary/rtl_golden",
            "-o", "results_step13_fpga_soc_dbf_boundary/rtl_sim/tb_dbf_core_accum.vvp",
            "rtl/dbf_complex_mac.v", "rtl/dbf_beam_accum_core.v", "rtl/dbf_core_accum.v",
            "tb/tb_dbf_core_accum.v") `
        -FailNote "iverilog_compile_tb_dbf_core_accum_failed"

    Invoke-Checked -StepDir $stepDir -IverilogFound $iverilogFound -VvpFound $vvpFound `
        -Exe $vvpCmd.Source `
        -Args @("results_step13_fpga_soc_dbf_boundary/rtl_sim/tb_dbf_core_accum.vvp") `
        -FailNote "vvp_tb_dbf_core_accum_failed"
} finally {
    Pop-Location
}

$outputGenerated = Test-Path -LiteralPath $coreOutputCsv
if (-not $outputGenerated) {
    Write-SimSummary -StepDir $stepDir -Status "fail" `
        -IverilogFound $iverilogFound -VvpFound $vvpFound `
        -Note "dbf_core_accum_output_csv_missing"
    exit 5
}

Write-SimSummary -StepDir $stepDir -Status "pass" `
    -IverilogFound $iverilogFound -VvpFound $vvpFound `
    -Note "rtl_accumulator_smoke_passed" -OutputCsvGenerated $true
Write-Host "Step13.2a iverilog DBF smoke PASS. Outputs: results_step13_fpga_soc_dbf_boundary/rtl_sim"
