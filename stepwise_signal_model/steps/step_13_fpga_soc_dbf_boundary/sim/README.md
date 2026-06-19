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

The historical Step13.2 smoke only validated the raw accumulator for
`Z = W^H Y`. Step13.3 adds the DBF Z24 output datapath smoke:

```text
ACC raw accumulator -> shift -> round -> saturate -> signed int24 Z output
```

It still does not implement `Rz`, `G_cache`, 2D ML search, topK, C05,
confidence, boundary, fallback, timing closure, board validation, or formal
closure.
`Rz/G_cache/2D ML/topK/C05/confidence/fallback` are intentionally outside the
Step13 FPGA RTL scope and remain CPU/SoC responsibilities by design. Their
absence from the RTL smoke is not missing project work.

## Vivado XSim

Step13.2b adds a Vivado XSim toolchain smoke:

```powershell
powershell -ExecutionPolicy Bypass -File sim/run_xsim_dbf_smoke.ps1
```

or:

```cmd
sim\run_xsim_dbf_smoke.bat
```

These wrappers run:

```text
vivado -mode batch -source sim/run_xsim_dbf_smoke.tcl
```

after Vivado tools are available on `PATH`. The Tcl script compiles the RTL and
testbenches with `xvlog`, elaborates with `xelab`, runs `xsim`, and writes:

```text
results_step13_fpga_soc_dbf_boundary/rtl_sim/dbf_core_accum_output.csv
results_step13_fpga_soc_dbf_boundary/rtl_sim/step13_dbf_rtl_sim_summary.csv
```

Current Step13.3 XSim status in this environment:

- `simulation_status=pass`
- `dbf_complex_mac_smoke=pass`
- `dbf_core_accum_smoke=pass`
- `dbf_z24_quantizer_smoke=pass`
- `dbf_core_z24_smoke=pass`
- `dbf_core_accum_output_csv_created=true`
- `dbf_core_z24_output_csv_created=true`
- MATLAB compare `comparison_status=pass`
- `accumulator_match_flag=true`
- `z24_match_flag=true`
- `Z_shift_bits=12`
- compact golden `N=64, B=7, L=4`
- full reference shape `N=2080, B=7, L=16`

Generated `.jou`, `.log`, `.wdb`, `.pb`, and `xsim.dir/` files are ignored.

## Step13.4 Full-N XSim

Step13.4 adds a full-N Vivado XSim smoke:

```powershell
powershell -ExecutionPolicy Bypass -File sim/run_xsim_step13_4_fulln.ps1
```

or:

```cmd
sim\run_xsim_step13_4_fulln.bat
```

The Tcl entry point is `sim/run_xsim_step13_4_fulln.tcl`. It keeps the compact
raw accumulator and compact Z24 smoke, then runs the full-N B=7 testbench.

Current status:

- `compact_raw_accumulator_status=pass`
- `compact_z24_status=pass`
- `fulln_N=2080`, `fulln_B=7`, `fulln_L=2`
- `fulln_ACC_bits=48`, `fulln_Z_bits=24`
- `engineering_Z_shift_bits=20`
- no-gap frame: `pass`
- valid-gap frame: `pass`
- `fulln_accumulator_match_flag=true`
- `fulln_z24_match_flag=true`
- `fulln_missing_count=0`
- `fulln_mismatch_count=0`
- `fulln_clip_count=0`
- `fulln_overflow_count=0`
- `simulation_status=pass`
- `formal_result_claimed=false`

This smoke is not formal proof, timing closure, implementation closure, or
board validation.
