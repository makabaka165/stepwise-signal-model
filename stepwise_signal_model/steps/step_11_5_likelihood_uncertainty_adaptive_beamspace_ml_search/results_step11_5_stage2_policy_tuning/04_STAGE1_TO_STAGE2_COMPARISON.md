# Step11.5 Stage1 To Stage2 Comparison

## Stage1

Step11.5 Stage1: original uncertainty policy negative result / safety passed but complexity failed

- fixed_topK3_mean_num_pairs = 19126.26
- stage1_adaptive_mean_num_pairs = 38749.86
- policy distribution: EASY=0, NORMAL=0, HARD=1, UNSAFE=0
- conclusion: safety passed but complexity failed.

## Stage2

- selected_config_name = `C05_easy_very_aggressive`
- fixed_topK3_mean_num_pairs = 19090.62
- stage2_selected_adaptive_mean_num_pairs = 13668.3
- stage2_selected_pair_count_ratio = 0.715969413251
- stage2_adaptive_pass_flag = 1

Stage2 corrects the Stage1 over-conservative mapping by making fixed topK3 the NORMAL default and limiting window expansion to boundary-risk samples.
