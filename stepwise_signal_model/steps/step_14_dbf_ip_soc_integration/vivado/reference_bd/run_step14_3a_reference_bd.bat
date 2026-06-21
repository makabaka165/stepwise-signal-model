@echo off
setlocal
set SCRIPT_DIR=%~dp0
for %%I in ("%SCRIPT_DIR%..\..") do set STEP14_DIR=%%~fI
set USE_SUBST=0
set SUBST_DRIVE=S:
if not exist %SUBST_DRIVE%\NUL (
  subst %SUBST_DRIVE% "%STEP14_DIR%"
  set USE_SUBST=1
  set TCL=%SUBST_DRIVE%\vivado\reference_bd\run_step14_3a_reference_bd.tcl
) else (
  set TCL=%SCRIPT_DIR%run_step14_3a_reference_bd.tcl
)

if not "%VIVADO_SETTINGS64%"=="" (
  call "%VIVADO_SETTINGS64%"
) else if exist "E:\Xilinx\Vivado\2024.2\settings64.bat" (
  call "E:\Xilinx\Vivado\2024.2\settings64.bat"
)

vivado -mode batch -source "%TCL%"
set VIVADO_RC=%ERRORLEVEL%
if "%USE_SUBST%"=="1" subst %SUBST_DRIVE% /D
exit /b %VIVADO_RC%
