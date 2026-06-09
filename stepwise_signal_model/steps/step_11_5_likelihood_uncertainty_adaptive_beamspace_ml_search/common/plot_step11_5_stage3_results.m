function plot_paths = plot_step11_5_stage3_results(alt_summary_table, repeat_summary_table, branch_trial_table, keypoints, result_dir)
%PLOT_STEP11_5_STAGE3_RESULTS Generate Stage3 required enhancement PNG figures.

if nargin < 5
    error('plot_step11_5_stage3_results:NotEnoughInputs', ...
        'alt_summary_table, repeat_summary_table, branch_trial_table, keypoints, and result_dir are required.');
end
if exist(result_dir, 'dir') ~= 7
    mkdir(result_dir);
end
plot_paths = {};

fig = figure('Visible', 'off');
val = alt_summary_table(strcmp(alt_summary_table.summary_scope, 'split_scheme_split') & ...
    strcmp(alt_summary_table.split_name, 'validation'), :);
if isempty(val)
    bar(categorical({'none'}), 0);
else
    cats = categorical(val.split_scheme);
    cats = reordercats(cats, cellstr(val.split_scheme));
    bar(cats, [val.adaptive_vs_fixed_pair_count_ratio, val.adaptive_full_grid_match_rate]);
    ylim([0, 1.10]);
    ylabel('rate');
    legend({'pair count ratio','full-grid match'}, 'Location', 'best');
end
title('Stage3 alternative validation splits');
grid on;
plot_paths{end + 1} = save_png_local(fig, result_dir, 'step11_5_stage3_alt_split_recheck.png');

fig = figure('Visible', 'off');
seed_rows = repeat_summary_table(strcmp(repeat_summary_table.summary_scope, 'seed_group_all'), :);
if isempty(seed_rows)
    bar(categorical({'none'}), 0);
else
    cats = categorical(compose('seed%d', seed_rows.seed_group_id));
    cats = reordercats(cats, cellstr(cats));
    bar(cats, [seed_rows.adaptive_vs_fixed_pair_count_ratio, seed_rows.adaptive_full_grid_match_rate]);
    ylim([0, 1.10]);
    ylabel('rate');
    legend({'pair count ratio','full-grid match'}, 'Location', 'best');
end
title('Stage3 repeat-seed larger-Metkl recheck');
grid on;
plot_paths{end + 1} = save_png_local(fig, result_dir, 'step11_5_stage3_repeat_seed_metkl_recheck.png');

fig = figure('Visible', 'off');
if isempty(branch_trial_table)
    bar(categorical({'none'}), 0);
else
    cats = categorical(branch_trial_table.branch_case_name);
    cats = reordercats(cats, cellstr(branch_trial_table.branch_case_name));
    bar(cats, [branch_trial_table.branch_triggered, branch_trial_table.reasonable_safe_output, ...
        branch_trial_table.high_confidence_misuse]);
    ylim([0, 1.10]);
    ylabel('flag');
    legend({'triggered','safe output','high confidence misuse'}, 'Location', 'best');
end
title('Stage3 targeted branch safety outputs');
grid on;
plot_paths{end + 1} = save_png_local(fig, result_dir, 'step11_5_stage3_targeted_branch_recheck.png');

fig = figure('Visible', 'off');
cats = categorical({'alt split','repeat seed','targeted branch','overall'});
cats = reordercats(cats, {'alt split','repeat seed','targeted branch','overall'});
bar(cats, [keypoints.alt_split_recheck_pass_flag, keypoints.repeat_seed_metkl_recheck_pass_flag, ...
    keypoints.targeted_branch_recheck_pass_flag, keypoints.stage3_required_enhancement_pass_flag]);
ylim([0, 1.10]);
ylabel('pass flag');
title('Stage3 required enhancement pass flags');
grid on;
plot_paths{end + 1} = save_png_local(fig, result_dir, 'step11_5_stage3_pass_flags.png');
end

function path = save_png_local(fig, result_dir, file_name)
path = fullfile(result_dir, file_name);
try
    exportgraphics(fig, path, 'Resolution', 150);
catch
    saveas(fig, path);
end
close(fig);
end
