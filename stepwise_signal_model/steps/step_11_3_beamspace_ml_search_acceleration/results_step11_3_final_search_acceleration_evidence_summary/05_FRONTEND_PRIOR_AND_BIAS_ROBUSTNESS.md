# Frontend prior and bias robustness

The search center comes from the front-end coarse angle estimate. The simulation uses nominal center plus bias to emulate front-end error; it does not use the true target center.

- supported bias range: az_bias=[-0.20,0.20], el_bias=[-0.20,0.20]
- max_bias_success_drop = 0.06
- max_bias_topK_miss_rate = 0
- max_bias_boundary_hit_rate = 0
- frontend_prior_robustness_pass_flag = 1

Within the tested +/-0.2 deg azimuth/elevation bias cases, the Stage2 recommended configuration keeps topK miss at zero and boundary-hit rate at zero.
