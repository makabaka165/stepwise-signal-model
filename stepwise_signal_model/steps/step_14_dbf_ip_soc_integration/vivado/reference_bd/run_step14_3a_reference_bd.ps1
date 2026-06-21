$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$Step14Dir = Resolve-Path (Join-Path $ScriptDir "..\..")
$ResultDir = Join-Path $Step14Dir "results_step14_dbf_ip_soc_integration\reference_bd"
New-Item -ItemType Directory -Force -Path $ResultDir | Out-Null

$VivadoSettings = $env:VIVADO_SETTINGS64
if (-not $VivadoSettings -and (Test-Path "E:\Xilinx\Vivado\2024.2\settings64.bat")) {
    $VivadoSettings = "E:\Xilinx\Vivado\2024.2\settings64.bat"
}

$UseSubst = $false
$SubstDrive = "S:"
if (-not (Test-Path "$SubstDrive\")) {
    cmd /c "subst $SubstDrive `"$Step14Dir`""
    $UseSubst = $true
    $Tcl = "$SubstDrive\vivado\reference_bd\run_step14_3a_reference_bd.tcl"
} else {
    $Tcl = Join-Path $ScriptDir "run_step14_3a_reference_bd.tcl"
}

try {
    if ($VivadoSettings) {
        cmd /c "call `"$VivadoSettings`" && vivado -mode batch -source `"$Tcl`""
    } else {
        vivado -mode batch -source $Tcl
    }
} finally {
    if ($UseSubst) {
        cmd /c "subst $SubstDrive /D" | Out-Null
    }
}

if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}
