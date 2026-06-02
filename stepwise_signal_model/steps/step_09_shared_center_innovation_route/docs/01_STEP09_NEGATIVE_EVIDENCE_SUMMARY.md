# Step09 Negative Evidence Summary

These are not thesis mainline failures. They are route-selection evidence explaining why Step09 backend attempts were not adopted and why the final thesis route uses Step8.7 verified lazy cascade as the backend.

| experiment | result | blocker | decision | evidence_path |
| --- | --- | --- | --- | --- |
| Step09 formal MC | overall success was low and formal pass flag was 0 | `overall_false_high_rate_gt_0p01`, `close_coherent_success_low`, `large_el_success_low` | not adopted | `../archive/diagnostic_results/results_step09_formal_mc/step09_formal_mc_keypoints.csv`; `../archive/negative_reports/09_FORMAL_MONTE_CARLO_RESULTS.md` |
| Step09 ablation | full Step09 success remained low and safety still missed target | `rank1_gain_close_coherent_low`, `local_2d_gain_large_el_low`, `full_step09_false_high_gt_0p01` | not adopted | `../archive/diagnostic_results/results_step09_ablation/step09_ablation_keypoints.csv`; `../archive/negative_reports/11_ABLATION_STUDY_RESULTS.md` |
| Step09-vs-Step87 consistency | old Step8.7 was not originally a direct functional backend entry | `step87_reference_not_functionalized` | diagnostic only | `../archive/diagnostic_results/results_step09_vs_step87_consistency/step09_vs_step87_keypoints.csv`; `../archive/negative_reports/10_STEP09_VS_STEP87_CONSISTENCY.md` |
| Step09-Step87 backend bridge | bridge became callable but did not become the final default backend | bridge evidence did not supersede Step8.7 final evidence | diagnostic only | `../archive/diagnostic_results/results_step09_step87_backend_bridge/step09_step87_backend_bridge_keypoints.csv`; `../archive/negative_reports/14_STEP87_BACKEND_BRIDGE.md` |
| close coherent gate diagnostics | candidate generation was not the main failure mode | common-el gate mismatch | diagnosis only | `../archive/diagnostic_results/results_step09_close_coherent_gate_diagnostics/step09_close_coherent_gate_keypoints.csv`; `../archive/negative_reports/15_CLOSE_COHERENT_GATE_DIAGNOSTICS.md` |
| common-el gate alignment | Gate 2 improved close-coherent success but failed safety | `gate_alignment_failed_false_high`; single-target false split remained unacceptable | not adopted | `../archive/diagnostic_results/results_step09_common_el_gate_alignment/step09_common_el_gate_alignment_keypoints.csv`; `../archive/negative_reports/16_COMMON_EL_GATE_ALIGNMENT.md` |
| optional learning | not part of current final thesis route | future-work scope only | future work only | `../archive/negative_reports/12_LEARNING_ASSISTED_ROUTE_OPTIONAL.md` |

Final decision evidence:

- `../results_step09_final_decision.csv`
- `../archive/negative_reports/17_FINAL_BACKEND_DECISION.md`
- `../archive/negative_reports/18_FALLBACK_TO_STEP87_FINAL_DECISION.md`
- `../archive/negative_reports/19_FINAL_THESIS_ROUTE_SUMMARY.md`
