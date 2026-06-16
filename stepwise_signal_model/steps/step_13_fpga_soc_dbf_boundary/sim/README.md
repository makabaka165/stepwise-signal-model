# Step13.2 Icarus Verilog Smoke

Run from the Step13 DBF boundary directory:

```bash
bash sim/run_iverilog_dbf_smoke.sh
```

The script checks for `iverilog` and `vvp`, compiles the DBF accumulator RTL
prototype and testbenches, and writes small simulation outputs under:

```text
results_step13_fpga_soc_dbf_boundary/rtl_sim/
```

It does not create or track waveform files by default.

