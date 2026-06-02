# File Manifest And Cleanup Log

Step09 is now frozen as archived diagnostics and thesis-interface notes. The final thesis route is documented in:

```text
steps/step_10_final_thesis_route/
```

## Mainline Retained In Step09

| path | handling | reason |
| --- | --- | --- |
| `README.md` | keep | archived Step09 positioning and pointers to Step10 |
| `main/shared_center_select_subarray.m` | keep | shared-center 65-column interface demonstration |
| `main/build_y_work_from_frontend.m` | keep | frontend detection cell to `Y_work` construction demonstration |
| `docs/17_FINAL_BACKEND_DECISION.md` | keep | final Step09 negative decision |
| `docs/18_FALLBACK_TO_STEP87_FINAL_DECISION.md` | keep | fallback to Step8.7 decision |
| `docs/19_FINAL_THESIS_ROUTE_SUMMARY.md` | keep | thesis route summary |
| `results_step09_final_decision.csv` | keep | compact final decision evidence |

## Archived Diagnostic Scripts

| original role | archive location |
| --- | --- |
| final shared-center demo | `archive/diagnostic_scripts/run_final_shared_center_demo.m` |
| final shared-center validation | `archive/diagnostic_scripts/run_final_shared_center_validation.m` |
| formal MC | `archive/diagnostic_scripts/run_step09_formal_monte_carlo.m` |
| Step09-vs-Step87 consistency | `archive/diagnostic_scripts/run_step09_vs_step87_consistency_check.m` |
| ablation | `archive/diagnostic_scripts/run_step09_ablation_study.m` |
| supplementary experiment driver | `archive/diagnostic_scripts/run_step09_all_supplementary_experiments.m` |
| Step87 bridge validation | `archive/diagnostic_scripts/run_step09_step87_backend_bridge_validation.m` |
| close-coherent diagnostics | `archive/diagnostic_scripts/run_step09_close_coherent_gate_diagnostics.m` |
| common-el gate alignment | `archive/diagnostic_scripts/run_step09_common_el_gate_alignment.m` |

## Archived Backend Attempts

| original path | archive location | reason |
| --- | --- | --- |
| `main/shared_center_enhanced_doa.m` | `archive/backend_attempts/shared_center_enhanced_doa.m` | Step09-light/bridge entry; not final backend |
| `main/step87_reference_backend.m` | `archive/backend_attempts/step87_reference_backend.m` | Step09 bridge backend; diagnostic only |
| `main/step09_experiment_utils.m` | `archive/backend_attempts/step09_experiment_utils.m` | supplementary experiment utility |
| `main/local_cylindrical_music_test.m` | `archive/backend_attempts/local_cylindrical_music_test.m` | helper for Step09-light backend |
| `main/coherent_rank1_refocus_fallback.m` | `archive/backend_attempts/coherent_rank1_refocus_fallback.m` | helper for Step09-light backend |
| `main/local_2d_pair_refinement.m` | `archive/backend_attempts/local_2d_pair_refinement.m` | helper for Step09-light backend |
| `main/confidence_boundary_rejector.m` | `archive/backend_attempts/confidence_boundary_rejector.m` | helper for Step09-light backend |

## Archived Diagnostic Results

| result group | archive location |
| --- | --- |
| formal MC | `archive/diagnostic_results/results_step09_formal_mc/` |
| ablation | `archive/diagnostic_results/results_step09_ablation/` |
| Step09-vs-Step87 consistency | `archive/diagnostic_results/results_step09_vs_step87_consistency/` |
| Step87 bridge | `archive/diagnostic_results/results_step09_step87_backend_bridge/` |
| close-coherent diagnostics | `archive/diagnostic_results/results_step09_close_coherent_gate_diagnostics/` |
| common-el gate alignment | `archive/diagnostic_results/results_step09_common_el_gate_alignment/` |

## Removed From Mainline Positioning

The following remain as archived evidence or future-work notes only:

- Step09-light backend;
- Step09-Step87 bridge backend;
- common-el gate alignment;
- dual-center routes;
- complex-gain / V2 variants;
- weak-target forced solving;
- near anti-phase forced solving;
- Step8.10 unified model selection;
- pure FPGA fixed-point backend claim.

## Physical Delete

None. No files were physically deleted in this cleanup. Historical artifacts were moved into archive paths or superseded by Step10 documentation.

