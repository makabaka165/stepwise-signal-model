# Step14.2b Status And Audit Hardening

Step14.2b hardens the existing Step14.2a Custom IP evidence chain. It does not
add DMA, PS, Block Design, AXI-Lite, bitstream, board validation, or a full FPGA
backend.

## Status Semantics

`status_busy` now covers the complete frame lifetime:

```text
status_busy = frame_active || (state != ST_RX) || serializer_busy
```

`frame_active` is set by the first accepted Y sample and cleared only after the
final Z beat is accepted. The raw baseline, optimized raw top, and packaged-IP
testbenches check:

- busy low after reset
- busy high from first Y accept
- busy high during DRAIN
- busy high during output backpressure
- busy low after final Z accept

This does not change `S_AXIS_Y` or `M_AXIS_Z` protocol behavior.

## Directed Regressions

Step14.2b adds two source-level XSim tests:

- `tb_dbf_w_provider_rom_opt_boundary.v`: checks split W ROM response latency,
  addresses 0, 2047, 2048, 2079, invalid 2080, request gaps, and back-to-back
  main/tail requests.
- `tb_dbf_z24_quantizer_pipe_equiv.v`: compares Step13 `dbf_z24_quantizer`
  against Step14 `dbf_z24_quantizer_pipe` with pipeline latency compensation,
  directed boundary inputs, valid gaps, back-to-back valid, and 1000
  deterministic pseudo-random ACC48 values.

## DRC Count Semantics

DRC counts are parsed from the report summary table and cross-checked against
detail headings of the form `RULE#N`. The intended counts are:

```text
baseline:  DPIP-1=42, DPOP-1=28, DPOP-2=28, ZPS7-1=1
optimized: DPIP-1=0,  DPOP-1=14, DPOP-2=0,  ZPS7-1=1
```

`drc_parser_consistency_pass_flag=true` requires the summary table count to
match the detail heading count.

## Package Provenance

The package manifest records source and packaged paths, source base commit,
dirty state sampled before package rebuild, source/package sizes, SHA256 values,
and `content_match`. Nonempty HDL and MEM files must not report the empty-file
SHA256, and every copied source/package pair must match in size and SHA256.

The second-stage package refresh must run from a clean worktree so
`source_worktree_dirty=false` and `source_base_commit` equals the first-stage
hardening commit.
