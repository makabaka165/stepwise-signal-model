# Stage2 Synthetic Frontend Coarse-Angle Plan

## Goal

Run a synthetic frontend two-dimensional beam scan and estimate coarse az/el
from beam energy. The coarse center must come from beam observations, not from
the truth angles.

## Planned Methods

- `peak`
- `centroid_top9`
- `centroid_threshold`

## Planned Metrics

- coarse azimuth error
- coarse elevation error
- within +/-0.2 deg rate
- beam spread indicator
- cluster indicator

## Outputs

- trial CSV
- summary CSV
- keypoints CSV
- result MAT
- log
- diagnostic plot if useful

