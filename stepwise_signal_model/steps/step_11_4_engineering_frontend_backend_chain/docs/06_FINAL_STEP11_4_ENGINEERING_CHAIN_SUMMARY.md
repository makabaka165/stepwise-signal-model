# Final Step11.4 Engineering Chain Summary

## Final Decision

ACCEPT_WITH_RISKS_AND_END

Step11.4 validates the interface-level chain under the scoped synthetic tests,
but it does not claim full frontend CFAR/MTD closure or complete automatic
single-vs-pair model selection.

## Main Answers

1. Step11.4 can chain at interface level.
   Stage1 interface contract passed, Stage3 synthetic frontend backend reached
   the same success rate as oracle backend, and Stage4 module diagnostics passed.

2. The main bottleneck is frontend coarse-angle quality in weak-secondary and
   low-SNR hard cases.
   Stage2 best method was `centroid_top9`, with within +/-0.2 deg rate 0.6,
   azimuth RMSE 0.340822 deg, elevation RMSE 0.114006 deg, and pass flag 0.

3. The frontend coarse angle is not uniformly inside the Step11.3 +/-0.2 deg
   robustness envelope, but it was sufficient for the tested local backend
   window.
   Stage3 synthetic backend success rate was 1 with topK miss rate 0 and
   boundary hit rate 0.

4. Synthetic frontend backend was close to oracle backend in the tested setup.
   Oracle success rate = 1, synthetic success rate = 1, success ratio = 1.
   Synthetic mean backend RMSE was 0.030219 deg az and 0.027238 deg el; oracle
   mean backend RMSE was 0.036656 deg az and 0.011000 deg el.

5. Ordinary single targets should not default-trigger pair2d.
   Stage4 forced single-target pair2d false split rate = 1, while pair-target
   success rate = 1. Pair2d should be an unresolved-cluster enhanced mode.

6. The engineering recommendation is modular continuation, not full closure.
   Keep frontend coarse detection/angle as the ordinary path; call pair2d only
   when local cluster indicators justify unresolved-pair enhancement.

7. Thesis writing should separate the algorithm route and engineering route.
   The algorithm route is Step11 controlled pair2d beamspace ML with
   `greedy_combined_B7` and degree-based coarse-to-fine search. The engineering
   route is the Step11.4 interface feasibility study showing how a frontend
   coarse peak can drive that backend, with explicit limits.

## Stage Results

| Stage | Key Result | Decision |
| --- | --- | --- |
| Stage1 interface contract | `interface_contract_pass_flag = 1` | GO |
| Stage2 synthetic frontend coarse angle | `frontend_coarse_angle_pass_flag = 0` | CONTINUE_WITH_RISK |
| Stage3 frontend-to-backend chain | `chain_validation_pass_flag = 1` | GO |
| Stage4 single-vs-pair diagnostics | `stage4_module_diagnostics_pass_flag = 1` | GO |

## Final Maximum Review

- User-side correctness: the requested Step11.4 directory and goal-internal
  `goal-1` management files were created; no root-level goal directory was used.
- Code correctness: Stage1-4 MATLAB scripts ran successfully in MATLAB R2022b.
- MATLAB runtime: final sequential rerun of Stage1-4 completed successfully.
- Theory consistency: frontend single peak is treated as an observable local
  prior, not as a physical single-target decision.
- Frontend/backend layering: `frontend_out` carries coarse center, search
  window, beam energy, and cluster indicators; backend treats it as local prior.
- Overclaim control: docs and results avoid claiming full CFAR/MTD closure or
  complete automatic target-count selection.
- Git rollback safety: every task/review gate was committed separately.
- Reproducibility: stage scripts write CSV, MAT, log, keypoints, README, and
  PNG artifacts with fixed seeds.
- Documentation completeness: task reports, review reports, records, context,
  and final summary are present under Step11.4.

## Residual Risks

- Stage2 frontend coarse angle is biased in weak-secondary and low-SNR hard
  cases.
- The evidence is synthetic and local-window scoped.
- The trigger policy is diagnostic guidance, not a completed automatic
  classifier.
- Real frontend CFAR/MTD integration remains out of scope.

