# MATLAB Golden Data

This directory contains small-vector MATLAB scripts for RTL module validation.

- `generate_fpga_test_vectors.m` writes deterministic CSV golden vectors for the column selector, Y_work packer, and projection score core.
- `compare_fpga_sim_outputs.m` compares simulator output CSV files against the generated golden CSV files and prints pass/fail.

Do not save large `.mat` files here. If small vectors need to be committed later, place them in `matlab_golden/test_vectors_small/`.
