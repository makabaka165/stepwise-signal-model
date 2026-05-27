clc
clear
close all

script_dir = fileparts(mfilename('fullpath'));
if isempty(script_dir)
    script_dir = pwd;
end

orig_result_dir = fullfile(script_dir, 'results_step8_7_6_observable_dispatch_demo');
cal_result_dir = fullfile(script_dir, 'results_step8_7_6b_observable_dispatch_calibrated');

orig_summary_path = fullfile(orig_result_dir, 'step8_7_6_observable_dispatch_demo_summary.csv');
cal_summary_path = fullfile(cal_result_dir, 'step8_7_6b_observable_dispatch_calibrated_summary.csv');

if ~exist(orig_summary_path, 'file')
    error('Missing original part-6 summary: %s', orig_summary_path);
end
if ~exist(cal_summary_path, 'file')
    error('Missing calibrated part-6B summary: %s', cal_summary_path);
end

orig_tbl = readtable(orig_summary_path, 'TextType', 'string');
cal_tbl = readtable(cal_summary_path, 'TextType', 'string');

orig_obs = orig_tbl(orig_tbl.route_name == "observable_dispatch", :);
cal_obs = cal_tbl(cal_tbl.route_name == "observable_dispatch", :);
groups = unique(string(cal_obs.group), 'stable');

plot_compare_metric_by_group_local( ...
    groups, orig_obs, cal_obs, 'joint_tol_success_rate', ...
    'Observable dispatch success', 'joint success rate', ...
    fullfile(cal_result_dir, 'calibrated_vs_original_success.png'));

plot_compare_metric_by_group_local( ...
    groups, orig_obs, cal_obs, 'false_high_confidence_rate', ...
    'False-high-confidence rate', 'rate', ...
    fullfile(cal_result_dir, 'calibrated_false_high_confidence.png'));

plot_compare_metric_by_group_local( ...
    groups, orig_obs, cal_obs, 'dispatch_low_confidence_rate', ...
    'Low-confidence rate', 'rate', ...
    fullfile(cal_result_dir, 'calibrated_low_confidence_rate.png'));

plot_compare_metric_by_group_local( ...
    groups, orig_obs, cal_obs, 'boundary_missed_rate', ...
    'Boundary-missed rate', 'rate', ...
    fullfile(cal_result_dir, 'calibrated_boundary_missed_rate.png'));

plot_route_distribution_by_group_local( ...
    groups, cal_obs, fullfile(cal_result_dir, 'calibrated_route_distribution_by_group.png'));

function plot_compare_metric_by_group_local(groups, orig_obs, cal_obs, colname, ttl, ylbl, path_out)
    vals = zeros(numel(groups), 2);
    for ig = 1:numel(groups)
        vals(ig, 1) = mean(orig_obs.(colname)(orig_obs.group == groups(ig)), 'omitnan');
        vals(ig, 2) = mean(cal_obs.(colname)(cal_obs.group == groups(ig)), 'omitnan');
    end
    fig = figure('Visible', 'off');
    bar(vals);
    grid on
    ylim([-0.05, 1.05]);
    set(gca, 'XTick', 1:numel(groups), 'XTickLabel', cellstr(groups), 'XTickLabelRotation', 20);
    ylabel(ylbl);
    title(ttl);
    legend({'part6', 'part6B'}, 'Location', 'best');
    saveas(fig, path_out);
    close(fig);
end

function plot_route_distribution_by_group_local(groups, obs_tbl, path_out)
    route_names = [ ...
        "level2_music_or_center_real", ...
        "level2_rank1_fallback", ...
        "common_el_refocus_power_rank1", ...
        "level3_2d_music", ...
        "pair_el_local_covfit", ...
        "boundary_unreliable", ...
        "low_confidence"];
    vals = zeros(numel(groups), numel(route_names));
    for ig = 1:numel(groups)
        mask_g = obs_tbl.group == groups(ig);
        for ir = 1:numel(route_names)
            vals(ig, ir) = mean(obs_tbl.observable_dispatch_route(mask_g) == route_names(ir), 'omitnan');
        end
    end
    fig = figure('Visible', 'off');
    bar(vals, 'stacked');
    grid on
    ylim([-0.05, 1.05]);
    set(gca, 'XTick', 1:numel(groups), 'XTickLabel', cellstr(groups), 'XTickLabelRotation', 20);
    ylabel('share of scenario-SNR rows');
    title('Calibrated observable route distribution by group');
    legend(cellstr(route_names), 'Interpreter', 'none', 'Location', 'eastoutside');
    saveas(fig, path_out);
    close(fig);
end
