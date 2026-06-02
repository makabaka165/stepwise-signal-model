# Local Step Summary: Step 8.7 to Step 8.10

Source basis: latest local commit `f4eb06e1d667fcb55053d85b5a799142f2d8714d` (`Add step 8.11 shared-center final route summary`). I read the committed versions from `HEAD`, not the modified working-tree copy of the Step 8.7 report.

## Step 8.7 Core Algorithm

Step 8.7 is not a single new 2D-MUSIC algorithm. It is a conservative route-dispatch chain for a 65 x 32 cylindrical working subarray:

1. regular level-2 MUSIC when the 1D/beamspace spectrum gives reliable peaks;
2. level-2 rank1 fallback when strong coherent close targets collapse into one peak;
3. common-el refocus plus level-2 rank1 fallback when two targets share elevation but upstream elevation focus is unreliable;
4. 2D-MUSIC plus pair-local covariance fitting when elevation separation is large;
5. `low_confidence` or `boundary_unreliable` when weak targets, near anti-phase cancellation, route conflicts, or insufficient observables appear.

Key committed metrics:

- observable dispatch success in Step 8.7 6B: about `0.732`;
- false-high-confidence: `0`;
- boundary-missed: `0`;
- Step 8.7 7B lazy runtime success: about `0.731`;
- mean runtime reduction: about `0.359`;
- 2D-MUSIC execution rate: about `0.581`;
- pair-local execution rate: about `0.353`;
- large-elevation scenario success: `1.0`.

Interpretation: Step 8.7 should be written as "third-level information + level-2 fallback + observable route dispatch", not as a universal coherent-source MUSIC replacement.

## Step 8.8 Interface Closure

Step 8.8 connects the frontend detection chain to Step 8.7:

`LFM / pulse compression / MTD / CFAR / coarse angle -> shared-center 65-column subarray -> Y_work -> Step 8.7 lazy cascade`.

The default in-scope case is `single coarse peak / unresolved local cluster`. Two separated coarse peaks are explicitly out of scope for the default shared-center route.

Key committed metrics:

- CFAR detection rate: `1`;
- single-coarse-peak rate: about `0.917`;
- two-coarse-peak out-of-scope rate: about `0.083`;
- in-scope shared-center rate: about `0.917`;
- false-high in scope: `0`;
- boundary-missed in scope: `0`.

Step 8.8B indicates Doppler de-rotation is optional; `no_derotation`, `derotation_minus`, and `derotation_plus` give the same route/confidence/success/output behavior in the tested settings.

## Step 8.9 Fixed-Point Boundary

Step 8.9 is a negative/blocker validation for fixed-point migration. It does not close a bit-true FPGA implementation.

Findings:

- float32 is mostly stable;
- int16/int18/int24 modes preserve safety but do not preserve route/confidence/output equivalence strongly enough;
- steering/template/cache quantization is more sensitive than `Y_work` int16 block floating;
- mixed precision `Y_work int16 + coeff int24` improves p95 azimuth difference but still leaves boundary route/candidate-tie flips;
- Step 8.9E identifies first divergences mainly at refocus-stage metrics such as `refocus_rank1_score_gap_ratio` and `refocus_rank1_pair_sep_est`.

Engineering implication: FPGA should accelerate regular front-end and spectrum/candidate computations, while route decision, EVD, confidence, and boundary logic should remain on CPU/ARM/DSP/floating-point IP in the first version.

## Step 8.10 Unified Model Selection

Step 8.10 attempted H1/H2/H3/H0 unified residual scoring to replace or explain the Step 8.7 cascade. The committed result says it is unsafe:

- unified success: about `0.085`;
- cascade success on the same `Y_work`: about `0.494`;
- success gap: about `-0.409`;
- unified false-high: about `0.222`;
- unified boundary-missed: about `0.036`;
- H1/H2/H3 model selection distribution does not match physical expectations.

Interpretation: a single residual-based model selector is not enough for this problem. The cascade's route gates and boundary protection are necessary engineering structure.

## Literature Mapping

The closest literature families are:

- classic MUSIC and its failure under coherent/rank-deficient source covariance;
- spatial smoothing and forward/backward spatial smoothing for coherent-source rank restoration;
- circular/cylindrical or beamspace transformations for arrays that are not simple ULAs;
- 2D-MUSIC and 2D spatial smoothing/differencing for azimuth/elevation separation;
- covariance or Toeplitz reconstruction for coherent-source DOA;
- sparse or gridless covariance recovery as a future alternative to exhaustive model selection.

The current implementation is best positioned as an engineering hybrid, not as a new universal MUSIC theory.
