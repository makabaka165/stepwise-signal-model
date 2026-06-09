# Ill-Conditioned Real-Search Stress Recheck

## Purpose

This recheck attempts to make the fixed C05 ILL_CONDITIONED branch trigger naturally in the real search pipeline. It does not lower `cond_threshold`, does not force policy labels, and does not use truth for policy decisions.

## Stress case table

| stress_group | stress_case_name | az_sep_deg | el_sep_deg | rho | phase_deg | beta | snr_db |
| --- | --- | --- | --- | --- | --- | --- | --- |
| close_same_elevation_coherent_pair | ill_real_sep_0p30_phase0 | 0.3 | 0 | 1 | 0 | 1 | 40 |
| close_same_elevation_coherent_pair | ill_real_sep_0p20_phase0 | 0.2 | 0 | 1 | 0 | 1 | 40 |
| close_same_elevation_coherent_pair | ill_real_sep_0p15_phase0 | 0.15 | 0 | 1 | 0 | 1 | 40 |
| close_same_elevation_coherent_pair | ill_real_sep_0p10_phase0 | 0.1 | 0 | 1 | 0 | 1 | 40 |
| near_antiphase_close_pair | ill_real_sep_0p30_phase180 | 0.3 | 0 | 1 | 180 | 1 | 40 |
| near_antiphase_close_pair | ill_real_sep_0p20_phase180 | 0.2 | 0 | 1 | 180 | 1 | 40 |
| near_antiphase_close_pair | ill_real_sep_0p15_phase180 | 0.15 | 0 | 1 | 180 | 1 | 40 |
| near_antiphase_close_pair | ill_real_sep_0p10_phase180 | 0.1 | 0 | 1 | 180 | 1 | 40 |
| weak_secondary_close_pair | ill_real_sep_0p20_beta03_phase0 | 0.2 | 0 | 1 | 0 | 0.3 | 40 |
| weak_secondary_close_pair | ill_real_sep_0p15_beta03_phase0 | 0.15 | 0 | 1 | 0 | 0.3 | 40 |
| lower_snr_close_pair | ill_real_sep_0p20_snr20 | 0.2 | 0 | 1 | 0 | 1 | 20 |
| lower_snr_close_pair | ill_real_sep_0p15_snr20 | 0.15 | 0 | 1 | 0 | 1 | 20 |

## Summary

