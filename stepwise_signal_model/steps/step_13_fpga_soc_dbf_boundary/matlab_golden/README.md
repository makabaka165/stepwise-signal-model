# Step13.2 MATLAB RTL Golden Vectors

This folder generates compact golden vectors for the Step13 DBF RTL
prototype. The scope is only the DBF accumulator kernel:

```text
Z = W^H Y
```

The default input source is `step11_light`, reusing the Step11-compatible
W/Y_work construction style from Step13.1 without running the Step11.7 full
backend.

Default settings:

- `STEP13_INPUT_SOURCE=step11_light`
- `STEP13_RTL_GOLDEN_MODE=mixed_W18_Y16_Z24`
- `STEP13_RTL_GOLDEN_N_LIMIT=64`
- `STEP13_RTL_GOLDEN_B_LIMIT=7`
- `STEP13_RTL_GOLDEN_L_LIMIT=4`

Run from the repository root:

```matlab
run('setup_paths.m')
cd('steps/step_13_fpga_soc_dbf_boundary/matlab_golden')
setenv('STEP13_INPUT_SOURCE','step11_light')
setenv('STEP13_RTL_GOLDEN_MODE','mixed_W18_Y16_Z24')
setenv('STEP13_RTL_GOLDEN_N_LIMIT','64')
setenv('STEP13_RTL_GOLDEN_L_LIMIT','4')
generate_step13_dbf_rtl_golden
```

Generated files are written under:

```text
../results_step13_fpga_soc_dbf_boundary/rtl_golden/
```

The first RTL smoke validates raw integer accumulators only. It does not
claim formal closure, full FPGA backend validation, board validation, or ML
score-core RTL completion.

