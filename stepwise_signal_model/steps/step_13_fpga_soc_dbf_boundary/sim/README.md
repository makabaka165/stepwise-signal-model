# Step13.2a Icarus Verilog Smoke

Run from the Step13 DBF boundary directory with bash when available:

```bash
bash sim/run_iverilog_dbf_smoke.sh
```

On Windows, run either:

```powershell
powershell -ExecutionPolicy Bypass -File sim/run_iverilog_dbf_smoke.ps1
```

or:

```cmd
sim\run_iverilog_dbf_smoke.cmd
```

The PowerShell script can also be launched from the `sim/` directory. It
auto-locates the Step13 directory, checks for `iverilog` and `vvp`, compiles
the DBF accumulator RTL prototype and testbenches when tools are available,
and writes small simulation outputs under:

```text
results_step13_fpga_soc_dbf_boundary/rtl_sim/
```

If `iverilog` or `vvp` is unavailable, the scripts do not report a false pass.
They write:

```text
results_step13_fpga_soc_dbf_boundary/rtl_sim/step13_dbf_rtl_sim_summary.csv
```

with `simulation_status=unavailable`, `formal_result_claimed=false`, and
`note=iverilog_or_vvp_not_available`.

It does not create or track waveform files by default.

This smoke only validates the raw accumulator for `Z = W^H Y`. It does not
implement Z24 shift/round/saturate, `Rz`, `G_cache`, 2D ML search, topK, C05,
confidence, fallback, timing closure, board validation, or formal closure.
