# Thesis Chapter Outline

## 1. Problem Definition

- Define the holographic staring cylindrical array context.
- Define the frontend detection cell and coarse angle input.
- Limit the method to local unresolved clusters.
- Separate in-scope and out-of-scope frontend states.

## 2. Frontend-Driven Local Cluster Modeling

- Explain `single_peak_in_scope`.
- Explain why two separated coarse peaks are not forced into the route.
- Explain weak and near anti-phase boundary protection.
- Define validation labels and safety metrics.

## 3. Shared-Center Local Manifold Normalization

- Define center column selection.
- Define 65 work columns.
- Define `Y_work in C^(65 x 32 x Np)`.
- Explain no default Doppler de-rotation.

## 4. Step8.7 Verified Lazy Cascade Backend

- Describe level2 MUSIC and common-el refocus.
- Describe rank1 fallback.
- Describe 2D MUSIC and pair-local refinement.
- Describe confidence and boundary output.
- Describe lazy early stop.

## 5. Experimental Results

- Present Step8.7 backend evidence.
- Present Step8.8 frontend closure.
- Present Step09 negative decision evidence.
- Present safety metrics, not only success rate.

## 6. Hardware Implementation Boundary

- Explain FPGA-friendly modules.
- Explain SoC/DSP/floating modules.
- Explain fixed-point validation blocker.
- Avoid claiming full pure-FPGA closure.

## 7. Negative Results and Route Tradeoffs

- Step8.10 unified model selection negative result.
- Step09-light negative result.
- common-el gate alignment negative result.
- Learning route as future work only.

## 8. Summary

- Restate final route.
- Restate three innovation points.
- Restate final backend decision.
- State that the next phase is thesis writing and figures.

