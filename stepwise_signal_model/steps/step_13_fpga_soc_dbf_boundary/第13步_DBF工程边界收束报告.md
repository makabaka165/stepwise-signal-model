# Step13.4 DBF Engineering Boundary Closure Report

## Scope

FPGA scope is DBF only: `Z = W^H Y`.

The closed datapath is:

```text
Y stream -> W input/read -> conj(W)*Y -> full-N accumulation -> fixed shift -> symmetric rounding -> signed int24 saturation -> Z output + clip/overflow flags
```

CPU/SoC remains responsible for `Rz/G_cache/2D ML/topK/C05/confidence/boundary/fallback/logging/final output` by design. These are not missing FPGA RTL modules.

## Functional Evidence

- W method: `greedy_combined_B7`
- N/B/L sweep: `2080 / 7 / 16`
- full-N RTL L snapshots: `2`
- recommended DBF format: `mixed_W18_Y16_Z24`
- fallback DBF format: `mixed_W24_Y16_Z24`
- ACC/Z bits: `48 / 24`
- engineering Z shift bits: `20`
- fixed shift policy pass: `true`
- minimum observed headroom bits: `1`
- global clip / overflow count: `0 / 0`
- full-N functional pass: `true`
- full-N accumulator / Z24 match: `true / true`
- full-N missing / mismatch count: `0 / 0`

## Vivado OOC Synthesis

- Vivado part: `xc7z020clg400-1`
- part source: `reference_default`
- reference device only: `true`
- single lane LUT/FF/DSP/BRAM36/URAM/WNS: `487 / 193 / 4 / 0 / 0 / 1.675`
- B=7 LUT/FF/DSP/BRAM36/URAM/WNS: `3376 / 1345 / 28 / 0 / 0 / 1.675`
- OOC synthesis pass: `true`
- 200 MHz post-synthesis timing met: `true`

This is reference-device out-of-context synthesis evidence only. It is not implementation closure, board timing closure, bitstream generation, or final board resource characterization.

The earlier rough B=7 DSP estimate was 21. Vivado OOC reports 28 DSP for the current RTL, i.e. 4 DSP per complex lane.

## Closure Flags

- step13_engineering_closure_flag: `true`
- proceed_to_dbf_ip_integration_flag: `true`
- proceed_to_full_fpga_backend_flag: `0`
- proceed_to_board_validation_flag: `0`
- formal_result_claimed: `false`
- recommended_next_action: `prepare_dbf_ip_integration_plan_with_board_specific_constraints`

Step13 closure only covers FPGA DBF engineering feasibility. It does not cover a complete FPGA backend, board validation, or CPU/SoC ML software integration.
