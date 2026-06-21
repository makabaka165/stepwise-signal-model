@echo off
setlocal
cd /d "%~dp0.."
if defined VIVADO_SETTINGS64 (
  call "%VIVADO_SETTINGS64%"
) else if exist "E:\Xilinx\Vivado\2024.2\settings64.bat" (
  call "E:\Xilinx\Vivado\2024.2\settings64.bat"
)
vivado -mode batch -source sim/run_xsim_step14_2b_hardening.tcl
