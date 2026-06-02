# Step09 Keep / Archive / Delete Table

| path | action | new_path | reason | risk_if_removed |
| --- | --- | --- | --- | --- |
| `README.md` | keep | `README.md` | current archive positioning | Step09 role becomes ambiguous |
| `docs/00_ARCHIVED_STEP09_POSITIONING.md` | keep | `docs/00_ARCHIVED_STEP09_POSITIONING.md` | current positioning note | future readers may treat Step09 as active backend |
| `docs/01_STEP09_NEGATIVE_EVIDENCE_SUMMARY.md` | keep | `docs/01_STEP09_NEGATIVE_EVIDENCE_SUMMARY.md` | compact negative-evidence index | route rejection evidence becomes scattered |
| `docs/02_STEP09_TO_STEP10_RELATION.md` | keep | `docs/02_STEP09_TO_STEP10_RELATION.md` | explains Step09-to-Step10 handoff | final route framing becomes unclear |
| `docs/03_DO_NOT_USE_AS_BACKEND.md` | keep | `docs/03_DO_NOT_USE_AS_BACKEND.md` | prevents future misuse | Step09 backend attempts may be reused by mistake |
| `main/shared_center_select_subarray.m` | keep | `main/shared_center_select_subarray.m` | shared-center interface demo | interface definition loses concrete reference |
| `main/build_y_work_from_frontend.m` | keep | `main/build_y_work_from_frontend.m` | `Y_work` construction demo | local observation construction loses concrete reference |
| `results_step09_final_decision.csv` | keep | `results_step09_final_decision.csv` | compact final decision evidence | final Step09 recommendation becomes harder to cite |
| `run_step09_*.m` and old final demo scripts | archive | `archive/diagnostic_scripts/` | reproducibility only, not final route commands | negative evidence cannot be reproduced from archived scripts |
| `main/shared_center_enhanced_doa.m` and backend helpers | archive | `archive/backend_attempts/` | frozen Step09 backend attempts | route-decision audit trail is weakened |
| `results_step09_formal_mc/` | archive | `archive/diagnostic_results/results_step09_formal_mc/` | formal MC negative evidence | formal MC blocker evidence is lost |
| `results_step09_ablation/` | archive | `archive/diagnostic_results/results_step09_ablation/` | ablation negative evidence | backend weakness evidence is lost |
| `results_step09_vs_step87_consistency/` | archive | `archive/diagnostic_results/results_step09_vs_step87_consistency/` | consistency diagnostics | bridge motivation becomes unclear |
| `results_step09_step87_backend_bridge/` | archive | `archive/diagnostic_results/results_step09_step87_backend_bridge/` | bridge diagnostics | callable-but-not-final evidence is lost |
| `results_step09_close_coherent_gate_diagnostics/` | archive | `archive/diagnostic_results/results_step09_close_coherent_gate_diagnostics/` | close-coherent gate diagnostics | common-el blocker diagnosis is lost |
| `results_step09_common_el_gate_alignment/` | archive | `archive/diagnostic_results/results_step09_common_el_gate_alignment/` | final gate-alignment negative decision | false-high / single-split blocker evidence is lost |
| `results/` final smoke/demo outputs | archive | `archive/diagnostic_results/results_step09_final_smoke_validation/` | old smoke validation, not final backend evidence | historical interface smoke evidence is lost |
| old `docs/00` through `docs/19` reports | archive | `archive/negative_reports/` | retain historical Step09 reports outside main docs | old decision evidence becomes hard to audit |
| any Step09 keypoints / report / summary file | keep | original archive path | required route-selection evidence | route-selection evidence is incomplete |
| none | delete | none | no physical deletion in this cleanup | none |
