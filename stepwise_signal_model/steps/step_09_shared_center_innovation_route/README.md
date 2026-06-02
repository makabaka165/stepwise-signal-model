# Archived Step09 Diagnostics and Thesis Interface Notes

Step09 is now an archived diagnostics and thesis-interface note set. It is not a backend tuning mainline and it is not the final algorithm backend.

## Current Status

- Step09 backend tuning is frozen.
- Step09-light backend is not adopted.
- Step09-Step87 bridge is diagnostic only.
- common-el gate alignment is not adopted.
- Final backend evidence is Step8.7 verified lazy cascade.
- Final thesis route is documented in [../step_10_final_thesis_route/](../step_10_final_thesis_route/).

Final thesis route:

```text
Frontend detection / coarse angle
-> shared-center 65-column local work subarray
-> Y_work construction
-> Step8.7 verified lazy cascade backend
-> confidence / boundary output
-> FPGA/SoC implementation boundary
```

## Why Step09 Is Archived

Step09 is retained to record negative / diagnostic evidence:

- Step09-light formal MC did not pass.
- Ablation exposed backend weakness.
- Step09-Step87 bridge was callable but not adopted.
- Close-coherent diagnostics showed common-el gate mismatch.
- Common-el gate alignment improved close-coherent success but failed safety due to false-high / single-target false split.
- Therefore Step09 backend tuning is frozen.

## What Remains Useful

- Shared-center interface concept.
- `Y_work` construction concept.
- Negative evidence.
- Route decision evidence.
- Thesis framing support.

Retained interface files:

- `main/shared_center_select_subarray.m`
- `main/build_y_work_from_frontend.m`

These files demonstrate the 65-column shared-center handoff and local `Y_work` construction. They are not a final backend implementation.

## What Is Not Final

- Step09-light is not final.
- Step87 bridge inside Step09 is not final.
- Common-el gate alignment is not final.
- Step09 backend code is not final.
- Step11 ML is not part of the Step09 final route.

## Final Route Location

Use the final thesis route in:

```text
../step_10_final_thesis_route/
```

## Archived Diagnostic Commands

These commands are kept for reproducibility only. Do not run them as part of the final thesis route.

```matlab
run('steps/step_09_shared_center_innovation_route/archive/diagnostic_scripts/run_step09_formal_monte_carlo.m')
run('steps/step_09_shared_center_innovation_route/archive/diagnostic_scripts/run_step09_vs_step87_consistency_check.m')
run('steps/step_09_shared_center_innovation_route/archive/diagnostic_scripts/run_step09_ablation_study.m')
run('steps/step_09_shared_center_innovation_route/archive/diagnostic_scripts/run_step09_all_supplementary_experiments.m')
run('steps/step_09_shared_center_innovation_route/archive/diagnostic_scripts/run_step09_step87_backend_bridge_validation.m')
run('steps/step_09_shared_center_innovation_route/archive/diagnostic_scripts/run_step09_close_coherent_gate_diagnostics.m')
run('steps/step_09_shared_center_innovation_route/archive/diagnostic_scripts/run_step09_common_el_gate_alignment.m')
```

## Archive Map

- `docs/`: current Step09 positioning notes only.
- `archive/diagnostic_scripts/`: retained scripts for reproducing negative / diagnostic evidence.
- `archive/backend_attempts/`: frozen Step09 backend attempts.
- `archive/diagnostic_results/`: archived result bundles and key evidence.
- `archive/negative_reports/`: old Step09 reports retained as evidence, not mainline docs.
- `archive/manifest/`: Step09 keep/archive/delete manifest.
- `results_step09_final_decision.csv`: compact final decision evidence retained at Step09 root.

## Final Decision

```text
final_recommendation = freeze_step09_backend_use_step87_verified_lazy_cascade
```

Do not continue Step09 threshold tuning, common-el gate variants, learning-assisted calibration, dual-center modeling, V2/complex-gain routes, or Step8.10 unified model selection inside the final thesis route.
