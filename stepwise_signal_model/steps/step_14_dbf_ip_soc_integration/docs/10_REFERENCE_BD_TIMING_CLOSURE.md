# Step14.3b Reference BD Timing Closure

Step14.3b closes the 200 MHz post-route timing gate for the Step14.3a
board-independent Reference BD.

The starting point is the Step14.3a functional pass with timing failure:

```text
Reference BD structure = pass
validate_bd_design = pass
wrapper generation = pass
Reference BD XSim = pass
Case A exact compare = 14/14
Case B FIFO/backpressure stress exact compare = 28/28
synthesis = pass
route_completed_flag = true
post_route_WNS_ns = -0.076
post_route_TNS_ns = -0.079
post_route_failing_endpoints = 2
post_route_WHS_ns = 0.096
post_route_hold_failing_endpoints = 0
blocker_if_any = post_route_timing_200MHz_not_met
```

## Fixed Scope

Step14.3b keeps the same RTL, Custom IP, Reference BD topology, FIFO sizes, and
clock target during Phase A:

```text
S_AXIS_Y
-> axis_in_fifo_0
-> dbf_axis_0 (user.org:radar:dbf_axis:1.0)
-> axis_out_fifo_0
-> M_AXIS_Z
```

The clock target remains 200 MHz:

```text
clock_period_ns = 5.000
advertised_aclk_Hz = 200000000
timing_margin_pass_flag requires WNS >= 0.100 ns
```

The flow does not lower the clock, change advertised clock metadata, add data
false paths, add multicycle exceptions, relax setup with `set_max_delay`,
delete endpoints, or edit summary CSVs as a timing fix.

## Phase A Strategy Sweep

Phase A runs Vivado implementation strategy variants against the same
synthesized Reference BD netlist. It includes the Step14.3a baseline strategy
and Vivado-supported performance strategies discovered on the installed Vivado
2024.2 toolchain.

Each sweep run is launched with `-to_step route_design`. The CSV therefore
records `implementation_stop_step=route_design` and
`post_route_phys_opt_executed_flag` for each row. A strategy name such as
`Performance_ExplorePostRoutePhysOpt` means the Vivado strategy was accepted by
the implementation run, not that a separate post-route phys-opt step was
completed in this sweep.

The sweep writes:

```text
results_step14_dbf_ip_soc_integration/reference_bd_timing/
  step14_3b_available_strategies.csv
  step14_3b_unavailable_requested_strategies.csv
  step14_3b_strategy_sweep.csv
  step14_3b_best_strategy.csv
  step14_3b_best_timing_summary.rpt
  step14_3b_best_timing_paths.rpt
  step14_3b_best_utilization.rpt
  step14_3b_best_drc_summary.csv
  step14_3b_best_methodology_summary.csv
```

Best strategy selection is stable:

```text
route_completed_flag = true
prefer timing_margin_pass_flag
then timing_met_flag
then larger WNS
then larger TNS
then fewer setup failing endpoints
then lexicographic strategy name
```

If the best strategy reaches `WNS >= 0.100 ns`, Step14.3b performs one
independent clean rerun using only that strategy. Phase A is accepted only when
both the sweep and clean rerun meet the 0.100 ns margin.

## Phase B Rule

Phase B is allowed only if Phase A cannot reach the 0.100 ns engineering margin.
When Phase A succeeds, Step14.3b does not modify DBF RTL, does not add operand
pipeline latency, does not repackage the Custom IP, and does not alter
`component.xml`.

If Phase B is ever required, the only permitted RTL change is one local operand
input pipeline stage in `rtl/dbf_complex_mac_pipe.v`, with unchanged DBF
mathematics, bit widths, coefficient values, AXI4-Stream protocol, and
throughput.

## Step14.3b Result

Vivado 2024.2 ran the Step14.3b strategy sweep on the same Step14.3a Reference
BD and selected `Performance_NetDelay_high`. The independent clean rerun with
that strategy also met the 200 MHz margin:

```text
phase_a_strategy_count = 9
phase_a_best_strategy = Performance_NetDelay_high
phase_a_best_implementation_stop_step = route_design
phase_a_best_post_route_phys_opt_executed_flag = false
phase_a_best_WNS_ns = 0.205
phase_a_clean_rerun_pass_flag = true
phase_b_required_flag = false
operand_pipeline_added_flag = false
operand_pipeline_extra_latency_cycles = 0
mac_pipe_equivalence_applicable_flag = false
mac_pipe_equivalence_status = not_applicable
input_throughput_samples_per_cycle = 1
final_WNS_ns = 0.205
final_TNS_ns = 0.000
final_setup_failing_endpoints = 0
final_WHS_ns = 0.093
final_hold_failing_endpoints = 0
final_LUT = 2096
final_FF = 5031
final_DSP = 42
final_BRAM18 = 1
final_BRAM36 = 16
```

Because Phase A closed timing with margin, Phase B was not triggered and no
operand input pipeline was added. The MAC pipeline equivalence test is therefore
not applicable for this artifact set; its gate status records that the missing
test is non-blocking only because Phase B was not required.

The final aggregator reads regression evidence from the original result CSVs:
Step14.1 AXIS compare, optimized raw-top XSim summaries, packaged-IP XSim
summaries, and packaged-IP exact compare. These flags are no longer inferred
from the Step14.2b aggregate gate alone.

## External Clock Metadata

The Reference BD creation script explicitly records external clock association
metadata when Vivado exposes the properties:

```text
CONFIG.ASSOCIATED_BUSIF = S_AXIS_Y:M_AXIS_Z
CONFIG.ASSOCIATED_RESET = aresetn
CONFIG.FREQ_HZ = 200000000
```

`external_clock_association_pass_flag` is required for the final Step14.3b gate.

## Methodology Classification

The Reference BD is a board-independent OOC wrapper with external AXIS ports.
`TIMING-18` methodology warnings are expected in this context because a real
platform will connect these ports to on-chip infrastructure rather than FPGA
package pins.

The final gate allows expected `TIMING-18` only. Any methodology Error or
Critical Warning outside the expected category blocks closure.

## Final Gate

Step14.3b passes only when:

```text
step14_2b_hardening_pass_flag
AND step14_3a_functional_evidence_pass_flag
AND external_clock_association_pass_flag
AND reference_methodology_expected_only_flag
AND phase_a_or_phase_b_all_regressions_pass
AND final_WNS_ns >= 0
AND final_TNS_ns == 0
AND final_setup_failing_endpoints == 0
AND final_hold_failing_endpoints == 0
AND final_WNS_ns >= 0.100
```

When the final flag is true:

```text
step14_reference_bd_integration_pass_flag=true
proceed_to_platform_freeze_flag=true
proceed_to_target_board_dma_flag=false
proceed_to_board_validation_flag=false
proceed_to_full_fpga_backend_flag=false
formal_result_claimed=false
bitstream_generated_flag=false
xsa_generated_flag=false
hwh_generated_flag=false
```

Step14.3b remains a Reference BD timing-closure step. It is not DMA, PS,
AXI-Lite, bitstream, XSA/HWH, target-board, full backend, or formal closure.
