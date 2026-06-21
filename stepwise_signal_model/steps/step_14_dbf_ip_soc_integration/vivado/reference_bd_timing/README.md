# Step14.3b Reference BD Timing

This directory contains the Reference BD timing-closure flow.

Run Phase A strategy sweep from the Step14 directory:

```powershell
powershell -ExecutionPolicy Bypass -File vivado/reference_bd_timing/run_reference_bd_strategy_sweep.ps1
```

Run the closure wrapper, which performs the sweep and a clean rerun only when
the sweep finds a strategy with at least 0.100 ns WNS margin:

```powershell
powershell -ExecutionPolicy Bypass -File vivado/reference_bd_timing/run_reference_bd_timing_closure.ps1
```

The flow keeps the same RTL, Custom IP VLNV, Reference BD topology, FIFO sizes,
clock period, and XDC constraints during Phase A. It does not create bitstreams,
XSA/HWH, PS, DMA, AXI-Lite, SmartConnect, ILA, board constraints, or CPU
software.

Phase A writes:

```text
results_step14_dbf_ip_soc_integration/reference_bd_timing/
  step14_3b_available_strategies.csv
  step14_3b_unavailable_requested_strategies.csv
  step14_3b_strategy_sweep.csv
  step14_3b_best_strategy.csv
  step14_3b_best_strategy_clean_rerun_summary.csv
  step14_3b_baseline_timing_summary.rpt
  step14_3b_best_timing_summary.rpt
  step14_3b_best_timing_paths.rpt
  step14_3b_best_utilization.rpt
  step14_3b_best_drc_summary.csv
  step14_3b_best_methodology_summary.csv
  step14_3b_timing_resource_comparison.csv
```

The best strategy must pass both the sweep and a clean rerun:

```text
WNS >= 0.100 ns
TNS == 0
setup failing endpoints == 0
hold failing endpoints == 0
```

After Vivado finishes, aggregate the final gate from MATLAB:

```matlab
run('setup_paths.m');
cd('steps/step_14_dbf_ip_soc_integration');
run_step14_3b_reference_bd_timing_validation
```

The aggregator writes
`results_step14_dbf_ip_soc_integration/reference_bd_timing/step14_3b_reference_bd_timing_keypoints.csv`.
