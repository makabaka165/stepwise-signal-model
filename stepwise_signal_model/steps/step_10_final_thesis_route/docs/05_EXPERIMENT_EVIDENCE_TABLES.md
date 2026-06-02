# Experiment Evidence Tables

## Table 1: Step8.7 Verified Lazy Cascade

| metric | value | interpretation |
| --- | ---: | --- |
| lazy_success_rate_all | 0.764705882352941 | final backend success evidence |
| lazy_false_high_confidence_rate_all | 0 | no high-confidence wrong output in cited run |
| lazy_boundary_missed_rate_all | 0 | boundary cases protected |
| lazy_low_confidence_rate_all | 0.209150326797386 | conservative rejection remains visible |
| mean_runtime_reduction_all | 0.376998770503756 | lazy cascade reduces runtime |

## Table 2: Step8.8 Frontend Closure

| metric | value | interpretation |
| --- | ---: | --- |
| cfar_detection_rate_overall | 1 | frontend detection closure passed |
| single_coarse_peak_rate_overall | 0.916666666666667 | most cases enter the single-cluster route |
| in_scope_shared_center_rate | 0.916666666666667 | frontend-to-shared-center handoff rate |
| false_high_rate_in_scope | 0 | in-scope safety retained |
| boundary_missed_rate_in_scope | 0 | boundary safety retained |

## Table 3: Step8.9 Hardware Boundary

| metric | value | interpretation |
| --- | ---: | --- |
| fixed_point_pass_flag | 0 | no fixed-point format passed full influence validation |
| recommended_fixed_point_format | not_recommended | pure fixed-point backend is not claimed |
| fixed_point_blocker_if_any | quantization_not_closed | hardware work remains a boundary topic |

## Table 4: Negative Route Decisions

| route | decision | reason |
| --- | --- | --- |
| Step8.10 unified model selection | not adopted | default and sweep thresholds failed safety |
| Step09-light backend | not adopted | formal and supplementary evidence did not pass |
| Step09-Step87 bridge backend | diagnostic only | bridge did not become the default backend |
| common-el gate alignment | not adopted | false-high and single-target split failed |
| learning-assisted route | future work only | not part of final thesis route |
| pure FPGA fixed-point backend | not adopted | quantization not closed |

## Table 5: Final Route Decision

| item | value |
| --- | --- |
| final backend | Step8.7 verified lazy cascade |
| interface layer | Step09 shared-center interface |
| performance evidence | Step8.7 |
| supplementary evidence | Step09 diagnostics |
| next phase | thesis writing / figure preparation |

