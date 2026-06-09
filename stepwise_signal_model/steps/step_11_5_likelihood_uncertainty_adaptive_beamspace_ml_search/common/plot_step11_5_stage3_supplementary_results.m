function plot_paths = plot_step11_5_stage3_supplementary_results(metkl_summary_table, ill_trial_table, ill_summary_table, result_dir)
%PLOT_STEP11_5_STAGE3_SUPPLEMENTARY_RESULTS Generate Stage3 supplementary PNG figures.

if nargin < 4
    error('plot_step11_5_stage3_supplementary_results:NotEnoughInputs', ...
        'metkl_summary_table, ill_trial_table, ill_summary_table, and result_dir are required.');
end
if exist(result_dir, 'dir') ~= 7
    mkdir(result_dir);
end
plot_paths = {};

seed_rows = metkl_summary_table(strcmp(metkl_summary_table.summary_scope, 'seed_group'), :);
policy_rows = metkl_summary_table(strcmp(metkl_summary_table.summary_scope, 'policy'), :);

fig = figure('Visible', 'off');
if isempty(seed_rows)
    bar(categorical({'none'}), 0);
else
    cats = categorical(compose('seed%d', seed_rows.seed_group_id));
    cats = reordercats(cats, cellstr(cats));
    bar(cats, [seed_rows.fixed_mean_num_pairs, seed_rows.adaptive_mean_num_pairs]);
    ylabel('mean candidate count');
    legend({'fixed topK3','C05 adaptive'}, 'Location', 'best');
end
title('Stage3 supplementary Metkl30 candidate count');
grid on;
plot_paths{end + 1} = save_png_local(fig, result_dir, 'step11_5_stage3_supp_metkl30_pair_count.png');

fig = figure('Visible', 'off');
if isempty(seed_rows)
    bar(categorical({'none'}), 0);
else
    cats = categorical(compose('seed%d', seed_rows.seed_group_id));
    cats = reordercats(cats, cellstr(cats));
    bar(cats, [seed_rows.adaptive_success, seed_rows.adaptive_full_grid_match_rate, ...
        1 - seed_rows.adaptive_topK_miss_rate, 1 - seed_rows.adaptive_boundary_hit_rate]);
    ylim([0, 1.10]);
    ylabel('rate');
    legend({'success','full-grid match','1-topK miss','1-boundary hit'}, 'Location', 'best');
end
title('Stage3 supplementary Metkl30 safety');
grid on;
plot_paths{end + 1} = save_png_local(fig, result_dir, 'step11_5_stage3_supp_metkl30_safety.png');

fig = figure('Visible', 'off');
if isempty(policy_rows)
    bar(categorical({'none'}), 0);
else
    cats = categorical(policy_rows.policy_name);
    cats = reordercats(cats, cellstr(policy_rows.policy_name));
    bar(cats, policy_rows.n_trials);
    ylabel('trial count');
end
title('Stage3 supplementary Metkl30 policy distribution');
grid on;
plot_paths{end + 1} = save_png_local(fig, result_dir, 'step11_5_stage3_supp_metkl30_policy_distribution.png');

fig = figure('Visible', 'off');
case_rows = ill_summary_table(strcmp(ill_summary_table.summary_scope, 'stress_case'), :);
if isempty(case_rows)
    bar(categorical({'none'}), 0);
else
    cats = categorical(case_rows.stress_case_name);
    cats = reordercats(cats, cellstr(case_rows.stress_case_name));
    bar(cats, case_rows.ill_conditioned_real_trigger_rate);
    ylim([0, 1.10]);
    ylabel('trigger rate');
end
title('Stage3 supplementary ill-conditioned real trigger rate');
grid on;
plot_paths{end + 1} = save_png_local(fig, result_dir, 'step11_5_stage3_supp_illcond_trigger_rate.png');

fig = figure('Visible', 'off');
group_rows = ill_summary_table(strcmp(ill_summary_table.summary_scope, 'stress_group'), :);
if isempty(group_rows)
    bar(categorical({'none'}), 0);
else
    cats = categorical(group_rows.stress_group);
    cats = reordercats(cats, cellstr(group_rows.stress_group));
    bar(cats, [group_rows.low_confidence_rate, group_rows.medium_low_confidence_rate, ...
        group_rows.high_confidence_misuse_rate]);
    ylim([0, 1.10]);
    ylabel('rate');
    legend({'low confidence','medium-low confidence','high-confidence misuse'}, 'Location', 'best');
end
title('Stage3 supplementary ill-conditioned confidence safety');
grid on;
plot_paths{end + 1} = save_png_local(fig, result_dir, 'step11_5_stage3_supp_illcond_confidence_safety.png');

fig = figure('Visible', 'off');
if isempty(ill_trial_table)
    histogram(0);
else
    histogram(ill_trial_table.cond_risk, 20);
    xlabel('cond\_risk');
    ylabel('trial count');
end
title('Stage3 supplementary ill-conditioned cond risk distribution');
grid on;
plot_paths{end + 1} = save_png_local(fig, result_dir, 'step11_5_stage3_supp_illcond_cond_risk_distribution.png');
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
