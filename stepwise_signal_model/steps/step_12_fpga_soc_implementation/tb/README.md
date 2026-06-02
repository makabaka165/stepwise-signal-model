# Testbench Notes

This directory contains module-level testbenches for the Step12 RTL prototypes.

| Testbench | Checks |
|---|---|
| `tb_shared_center_column_selector.v` | `center_col = 0, 1, 96, 191` wrap-around behavior. |
| `tb_y_work_packer.v` | Small `NAZ = 8`, `NEL = 4`, `Q = 3` selected-column filtering and local index output. |
| `tb_projection_score_core.v` | Hand-checkable complex multiply-accumulate score. |

The testbenches are intentionally small and deterministic so they can be compared against MATLAB golden vectors.
