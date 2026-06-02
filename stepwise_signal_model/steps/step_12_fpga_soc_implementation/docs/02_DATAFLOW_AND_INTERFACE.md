# 02 Dataflow and Interface

## Dataflow

Raw ADC / array data
-> pulse compression
-> MTD / Doppler FFT
-> CFAR detection
-> coarse beamforming
-> shared-center 65-column selection
-> Y_work packing
-> optional projection score acceleration
-> Step8.7 lazy cascade route decision
-> EVD / SVD / rank1 / pair-local / confidence
-> az/el estimate + confidence + boundary flag + route log

## Interface Fields

### frontend_out

| Field | Meaning |
|---|---|
| `frame_id` | Radar frame index |
| `detect_id` | Detection cell index in frame |
| `range_bin` | Range bin after frontend detection |
| `doppler_bin` | Doppler bin after MTD / CFAR |
| `coarse_az` | Coarse azimuth estimate |
| `coarse_el` | Optional coarse elevation estimate |
| `center_col` | Coarse angle mapped to azimuth column index |
| `frontend_valid` | Valid flag for downstream shared-center extraction |

### selectedWorkColumns

| Field | Meaning |
|---|---|
| `center_col` | Shared center column |
| `Q` | Number of local work columns, default 65 |
| `selected_col[k]` | Circular wrapped global column index |
| `selected_valid` | Selection output valid flag |

### Y_work

| Field | Meaning |
|---|---|
| `frame_id` | Inherited frame id |
| `detect_id` | Inherited detection id |
| `local_col_index` | Local index in selected 65 columns |
| `global_col_index` | Original azimuth column index |
| `layer_index` | Elevation / layer index |
| `sample_i` | Signed in-phase sample |
| `sample_q` | Signed quadrature sample |
| `sample_valid` | Stream valid flag |

### route_output

| Field | Meaning |
|---|---|
| `route_name` | Step8.7 selected route |
| `az_est` | Final azimuth estimate |
| `el_est` | Final elevation estimate |
| `confidence_level` | High / medium / low confidence code |
| `boundary_flag` | Boundary or unresolved warning |
| `rank1_flag` | Rank1 route decision flag |
| `pair_local_flag` | Pair-local route decision flag |
| `route_log_id` | Trace id for debugging and thesis evidence |

## Boundary

The FPGA boundary ends at local tensor construction and optional projection acceleration. The SoC boundary starts at Step8.7 route scheduling and numerically sensitive decision logic.