| summary_scope | stress_group | stress_case_name | n_trials | fixed_success | adaptive_success | fixed_rmse | adaptive_rmse | fixed_mean_num_pairs | adaptive_mean_num_pairs | adaptive_vs_fixed_pair_count_ratio | ill_conditioned_real_trigger_rate | ill_conditioned_real_trigger_count | mean_cond_risk | max_cond_risk | mean_cond_best_GHG | max_cond_best_GHG | low_confidence_rate | medium_low_confidence_rate | high_confidence_misuse_rate | adaptive_topK_miss_rate | adaptive_boundary_hit_rate | safe_confidence_pass_flag |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| stress_group | close_same_elevation_coherent_pair |  | 40 | 0 | 0 | 0.322214725001 | 0.322214725001 | 16920 | 19161 | 1.13244680851 | 0 | 0 | 0.181026762729 | 0.203160669221 | 33.7131218237 | 42.1973670727 | 0 | 1 | 0 | 0.25 | 0 | 1 |
| stress_group | near_antiphase_close_pair |  | 40 | 1 | 1 | 0.0653726610726 | 0.0653726610726 | 18936 | 18936 | 1 | 0 | 0 | 0.225446533226 | 0.225446533226 | 63.6168653336 | 63.6168653336 | 0 | 0 | 0 | 0 | 0 | 1 |
| stress_group | weak_secondary_close_pair |  | 20 | 0 | 0 | 0.360350909598 | 0.360350909598 | 16425.5 | 19172.5 | 1.16723996225 | 0 | 0 | 0.153767094768 | 0.153767094768 | 16.9877850894 | 16.9877850894 | 0 | 1 | 0 | 0 | 0 | 1 |
| stress_group | lower_snr_close_pair |  | 20 | 0 | 0 | 0.347215133169 | 0.347215133169 | 16920 | 18756 | 1.1085106383 | 0 | 0 | 0.203160669221 | 0.203160669221 | 42.1973670727 | 42.1973670727 | 0 | 1 | 0 | 0 | 0 | 1 |
| stress_case |  | ill_real_sep_0p30_phase0 | 10 | 0 | 0 | 0.381837661841 | 0.381837661841 | 18504 | 20376 | 1.10116731518 | 0 | 0 | 0.114625043251 | 0.114625043251 | 8.26038607686 | 8.26038607686 | 0 | 1 | 0 | 1 | 0 | 1 |
| stress_case |  | ill_real_sep_0p20_phase0 | 10 | 0 | 0 | 0.359583091927 | 0.359583091927 | 18504 | 18756 | 1.01361867704 | 0 | 0 | 0.203160669221 | 0.203160669221 | 42.1973670727 | 42.1973670727 | 0 | 1 | 0 | 0 | 0 | 1 |
| stress_case |  | ill_real_sep_0p15_phase0 | 10 | 0 | 0 | 0.330643312347 | 0.330643312347 | 15336 | 18756 | 1.22300469484 | 0 | 0 | 0.203160669221 | 0.203160669221 | 42.1973670727 | 42.1973670727 | 0 | 1 | 0 | 0 | 0 | 1 |
| stress_case |  | ill_real_sep_0p10_phase0 | 10 | 0 | 0 | 0.216794833887 | 0.216794833887 | 15336 | 18756 | 1.22300469484 | 0 | 0 | 0.203160669221 | 0.203160669221 | 42.1973670727 | 42.1973670727 | 0 | 1 | 0 | 0 | 0 | 1 |
| stress_case |  | ill_real_sep_0p30_phase180 | 10 | 1 | 1 | 0.0883176086633 | 0.0883176086633 | 18936 | 18936 | 1 | 0 | 0 | 0.225446533226 | 0.225446533226 | 63.6168653336 | 63.6168653336 | 0 | 0 | 0 | 0 | 0 | 1 |
| stress_case |  | ill_real_sep_0p20_phase180 | 10 | 1 | 1 | 0.0574456264654 | 0.0574456264654 | 18936 | 18936 | 1 | 0 | 0 | 0.225446533226 | 0.225446533226 | 63.6168653336 | 63.6168653336 | 0 | 0 | 0 | 0 | 0 | 1 |
| stress_case |  | ill_real_sep_0p15_phase180 | 10 | 1 | 1 | 0.054083269132 | 0.054083269132 | 18936 | 18936 | 1 | 0 | 0 | 0.225446533226 | 0.225446533226 | 63.6168653336 | 63.6168653336 | 0 | 0 | 0 | 0 | 0 | 1 |
| stress_case |  | ill_real_sep_0p10_phase180 | 10 | 1 | 1 | 0.0616441400297 | 0.0616441400297 | 18936 | 18936 | 1 | 0 | 0 | 0.225446533226 | 0.225446533226 | 63.6168653336 | 63.6168653336 | 0 | 0 | 0 | 0 | 0 | 1 |
| stress_case |  | ill_real_sep_0p20_beta03_phase0 | 10 | 0 | 0 | 0.440478693812 | 0.440478693812 | 15808 | 19228 | 1.21634615385 | 0 | 0 | 0.153767094768 | 0.153767094768 | 16.9877850894 | 16.9877850894 | 0 | 1 | 0 | 0 | 0 | 1 |
| stress_case |  | ill_real_sep_0p15_beta03_phase0 | 10 | 0 | 0 | 0.280223125384 | 0.280223125384 | 17043 | 19117 | 1.12169219034 | 0 | 0 | 0.153767094768 | 0.153767094768 | 16.9877850894 | 16.9877850894 | 0 | 1 | 0 | 0 | 0 | 1 |
| stress_case |  | ill_real_sep_0p20_snr20 | 10 | 0 | 0 | 0.363786953991 | 0.363786953991 | 18504 | 18756 | 1.01361867704 | 0 | 0 | 0.203160669221 | 0.203160669221 | 42.1973670727 | 42.1973670727 | 0 | 1 | 0 | 0 | 0 | 1 |
| stress_case |  | ill_real_sep_0p15_snr20 | 10 | 0 | 0 | 0.330643312347 | 0.330643312347 | 15336 | 18756 | 1.22300469484 | 0 | 0 | 0.203160669221 | 0.203160669221 | 42.1973670727 | 42.1973670727 | 0 | 1 | 0 | 0 | 0 | 1 |
| overall |  |  | 120 | 0.333333333333 | 0.333333333333 | 0.247123469152 | 0.247123469152 | 17509.5833333 | 19020.4166667 | 1.08628608143 | 0 | 0 | 0.194979059316 | 0.225446533226 | 42.3075210795 | 63.6168653336 | 0 | 0.666666666667 | 0 | 0.0833333333333 | 0 | 1 |

## Guard probe

| probe_name | cond_risk | boundary_risk | gap_13 | H_norm | U_search | U_confidence | policy_name | confidence | boundary_flag | adaptive_topK | az_window_scale | el_window_scale | guard_probe_pass_flag |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| d | 0.9 | 0 | 0.001 | 0.8 | 0.458333333333 | 0.671666666667 | I | l | i | 3 | 1 | 1 | 1 |

## Key result

- illcond_real_trigger_count = 0
- illcond_real_trigger_rate = 0
- illcond_max_cond_risk = 0.225446533226
- illcond_max_cond_best_GHG = 63.6168653336
- illcond_high_confidence_misuse_rate = 0
- illcond_real_stress_pass_flag = 0
- illcond_guard_probe_pass_flag = 1
- result text = `ill_conditioned_real_stress_not_naturally_triggered_under_current_fixed_C05_and_grid`

ILL_CONDITIONED was not naturally triggered in real-search stress under the current fixed C05/W/grid/threshold setting. The deterministic guard probe remains only logic evidence and must not be described as real-search triggering.
