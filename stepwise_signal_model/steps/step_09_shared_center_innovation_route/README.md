# Archived Step09 Diagnostics And Thesis-Interface Notes

Step09 is now frozen as an archived diagnostics and interface-positioning layer. It is not the final algorithm backend.

Final thesis route:

```text
../step_10_final_thesis_route/
```

Final backend decision:

- Step09 backend tuning is frozen.
- Step09-light is not final.
- Step87 bridge inside Step09 is diagnostic only.
- common-el gate alignment is not adopted.
- Final backend evidence is the original Step8.7 verified lazy cascade.
- Step09 retains value as shared-center interface framing and negative route-decision evidence.

The final thesis route is:

```text
Frontend detection / coarse angle
-> shared-center 65-column local work subarray
-> Y_work construction
-> Step8.7 verified lazy cascade backend
-> confidence / boundary output
-> FPGA/SoC implementation boundary
```

## Retained Interface Notes

The following files remain in `main/` only as interface demonstrations:

- `main/shared_center_select_subarray.m`
- `main/build_y_work_from_frontend.m`

They document the shared-center handoff:

```text
selectedCenterColumn = argmin_k |wrap180(phiCol(k) - coarseAz)|
selectedWorkColumns = selectedCenterColumn + [-32, ..., 0, ..., +32]
Y_work in C^(65 x 32 x Np)
```

## Retained Decision Evidence

- `docs/17_FINAL_BACKEND_DECISION.md`
- `docs/18_FALLBACK_TO_STEP87_FINAL_DECISION.md`
- `docs/19_FINAL_THESIS_ROUTE_SUMMARY.md`
- `results_step09_final_decision.csv`
- `archive/diagnostic_results/results_step09_common_el_gate_alignment/step09_common_el_gate_alignment_keypoints.csv`

The final Step09 decision is:

```text
gate_alignment_pass_flag = 0
blocker_if_any = gate_alignment_failed_false_high
final_recommendation = freeze_step09_backend_use_step87_verified_lazy_cascade
```

Gate 2 recovered close-coherent success to `0.87333`, but safety failed:

```text
overall_false_high_rate = 0.034722
single_target_false_split_rate = 0.83333
```

## Archived Diagnostic Commands

These commands are retained only for reproducibility of negative / diagnostic evidence. They are not part of the final thesis route.

```matlab
run('steps/step_09_shared_center_innovation_route/archive/diagnostic_scripts/run_step09_formal_monte_carlo.m')
run('steps/step_09_shared_center_innovation_route/archive/diagnostic_scripts/run_step09_vs_step87_consistency_check.m')
run('steps/step_09_shared_center_innovation_route/archive/diagnostic_scripts/run_step09_ablation_study.m')
run('steps/step_09_shared_center_innovation_route/archive/diagnostic_scripts/run_step09_step87_backend_bridge_validation.m')
run('steps/step_09_shared_center_innovation_route/archive/diagnostic_scripts/run_step09_close_coherent_gate_diagnostics.m')
run('steps/step_09_shared_center_innovation_route/archive/diagnostic_scripts/run_step09_common_el_gate_alignment.m')
```

Archived groups:

- formal MC;
- ablation;
- Step09-vs-Step87 consistency;
- Step87 bridge;
- close coherent diagnostics;
- common-el gate alignment.

## Archived Backend Attempts

Step09 backend attempt files were moved to:

```text
archive/backend_attempts/
```

They are retained to explain the route decision, not to define the final backend. The final backend remains Step8.7 verified lazy cascade.

## Archived Diagnostic Results

Step09 diagnostic outputs were moved to:

```text
archive/diagnostic_results/
```

These results should be cited as supplementary negative evidence only. Final performance claims should cite Step8.7 and Step8.8 evidence through `../step_10_final_thesis_route/`.

## Do Not Continue Here

Do not continue Step09 threshold tuning, common-el gate variants, learning-assisted calibration, dual-center modeling, V2/complex-gain routes, or Step8.10 unified model selection as part of the final thesis route.

Recommended next phase: thesis writing, figure preparation, and defense material cleanup.

