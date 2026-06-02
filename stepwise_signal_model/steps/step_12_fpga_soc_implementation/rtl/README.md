# RTL Prototype Notes

The RTL files in this directory are prototype skeletons for engineering validation. They are not a complete replacement for the MATLAB Step8.7 backend.

| File | Purpose |
|---|---|
| `shared_center_column_selector.v` | Generate Q circular wrapped selected column indices from `center_col`. |
| `y_work_packer.v` | Filter an input array stream by selected columns and output local Y_work samples. |
| `projection_score_core.v` | Accumulate a simplified complex projection score for FPGA acceleration discussion. |

Run module-level checks with `../sim/run_iverilog_sim.sh` when iverilog is available.
