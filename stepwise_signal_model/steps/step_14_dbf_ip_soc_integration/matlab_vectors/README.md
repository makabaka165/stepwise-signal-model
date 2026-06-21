# MATLAB Vectors

This directory contains Step14 vector generation and compare scripts.

Step14.1:

- `generate_step14_1_axis_vectors.m` reads only Step13.4 full-N golden CSV files
  and writes AXIS replay vectors, beam-separated W ROM `.mem` files, expected Z,
  metadata, and a manifest.
- `compare_step14_1_axis_outputs.m` compares raw RTL XSim output to the
  Step14.1 expected Z CSV.

Step14.2:

- `compare_step14_2_packaged_ip_outputs.m` compares packaged-IP XSim output to
  the same Step14.1 expected Z CSV.
- It aligns by `frame_index + beam_id` and checks TDATA, Z values, clip flags,
  overflow flags, TLAST, row count, duplicate rows, missing rows, and beam order.

Step14.2a:

- `generate_step14_2a_w_split_mem.m` splits the 14 Step14.1 W ROM files into 28
  main/tail files and verifies reconstruction.
- `compare_step14_2a_optimized_ip_outputs.m` compares the optimized packaged-IP
  output against the Step14.1 expected Z CSV and aggregates timing/resource
  gates.

The MATLAB scripts do not invoke Vivado. Run the Vivado package/validate
wrappers first, then run `run_step14_2_custom_ip_validation.m` or
`run_step14_2a_timing_memory_optimization.m` from the Step14 directory to
aggregate compare results and keypoints.
