# Frontend-Backend Interface Theory

## Interface Interpretation

The frontend layer reports an observable coarse local peak:

- coarse center angle
- search window
- beam energy neighborhood
- cluster indicator
- optional quality indicators

The backend layer treats that coarse center as a local prior and evaluates
whether a pair2d unresolved-cluster enhancement is useful inside that local
window.

## `frontend_out`

`frontend_out` should be an observable engineering object. It may include truth
for offline metric evaluation only, but truth must not be used to construct the
coarse center or backend search prior.

Required conceptual fields:

- `coarse_az_deg`
- `coarse_el_deg`
- `search_window`
- `beam_energy`
- `cluster_indicator`
- `method`
- `quality`

## `backend_in`

`backend_in` should contain only what the backend needs:

- `Y`
- `W`
- `coarse_center_deg`
- `search_cfg`
- `manifold_opts`
- `search_opts`
- `metadata`

## Failure Diagnosis

If chaining fails, Step11.4 must report whether the bottleneck is likely in:

- frontend coarse-angle quality
- frontend-to-backend serialization
- Step11 backend local search configuration
- the mismatch between single-target cases and pair2d mode

