Stage2 topK and grid sweep plan
===============================

Stage2 sweeps topK and grid steps to choose a recommended coarse-to-fine
configuration.

Fixed:

- `W = greedy_combined_B7`
- scenarios: same five representative scenarios as Stage1
- `Metkl = 10`

Sweep:

- `topK_list = [1, 3, 5, 10]`
- `coarse_az_step_list = [0.12, 0.16, 0.20]`
- `coarse_el_step_list = [0.18, 0.24, 0.30]`
- `fine_az_step_list = [0.04, 0.02]`
- `fine_el_step_list = [0.06, 0.04]`

Recommendation rule:

Choose the minimum candidate-count configuration satisfying:

- success at least 95% of full-fine success;
- RMSE at most 105% of full-fine RMSE;
- topK miss rate no more than 0.05.

