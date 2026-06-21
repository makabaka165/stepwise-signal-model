$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$Step14Dir = Resolve-Path (Join-Path $ScriptDir "..")
Set-Location $Step14Dir

if ($env:VIVADO_SETTINGS64 -and (Test-Path $env:VIVADO_SETTINGS64)) {
    cmd /c "call `"$env:VIVADO_SETTINGS64`" && vivado -mode batch -source sim/run_xsim_step14_2b_hardening.tcl"
} elseif (Test-Path "E:\Xilinx\Vivado\2024.2\settings64.bat") {
    cmd /c "call `"E:\Xilinx\Vivado\2024.2\settings64.bat`" && vivado -mode batch -source sim/run_xsim_step14_2b_hardening.tcl"
} else {
    vivado -mode batch -source sim/run_xsim_step14_2b_hardening.tcl
}
