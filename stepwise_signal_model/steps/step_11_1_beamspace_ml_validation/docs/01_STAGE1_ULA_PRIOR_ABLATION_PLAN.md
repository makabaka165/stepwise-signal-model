# Stage1 ULA Prior Ablation Plan

## Base Parameters

```matlab
array_num = 256
lambda = 0.3 / 2.7
d = 0.047
numSnapshots = 130
theta_true = [12.7, 14.3]
true_center = mean(theta_true)
beam_width = 2.8
beam_count_list = [16, 20, 24, 28, 32]
center_bias_list = [-0.6, -0.4, -0.2, 0, 0.2, 0.4, 0.6]
search_mode_list = ["left_right", "ordered"]
snr_db = 20
Metkl = 50
tol_deg = 0.1
base_seed = 20260611
```

## Search Modes

### left_right

```matlab
theta1_grid = beam_c - beam_width/2 : 0.01 : beam_c
theta2_grid = beam_c + 0.01 : 0.01 : beam_c + beam_width/2
```

This reproduces the original Step11 left/right partitioned search prior.

### ordered

```matlab
theta_grid = beam_c - beam_width/2 : 0.01 : beam_c + beam_width/2
```

This searches all angle pairs with `theta1 < theta2`. It keeps only the weaker prior that both targets lie in the local window, without forcing them to sit on opposite sides of `beam_c`.

## Metrics

- `raw_success_rate`: two finite angles are returned.
- `tol_success_rate`: after sorting, both estimates are within `tol_deg`.
- `rmse_deg`: sorted two-target RMSE.
- `center_error_deg`: estimated center minus true center.
- `sep_error_deg`: estimated separation minus true separation.
- `boundary_hit_rate`: at least one estimate is within `0.01 deg` of the search-window boundary.
- `left_right_gap`: `left_right` minus `ordered` tolerance success rate at the same bias condition.
- `best_beam_count`: the beam count with the highest success rate and then the smallest RMSE.

## Acceptance Reading

If `ordered` search still reaches a high success rate near `center_bias = 0`, ML itself is not fully dependent on the left/right partition.

If performance degrades gradually as `center_bias` moves away from zero, the method is not fully dependent on knowing the true center exactly.

If `boundary_hit_rate` is high, the result must be marked as risky. Low RMSE should not be directly interpreted as robust super-resolution when estimates are often pinned to search boundaries.

If `left_right` is clearly better than `ordered`, the original Step11 route contains a strong left/right prior and later cylindrical-array migration must be treated cautiously.
