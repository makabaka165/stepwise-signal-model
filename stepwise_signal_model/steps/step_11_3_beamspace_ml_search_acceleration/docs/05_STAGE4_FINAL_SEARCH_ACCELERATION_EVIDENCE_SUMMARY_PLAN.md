Stage4 final search acceleration evidence summary plan
=====================================================

Stage4 is the final evidence-packaging stage for Step11.3. It does not add a
new algorithm, does not rerun ML search, and does not change any Stage1,
Stage2, or Stage3 search logic. Its only purpose is to collect the existing
Stage1--Stage3 results and turn them into tables, figures, and thesis-writing
material.

Step11.3 algorithm position
---------------------------

Step11.3 fixes the controlled pair2d beamspace ML backend from Step11.1 and
the Step11.2 recommended beamspace combiner:

- `W = greedy_combined_B7`
- beamspace snapshots: `Z = W' * Y`
- beamspace manifold: `G = W' * A_cyl`
- elevation separation parameterization: degree-based `el_sep_deg_list`
- search acceleration: coarse topK candidates followed by local fine refine

The acceleration is only a candidate-search strategy for the same ML score. It
is not AP, not full4D, not a new ML model, not a new W design, and not
element-domain ML. It also depends on a front-end coarse center and a bounded
local search window; the center is not replaced by the true target angles.

Final recommendation
--------------------

The current Stage2 and Stage3 evidence supports:

```text
recommended_search = degree_based_coarse_to_fine
recommended_topK = 3
recommended_coarse_grid = az_step 0.16 deg, el_step 0.24 deg
recommended_fine_grid = az_step 0.08 deg, el_step 0.12 deg
recommended_coarse_el_sep_list = [0,0.36,0.72]
recommended_fine_el_sep_list = [0,0.24,0.36,0.48,0.60,0.72]
recommended_W = greedy_combined_B7
```

Stage4 outputs
--------------

Stage4 writes a final results directory:

```text
results_step11_3_final_search_acceleration_evidence_summary/
```

The directory contains:

- final status, key metric, and recommendation CSV tables;
- one-page and detailed Markdown evidence documents;
- final overview PNG figures for algorithm flow, success, RMSE, candidate
  counts, reduction ratio, and front-end prior robustness;
- a MAT file containing the collected evidence struct;
- a log file listing collected and missing source files.

Usage boundary
--------------

The final summary should be used as evidence that Step11.3 is a local,
beamspace ML search-acceleration method under the current representative
scenarios, current `greedy_combined_B7` W, and current controlled pair2d model.
It should not be described as AP, full-space exhaustive optimization, a new
ML estimator, or a complete engineering closed loop.
