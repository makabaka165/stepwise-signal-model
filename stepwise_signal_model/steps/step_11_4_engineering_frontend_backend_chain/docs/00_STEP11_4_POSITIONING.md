# Step11.4 Positioning

## What This Step Tests

Step11.4 tests whether an engineering frontend coarse peak can be serialized
into `frontend_out`, transformed into `backend_in`, and used as a local prior
for the existing Step11 pair2d beamspace backend.

It does not claim a complete frontend detection pipeline, complete automatic
single-vs-pair model selection, or final engineering closure.

## Existing Evidence Used

- Step11.1 validates controlled pair2d beamspace ML.
- Step11.2 recommends `W = greedy_combined_B7`.
- Step11.3 recommends degree-based coarse-to-fine search.

Step11.4 reuses these as read-only prior results.

## Main Boundary

A frontend single coarse peak can contain an unresolved pair. It is not
evidence that the physical scene has one target, and it is not evidence that the
frontend already detected two targets.

The backend only receives a local search prior from the frontend; it must not
use truth to build the frontend coarse center.

