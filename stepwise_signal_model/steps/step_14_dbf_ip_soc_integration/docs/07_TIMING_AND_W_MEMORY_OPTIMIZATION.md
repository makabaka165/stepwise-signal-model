# Step14.2a Timing And W Memory Optimization

Step14.2a optimizes the Step14.2 packaged DBF AXI4-Stream Custom IP for the
reference 200 MHz OOC synthesis target. It does not add DMA, PS, Block Design,
bitstream, XSA, HWH, board validation, or a full FPGA backend.

## Baseline Symptom

Step14.2 packaging and packaged-IP XSim were functionally correct, but the
reference post-synthesis timing estimate did not meet the advertised 200 MHz
clock.

Baseline reference result:

```text
part = xc7z020clg400-1
old_LUT = 3594
old_FF = 1810
old_DSP = 28
old_BRAM36_equiv = 28
old_WNS_ns = -8.586
timing_200MHz_met_flag = false
```

## RTL Changes

Step14.2a adds optimized RTL under the Step14 directory only:

- `dbf_complex_mac_pipe.v`: registered input, multiplication, and complex
  add/sub stages.
- `dbf_beam_accum_core_pipe.v`: uses the pipelined MAC and keeps ACC48
  accumulation behavior.
- `dbf_z24_quantizer_pipe.v`: pipelined equivalent of the Step13 Z24 rounding
  and saturation rule.
- `dbf_core_z24_pipe.v` and `dbf_core_z24_bparallel_pipe.v`: B=7 pipelined DBF
  core wrapper.
- `dbf_w_rom18_split.v` and `dbf_w_provider_rom_opt.v`: 2048-row XPM block ROM
  main segment plus 32-row tail for each W lane.
- `dbf_axis_datapath_pipe.v` and `dbf_axis_system_top_opt.v`: AXI datapath
  integration around the optimized provider/core.
- `dbf_axis_ip_top.v`: now instantiates the optimized system top.

Step13 tracked RTL is not modified.

## W ROM Layout

The Step14.1 14 W ROM files are split into 28 files:

```text
step14_1_w_re_b0_main.mem
step14_1_w_re_b0_tail.mem
...
step14_1_w_im_b6_main.mem
step14_1_w_im_b6_tail.mem
```

Each main file has 2048 rows and is inferred through XPM block ROM. Each tail
file has 32 rows. The reconstruction check passes:

```text
w_split_vector_pass_flag=true
w_split_reconstruction_match_flag=true
```

## Verification Result

Functional gates:

```text
optimized_raw_top_xsim_pass_flag=true
packaged_ip_xsim_pass_flag=true
packaged_ip_output_match_flag=true
expected_rows=14
actual_rows=14
matched_rows=14
```

Reference OOC synthesis result:

```text
LUT=2155
FF=4695
DSP=42
BRAM18=0
BRAM36=14
BRAM36_equiv=14.000
WNS_ns=0.377
TNS_ns=0.000
failing_endpoints=0
timing_200MHz_met_flag=true
timing_validates_advertised_clock_flag=true
w_memory_inferred_flag=true
w_memory_resource_optimization_pass_flag=true
```

Worst remaining estimated path:

```text
source = inst/u_system/u_w_provider/u_im0/u_main_sprom/.../douta_reg_reg/CLKARDCLK
destination = inst/u_system/u_datapath/u_core/gen_lane[0].u_lane/u_accum/u_mac/p_im_reg/A[0]
data_delay_ns = 4.177
logic_levels = 1
```

## Gate

```text
step14_2a_optimization_pass_flag=true
proceed_to_reference_bd_design_flag=true
proceed_to_target_board_dma_flag=false
proceed_to_board_validation_flag=false
proceed_to_full_fpga_backend_flag=false
custom_ip_packaged_flag=true
formal_result_claimed=false
block_design_created_flag=false
bitstream_generated_flag=false
xsa_generated_flag=false
hwh_generated_flag=false
```

Step14.2a allows the next reference Block Design stage to start. It does not
claim DMA, PS, DDR, board execution, implementation closure, or formal closure.

## Step14.2b Hardening Addendum

Step14.2b adds no new datapath feature. It hardens status semantics and audit
evidence before the later reference Block Design stage:

- `status_busy_semantics_pass` must be true for baseline, optimized raw top, and
  packaged-IP regressions.
- `w_provider_boundary_pass` checks split ROM addresses 0, 2047, 2048, 2079,
  invalid 2080, request gaps, and back-to-back main/tail requests.
- `quantizer_pipe_equivalence_pass` checks Step14 pipelined quantization against
  Step13 for directed boundaries and 1000 deterministic random ACC48 inputs.
- `drc_parser_consistency_pass_flag` requires DRC summary-table counts to match
  detail headings.
- `package_content_integrity_pass_flag` requires all copied HDL/MEM files to be
  nonempty and source/package SHA256-identical.

The corrected DRC warning counts are:

```text
baseline:  DPIP-1=42, DPOP-1=28, DPOP-2=28, ZPS7-1=1
optimized: DPIP-1=0,  DPOP-1=14, DPOP-2=0,  ZPS7-1=1
```

`step14_2b_hardening_pass_flag` is the gate for
`proceed_to_reference_bd_design_flag`.
