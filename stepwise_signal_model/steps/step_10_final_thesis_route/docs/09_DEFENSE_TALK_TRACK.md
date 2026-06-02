# Defense Talk Track

1. I am not solving arbitrary full-field multi-target separation. I solve the local unresolved cluster problem after frontend detection.
2. The reason for shared-center is to make the local cylindrical array observation have a stable, comparable 65-column manifold.
3. I use 65 columns because it gives a fixed local work subarray around the frontend coarse azimuth while keeping the problem bounded.
4. The final backend is Step8.7 verified lazy cascade because it has the strongest safety evidence: zero false-high and zero boundary-missed in the cited validation.
5. Step09 contributes interface abstraction, route positioning, diagnostics, and negative evidence. It is not the final algorithm backend.
6. Step09-light is not adopted because it did not pass the final safety standard.
7. common-el gate alignment is not adopted because it improved close-coherent success but introduced unacceptable false-high and single-target false split behavior.
8. The experiments support the final choice by comparing success, false-high, boundary-missed, low-confidence, and route decision behavior.
9. Engineering implementation should split the work: FPGA for frontend acceleration and subarray extraction, SoC/DSP/floating IP for EVD and route decisions.
10. Future work can study learning-assisted calibration or deeper hardware hardening, but those are not part of the final thesis route.

