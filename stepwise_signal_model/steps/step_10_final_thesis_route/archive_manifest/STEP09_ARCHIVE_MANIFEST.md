# Step09 Archive Manifest

Step09 is retained as archived diagnostics and thesis-interface notes. It is not the final algorithm backend.

## Retained Evidence

- `archive/negative_reports/17_FINAL_BACKEND_DECISION.md`: final Step09 backend decision evidence.
- `archive/negative_reports/18_FALLBACK_TO_STEP87_FINAL_DECISION.md`: fallback decision to Step8.7.
- `archive/negative_reports/19_FINAL_THESIS_ROUTE_SUMMARY.md`: final thesis positioning summary.
- `results_step09_final_decision.csv`: compact final decision table.
- `archive/diagnostic_results/results_step09_common_el_gate_alignment/step09_common_el_gate_alignment_keypoints.csv`: common-el gate alignment keypoints.

## Archived Diagnostic Scripts

| archived file | reason |
| --- | --- |
| `archive/diagnostic_scripts/run_final_shared_center_demo.m` | old Step09 demo; retained only as historical interface smoke artifact |
| `archive/diagnostic_scripts/run_final_shared_center_validation.m` | old Step09 validation; retained only as historical interface smoke artifact |
| `archive/diagnostic_scripts/run_step09_formal_monte_carlo.m` | formal MC negative evidence reproduction |
| `archive/diagnostic_scripts/run_step09_vs_step87_consistency_check.m` | consistency diagnostic reproduction |
| `archive/diagnostic_scripts/run_step09_ablation_study.m` | ablation negative evidence reproduction |
| `archive/diagnostic_scripts/run_step09_all_supplementary_experiments.m` | old supplementary driver; not a mainline entry |
| `archive/diagnostic_scripts/run_step09_step87_backend_bridge_validation.m` | bridge diagnostic reproduction |
| `archive/diagnostic_scripts/run_step09_close_coherent_gate_diagnostics.m` | close-coherent gate diagnostic reproduction |
| `archive/diagnostic_scripts/run_step09_common_el_gate_alignment.m` | gate-alignment decision reproduction |

## Archived Backend Attempts

| archived file | reason |
| --- | --- |
| `archive/backend_attempts/shared_center_enhanced_doa.m` | Step09-light/bridge entry; not final backend |
| `archive/backend_attempts/step87_reference_backend.m` | Step09 bridge backend; diagnostic only |
| `archive/backend_attempts/step09_experiment_utils.m` | supplementary experiment utility; not thesis mainline |
| `archive/backend_attempts/local_cylindrical_music_test.m` | helper for Step09-light backend |
| `archive/backend_attempts/coherent_rank1_refocus_fallback.m` | helper for Step09-light backend |
| `archive/backend_attempts/local_2d_pair_refinement.m` | helper for Step09-light backend |
| `archive/backend_attempts/confidence_boundary_rejector.m` | helper for Step09-light backend |

## Retained Interface Files

| retained file | reason |
| --- | --- |
| `main/shared_center_select_subarray.m` | interface demonstration for 65-column selection |
| `main/build_y_work_from_frontend.m` | interface demonstration for local `Y_work` construction |

## Archived Diagnostic Results

| archived directory | reason |
| --- | --- |
| `archive/diagnostic_results/results_step09_formal_mc/` | formal MC negative evidence |
| `archive/diagnostic_results/results_step09_ablation/` | ablation negative evidence |
| `archive/diagnostic_results/results_step09_vs_step87_consistency/` | consistency diagnostics |
| `archive/diagnostic_results/results_step09_step87_backend_bridge/` | bridge diagnostics |
| `archive/diagnostic_results/results_step09_close_coherent_gate_diagnostics/` | close-coherent gate diagnostics |
| `archive/diagnostic_results/results_step09_common_el_gate_alignment/` | final gate-alignment negative decision |
| `archive/diagnostic_results/results_step09_final_smoke_validation/` | old Step09 smoke/demo outputs; not final backend evidence |
| `archive/diagnostic_results/results_step09_supplementary_overview.csv` | supplementary archived diagnostic overview |

No files were physically deleted in this cleanup. Large trial CSVs and PNGs are retained under archive for reproducibility, but they are not final thesis mainline outputs.

For the current Step09-local manifest, see:

```text
../../step_09_shared_center_innovation_route/archive/manifest/STEP09_ARCHIVE_MANIFEST.md
```
