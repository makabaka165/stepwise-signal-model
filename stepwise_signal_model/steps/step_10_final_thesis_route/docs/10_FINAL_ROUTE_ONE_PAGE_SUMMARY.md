# Final Route One-Page Summary

Method name:

```text
面向全息凝视圆柱阵局部未分辨目标簇的 shared-center 增强测角方法
```

Applicable scope: local unresolved target clusters after frontend detection on a holographic staring cylindrical array.

Final chain:

```text
Frontend detection / coarse angle
-> shared-center 65-column local work subarray
-> Y_work construction
-> Step8.7 verified lazy cascade backend
-> confidence / boundary output
-> FPGA/SoC implementation boundary
```

Innovation points:

- Frontend detection driven local unresolved-cluster modeling.
- Shared-center 65-column local cylindrical manifold normalization.
- Conservative enhanced DOA estimation with verified lazy cascade and boundary rejection.

Formal backend: Step8.7 verified lazy cascade.

Routes not adopted:

- Step09-light backend.
- Step09-Step87 bridge as default backend.
- common-el gate alignment.
- Step8.10 unified model selection.
- learning-assisted route in the current thesis.
- pure FPGA fixed-point backend as a completed claim.

Main evidence:

- Step8.7: `lazy_success_rate_all = 0.764705882352941`, `lazy_false_high_confidence_rate_all = 0`, `lazy_boundary_missed_rate_all = 0`.
- Step8.8: frontend closure passed with `cfar_detection_rate_overall = 1` and `in_scope_shared_center_rate = 0.916666666666667`.
- Step8.9: fixed-point route is not closed.
- Step8.10 and Step09 diagnostics provide negative route-decision evidence.

Engineering recommendation: FPGA handles frontend acceleration and 65-column extraction; SoC/DSP/floating IP handles EVD, route decision, confidence, and boundary state.

Final conclusion: this thesis finally adopts the Step09 shared-center interface plus the Step8.7 verified lazy cascade backend, not the Step09-light backend.

