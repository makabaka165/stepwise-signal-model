# Step13 FPGA/SoC DBF Boundary Validation

Step13 is the FPGA/SoC boundary closure step for the thesis engineering route. Its main line is FPGA/SoC collaborative boundary closure plus an FPGA DBF implementation plan. The FPGA-side kernel under study is digital beamforming:

```text
Z = W^H Y
```

where `Y` is array-domain or local work-subarray data, `W` is the DBF weight matrix, and `Z` is beamspace data for the CPU/SoC-side beamspace ML flow.

## Relationship To Step11 And Step12

Step11 and Step12 remain valuable as algorithm and fixed-point context. Step12 `mixed_Z16_G24_Rz24` is evidence for a future ML score-core accelerator. It is not the default recommendation for Step13 DBF W/Y/Z formatting.

Step13 DBF starts from these candidate formats:

- `mixed_W18_Y16_Z24`
- `mixed_W24_Y16_Z24`

A Step13 DBF pass only means the FPGA DBF boundary is feasible. It does not claim full ML backend FPGA closure.

## FPGA / CPU-SoC Partition

FPGA responsibilities:

- high-speed, regular, streaming, parallel DBF computation
- `Z = W^H Y`
- array-domain or local work-subarray data to beamspace conversion
- W storage/read
- complex multiply-accumulate pipeline
- fixed-point scale, rounding, saturation
- Z output interface

FPGA does not own:

- full 2D ML search
- full C05 policy, confidence, fallback, or boundary hardening

CPU/SoC responsibilities:

- receive FPGA output beamspace data `Z`
- construct or read `Rz = Z Z^H`
- manage `G_cache`
- execute beamspace ML 2D candidate search
- execute score ranking / topK
- execute C05 policy
- execute confidence / boundary / fallback
- own logs, debug, strategy control, and final output

Step13 does not change the Step11.7 backend default behavior.

## DBF Versus Beam Pattern

DBF means Digital Beamforming. DBF is not the beam pattern itself. DBF is the real-time operation that multiplies multi-element signals by complex weights and coherently sums them:

```text
z_b(t) = w_b^H x(t)
```

For multiple beams:

```text
Z = W^H Y
```

The beam pattern is the spatial response of a weight vector against steering vectors:

```text
B(theta, phi) = |w^H a(theta, phi)|
```

So DBF is a real-time compute module; the beam pattern is an analysis result of the weights. The beam pattern can explain DBF weight behavior, but it is not the DBF module.

## MATLAB Quick/Smoke

Run only quick/smoke validation in this step:

```matlab
run('setup_paths.m')
cd('steps/step_13_fpga_soc_dbf_boundary')
setenv('STEP13_QUICK_MODE','1')
run_step13_fpga_soc_dbf_boundary
```

The short wrapper is:

```matlab
dbf_fpga_soc_boundary
```

The smoke script uses synthetic W/Y inputs when upstream builders are unavailable. It does not run Step11.7 full backend as default behavior and does not fabricate formal results.

## Outputs

Outputs are written to:

```text
steps/step_13_fpga_soc_dbf_boundary/results_step13_fpga_soc_dbf_boundary/
```

Expected CSV outputs:

- `step13_dbf_fixed_point_trial.csv`
- `step13_dbf_fixed_point_summary.csv`
- `step13_dbf_keypoints.csv`
- `step13_dbf_resource_estimate.csv`
- `step13_fpga_soc_partition.csv`
- `step13_interface_fields.csv`
- `step13_recommendations.csv`

Expected figures:

- `dbf_z_error_by_quant_mode.png`
- `dbf_beam_power_error_by_quant_mode.png`
- `dbf_resource_estimate.png`
- `fpga_soc_partition_diagram.png`
- `dbf_pipeline_diagram.png`

## What This Step Is Not

Step13 is not:

- an ML score-core RTL prototype
- a complete FPGA backend
- a complete 2D ML search hardware implementation
- Step11.7 full backend RTL
- complete C05 policy / confidence / fallback / boundary hardening in hardware

Quick/smoke results are not formal closure. Formal claims require a later, explicitly scoped validation pass.
