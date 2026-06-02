# Review Synthesis

## 1. What the Local Algorithm Is Closest To

The current Step 8.7-8.10 route is best described as a MUSIC-family coherent-source engineering chain:

`frontend unresolved cluster -> shared-center local cylindrical subarray -> MUSIC/FBSS-style diagnosis -> rank1/refocus fallback or 2D branch -> confidence/boundary output`.

It is not a pure new MUSIC spectrum, not a universal coherent-source solver, and not a complete fixed-point FPGA algorithm. The literature match is therefore a combination of several families rather than one single paper.

## 2. Strongest Related Literature Families

### Spatial Smoothing and FBSS

Classic spatial smoothing and forward/backward spatial smoothing are the most important theoretical ancestors. They address the core failure mode: coherent sources collapse the source covariance rank, so direct MUSIC can lose the multi-source subspace structure.

For the thesis, this supports the statement:

`The proposed chain inherits the rank-restoration idea of spatial smoothing/FBSS but adds local cylindrical shared-center selection and route-level boundary protection.`

### Circular and Cylindrical Array Extensions

The current array is not a simple ULA; it uses a 65-column by 32-layer cylindrical working subarray. Literature on UCA and cylindrical-array smoothing is directly relevant because it explains why geometry-aware steering, beamspace transforms, and local templates matter.

For the thesis:

`Unlike ULA-only smoothing, the implementation keeps true cylindrical steering in the local shared-center subarray and validates local template reuse.`

### 2D Coherent DOA

The Step 8.7 large-elevation branch matches 2D coherent-source literature. When layer-2 elevation compression loses information, 2D-MUSIC or a 2D refinement route becomes necessary.

This supports:

`Large elevation separation is not solved by forcing a 1D rank1 fallback; it is routed to 2D MUSIC / pair-local refinement.`

### Covariance Reconstruction, Toeplitz, and Gridless Recovery

Recent papers reconstruct covariance matrices, Toeplitz structure, Khatri-Rao subspaces, or gridless covariance recovery to restore coherent-source identifiability. These are useful related work and future work, but they are not immediate replacements for the committed Step 8.7 cascade:

- they often assume different array structures;
- they can be heavier computationally;
- they do not by themselves solve the local engineering state machine, confidence, and boundary-protection problem;
- Step 8.10 already shows that simply unifying candidate models by residual score was unsafe in this codebase.

## 3. How to Compare Literature to Step 8.7

| Local component | Literature analogy | Difference |
|---|---|---|
| Branch A regular MUSIC | Original MUSIC and smoothed MUSIC | Local code uses route confidence and shared-center geometry |
| FBSS/MSSP preprocessing | Spatial smoothing / FBSS | Local code is embedded in a larger unresolved-cluster pipeline |
| common-el refocus + rank1 fallback | Coherent rank restoration / covariance fitting intuition | Refocus is used to correct elevation focus before returning to a mature 1D fallback |
| 2D-MUSIC / pair-local refinement | 2D coherent-source DOA | Triggered only when observables indicate 2D separation is needed |
| low-confidence / boundary-unreliable | Robust engineering decision logic | Less common in theoretical papers but important for avoiding false-high outputs |
| Step 8.9 fixed-point blocker | Hardware implementation boundary | Literature usually reports algorithmic accuracy, not route flip under quantized templates |
| Step 8.10 negative result | Model-selection / covariance fitting attempts | Local evidence shows residual-only unification can be unsafe |

## 4. Suggested Thesis Wording

Recommended:

`This work develops a shared-center local enhanced DOA chain for unresolved target clusters on a cylindrical working subarray. The chain combines MUSIC-family spatial smoothing, common-elevation refocus, rank1 fallback, and 2D MUSIC refinement under an observable route-dispatch framework, with low-confidence protection for weak or ill-conditioned cases.`

Avoid:

`This work proposes a universal improved MUSIC algorithm for all coherent sources.`

Also avoid:

`The algorithm has completed full fixed-point FPGA implementation.`

## 5. Literature Gaps That Match Future Work

1. Weak-target boundary: look for residual detection, SIC, sparse recovery, or dynamic range-aware coherent-source DOA.
2. Near anti-phase boundary: look for derivative steering, cancellation-aware models, or phase-sensitive covariance fitting.
3. Quantized steering/template sensitivity: look for fixed-point or hardware-aware MUSIC/DOA implementations; this is underrepresented in the current paper list.
4. Cylindrical-array coherent smoothing: manually retrieve Zoltowski/Mathews/Kung and related circular/cylindrical array papers.

## 6. Practical Next Step

For writing the related-work section, use this structure:

1. MUSIC and coherent-source failure;
2. spatial smoothing/FBSS rank restoration;
3. circular/cylindrical or beamspace array adaptations;
4. 2D DOA and covariance reconstruction alternatives;
5. gap: few papers combine frontend unresolved-cluster detection, shared-center local subarray selection, conservative route dispatch, and hardware-boundary analysis.
