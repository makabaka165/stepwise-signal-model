# Step13.4 Vivado OOC Synthesis

This folder contains the reference-device out-of-context synthesis flow for the
Step13 FPGA DBF arithmetic boundary.

The flow synthesizes only:

- `dbf_core_z24_ref_top`: one complex DBF lane
- `dbf_core_z24_b7_ref_top`: B=7 beam-parallel arithmetic reference top

It does not generate a bitstream, does not run place/route, and does not claim
board timing closure. `Rz/G_cache/2D ML/topK/C05/confidence/boundary/fallback`
remain CPU/SoC responsibilities by design.

Run from the Step13 directory after loading Vivado 2024.2:

```powershell
powershell -ExecutionPolicy Bypass -File synth/run_vivado_ooc_synth.ps1
```

Optional environment variables:

- `STEP13_FPGA_PART`: explicit FPGA part. If set, it must exist in Vivado.
- `STEP13_4_CLOCK_MHZ`: reference synthesis clock, default `200`.

Outputs are written to
`results_step13_fpga_soc_dbf_boundary/synth/`.

Current Step13.4 result:

- Vivado version: `2024.2`
- FPGA part: `xc7z020clg400-1`
- `fpga_part_source=reference_default`
- `reference_device_only=true`
- `clock_MHz=200`
- single lane: `LUT=487`, `FF=193`, `DSP=4`, `BRAM36=0`, `URAM=0`,
  `WNS=1.675 ns`
- B=7 parallel: `LUT=3376`, `FF=1345`, `DSP=28`, `BRAM36=0`, `URAM=0`,
  `WNS=1.675 ns`
- `ooc_synthesis_pass_flag=true`
- `timing_200MHz_met_flag=true`
- `formal_result_claimed=false`
- `implementation_closure_claimed=false`
- `board_validation_flag=false`

The old rough B=7 DSP estimate was `21`; Vivado reports `28` DSP for the
current RTL, or `4` DSP per complex lane.
