# Limitations and usage boundary

- The result is based on the current representative scenarios.
- W is fixed to greedy_combined_B7.
- The controlled pair2d model is fixed.
- The method does not guarantee robustness to arbitrary coarse-center bias.
- The method does not guarantee arbitrary full-field multi-target behavior.
- The method is not AP.
- The method is not a complete engineering closed loop.
- If the front-end coarse center bias exceeds the local window, enlarge the search window or reselect the center beams.
- Coarse-to-fine depends on the local search window and should not be described as an unconstrained global search.
