# Coarse-to-fine flow

## Inputs

- frontend coarse center
- local search window
- W = greedy_combined_B7
- beamspace snapshots Z

## Steps

1. Build full fine baseline grid.
2. Build coarse grid.
3. Compute coarse ML score.
4. Keep topK=3.
5. Build local refine windows.
6. Evaluate fine candidates.
7. Output best refined estimate.
8. Compare with full fine baseline.

## Text flow

```text
frontend coarse center
  -> local search window
  -> W = greedy_combined_B7 beamspace projection
  -> coarse degree-based grid
  -> ML score ranking
  -> topK=3 retained candidates
  -> local fine refine windows
  -> best controlled pair2d beamspace ML output
  -> comparison against full fine baseline
```
