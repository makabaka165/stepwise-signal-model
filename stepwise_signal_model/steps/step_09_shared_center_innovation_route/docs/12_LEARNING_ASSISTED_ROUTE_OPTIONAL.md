# Learning-Assisted Route Calibration Optional Note

This stage does not add deep learning to the Step 09 main route.

The current thesis line emphasizes a model-driven and explainable method: frontend-constrained local unresolved-cluster modeling, shared-center cylindrical local manifold normalization, coherent rank-loss recovery, local 2-D refinement, and conservative confidence/boundary rejection.

Learning is therefore kept as future work only. A future extension may train a lightweight route or confidence calibrator using Step 09 intermediate features such as `peak_count`, `peak_sep_deg`, `peak2_ratio`, `lambda2_over_lambda1`, rank1 projection score, 2-D peak ratio, frontend state, boundary flag, and a power/SNR proxy.

Such a model must remain a calibration layer. It must not become end-to-end `Y_work -> az/el`, must not replace MUSIC/rank1/2-D angle estimation, and must not change the validated Step 09 default route.
