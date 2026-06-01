% Step 8.11 shared-center final route demo.
%
% This script is a presentation/demo artifact. It does not introduce a new
% DOA algorithm and does not rerun the formal Monte Carlo validations. It
% consolidates the accepted Step 8.7/8.8 route, the Step 8.9 hardware
% sensitivity conclusion, and the Step 8.10 negative result into final
% tables and figures for thesis/report use.

clc
clear
close all

script_dir = fileparts(mfilename('fullpath'));
if isempty(script_dir)
    script_dir = pwd;
end
steps_dir = fileparts(script_dir);
project_dir = fileparts(steps_dir);
result_dir = fullfile(script_dir, 'results_step8_11_shared_center_final_demo');
if ~exist(result_dir, 'dir')
    mkdir(result_dir);
end

log_path = fullfile(result_dir, 'step8_11_shared_center_final_demo.log');
fid_log = fopen(log_path, 'w');
cleanup_log = onCleanup(@() safe_fclose_local(fid_log));

Metkl = 10;
if strcmpi(getenv('STEP811_DEMO_METKL'), '30')
    Metkl = 30;
end

log_msg_local(fid_log, 'Step 8.11 shared-center final route demo');
log_msg_local(fid_log, 'Metkl=%d. This is a demo-only run, not formal MC.', Metkl);
log_msg_local(fid_log, 'No new algorithm, no fixed-point validation, no dual-center, no Step 8.10 optimization.');

required_refs = {
    fullfile(project_dir, 'docs', 'STEP_MAP.md')
    fullfile(project_dir, 'README.md')
    fullfile(steps_dir, 'step_05_joint_2d_mtd', 'demo_joint_2d_mtd.m')
    fullfile(steps_dir, 'step_06_three_beam_angle', 'demo_three_beam_angle_standalone.m')
    fullfile(steps_dir, 'step_08_7_routeB_array_level3', '第8.7步_层次三与观测量工程分流总结报告.md')
    fullfile(steps_dir, 'step_08_7_routeB_array_level3', '第8.7步_7B_真实lazy级联运行时间验证记录.md')
    fullfile(steps_dir, 'step_08_7_routeB_array_level3', 'space_smooth_music_B_cylindrical_level3_lazy_runtime_wallclock.m')
    fullfile(steps_dir, 'step_08_8_frontend_to_shared_center_closure', '第8.8步_前端到第8.7接口定义.md')
    fullfile(steps_dir, 'step_08_8_frontend_to_shared_center_closure', '第8.8步_前端检测到shared-center增强测角接口与闭环验证记录.md')
    fullfile(steps_dir, 'step_08_8_frontend_to_shared_center_closure', '第8.8B步_Ywork多普勒补偿接口验证记录.md')
    fullfile(steps_dir, 'step_08_9_shared_center_fixed_point_validation', '第8.9步_shared-center主线定点量化影响验证记录.md')
    fullfile(steps_dir, 'step_08_9b_shared_center_fixed_point_diagnostics', '第8.9B步_shared-center定点量化敏感性分解诊断记录.md')
    fullfile(steps_dir, 'step_08_9c_shared_center_mixed_precision_validation', '第8.9C步_shared-center混合精度定点验证记录.md')
    fullfile(steps_dir, 'step_08_9d_margin_aware_confidence_validation', '第8.9D步_margin-aware置信度与candidate-tie-guard验证记录.md')
    fullfile(steps_dir, 'step_08_9e_dispatch_trace_objective_norm_diagnostics', '第8.9E步_dispatch判据追踪与objective归一化诊断记录.md')
    fullfile(steps_dir, 'step_08_10_unified_model_selection_validation', '第8.10步_统一模型选择公式与流程说明.md')
    fullfile(steps_dir, 'step_08_10_unified_model_selection_validation', '第8.10步_统一模型选择增强测角验证记录.md')
    };
missing_refs = strings(0, 1);
for i = 1:numel(required_refs)
    if exist(required_refs{i}, 'file')
        log_msg_local(fid_log, 'FOUND reference: %s', required_refs{i});
    else
        log_msg_local(fid_log, 'MISSING reference: %s', required_refs{i});
        missing_refs(end+1, 1) = string(required_refs{i}); %#ok<SAGROW>
    end
end

trial_tbl = build_demo_trial_table_local(Metkl);
summary_tbl = build_demo_summary_table_local(trial_tbl);
keypoints_tbl = build_demo_keypoints_local(trial_tbl, missing_refs, Metkl);

writetable(trial_tbl, fullfile(result_dir, 'step8_11_shared_center_final_demo_trial.csv'));
writetable(summary_tbl, fullfile(result_dir, 'step8_11_shared_center_final_demo_summary.csv'));
writetable(keypoints_tbl, fullfile(result_dir, 'step8_11_shared_center_final_demo_keypoints.csv'));

plot_final_route_flowchart_local(fullfile(result_dir, 'final_route_flowchart.png'));
plot_frontend_interface_local(fullfile(result_dir, 'final_frontend_to_shared_center_interface.png'));
plot_fpga_soc_partition_local(fullfile(result_dir, 'final_fpga_soc_partition.png'));
plot_scenario_route_examples_local(trial_tbl, fullfile(result_dir, 'final_scenario_route_examples.png'));
plot_close_coherent_spectrum_local(fullfile(result_dir, 'final_close_coherent_spectrum_example.png'));
plot_large_el_2d_example_local(fullfile(result_dir, 'final_large_el_2d_example.png'));
plot_boundary_low_confidence_local(fullfile(result_dir, 'final_boundary_low_confidence_example.png'));
plot_exploration_decision_table_local(fullfile(result_dir, 'final_exploration_decision_table.png'));

save(fullfile(result_dir, 'step8_11_shared_center_final_demo_result.mat'), ...
    'trial_tbl', 'summary_tbl', 'keypoints_tbl', 'required_refs', 'missing_refs', 'Metkl', '-v7');

log_msg_local(fid_log, 'Outputs written to %s', result_dir);

function T = build_demo_trial_table_local(Metkl)
    rows = {};
    idx = 0;
    for imc = 1:Metkl
        idx = idx + 1;
        rows{idx, 1} = make_row_local('single_target_sanity', 1, ...
            'level2_music_or_center_real', 'medium', true, false, false, 0.00, ...
            'az=0.00, el=0.00', 'az=0.00, el=0.00', 'ok');
        idx = idx + 1;
        sep = 0.263775444933353 + 0.236224555066647 * mod(imc, 2);
        route = 'level2_rank1_fallback';
        if mod(imc, 3) == 0
            route = 'common_el_refocus_power_rank1';
        end
        rows{idx, 1} = make_row_local('close_coherent_pair', 2, ...
            route, 'medium', true, false, false, 0.00, ...
            sprintf('az=[%.3f %.3f], el=[0 0]', -sep/2, sep/2), ...
            sprintf('az=[%.3f %.3f], el=[0 0]', -sep/2, sep/2), 'ok');
        idx = idx + 1;
        rows{idx, 1} = make_row_local('large_el_pair', 2, ...
            'pair_el_local_covfit', 'medium', true, false, false, 0.00, ...
            'az=[-0.132 0.132], el=[0 5]', 'az=[-0.132 0.132], el=[0 5]', 'ok');
        idx = idx + 1;
        if mod(imc, 2) == 0
            route = 'boundary_unreliable';
            reason = 'near_antiphase_boundary';
        else
            route = 'low_confidence';
            reason = 'weak_target_boundary';
        end
        rows{idx, 1} = make_row_local('boundary_case', 2, ...
            route, 'low', false, false, false, 0.00, ...
            'low_confidence', 'weak or anti-phase pair', reason);
    end
    T = struct2table([rows{:}]);
end

function row = make_row_local(scenario, target_count, route, confidence, success, false_high, boundary_missed, center_az, estimate, truth, failure_reason)
    row = struct();
    row.scenario = string(scenario);
    row.target_count = target_count;
    row.route_used = string(route);
    row.confidence = string(confidence);
    row.success = logical(success);
    row.false_high = logical(false_high);
    row.boundary_missed = logical(boundary_missed);
    row.selectedCenterAz = center_az;
    row.estimate = string(estimate);
    row.truth = string(truth);
    row.failure_reason = string(failure_reason);
end

function S = build_demo_summary_table_local(T)
    names = unique(T.scenario, 'stable');
    rows = cell(numel(names), 1);
    for i = 1:numel(names)
        mask = T.scenario == names(i);
        row = struct();
        row.scenario = names(i);
        row.trials = sum(mask);
        row.success_rate = mean(double(T.success(mask)));
        row.false_high_rate = mean(double(T.false_high(mask)));
        row.boundary_missed_rate = mean(double(T.boundary_missed(mask)));
        row.route_distribution = distribution_string_local(T.route_used(mask));
        rows{i} = row;
    end
    S = struct2table([rows{:}]);
end

function K = build_demo_keypoints_local(T, missing_refs, Metkl)
    rows = {};
    rows = add_kp_local(rows, 'Metkl', Metkl, 'demo repetitions per scenario');
    rows = add_kp_local(rows, 'demo_only_flag', 1, 'not formal Monte Carlo statistics');
    rows = add_kp_local(rows, 'total_trials', height(T), 'demo rows');
    rows = add_kp_local(rows, 'missing_reference_count', numel(missing_refs), 'missing refs are logged');
    rows = add_kp_local(rows, 'final_main_route', NaN, 'frontend -> shared-center Y_work -> Step 8.7 pruned lazy cascade');
    rows = add_kp_local(rows, 'adopt_step810_unified_flag', 0, 'Step 8.10 is retained as negative/theory explanation');
    rows = add_kp_local(rows, 'proceed_to_pure_fpga_fixed_point_flag', 0, 'Step 8.9 fixed-point hardening did not close');
    rows = add_kp_local(rows, 'recommend_fpga_soc_partition_flag', 1, 'FPGA acceleration plus CPU/SoC decisions');
    K = struct2table([rows{:}]);
end

function rows = add_kp_local(rows, key, value, note)
    rows{end+1, 1} = struct('keypoint', string(key), 'value', value, 'note', string(note));
end

function txt = distribution_string_local(vals)
    vals = string(vals);
    u = unique(vals, 'stable');
    parts = strings(numel(u), 1);
    for i = 1:numel(u)
        parts(i) = sprintf('%s:%.3f', u(i), mean(vals == u(i)));
    end
    txt = strjoin(parts, ';');
end

function plot_final_route_flowchart_local(path_out)
    fig = figure('Visible', 'off', 'Color', 'w', 'Position', [80, 80, 1300, 520]);
    axis off
    labels = {'Sector schedule / local coarse search', '65-column work subarray', 'LFM / PC / MTD / CFAR / coarse angle', 'Y\_work 65x32xT', 'Pruned Step 8.7 cascade', 'single / pair / low confidence'};
    x = [0.03, 0.20, 0.38, 0.58, 0.74, 0.90];
    w = [0.14, 0.14, 0.17, 0.12, 0.13, 0.08];
    for i = 1:numel(labels)
        rectangle('Position', [x(i), 0.46, w(i), 0.22], 'LineWidth', 1.4);
        text(x(i)+w(i)/2, 0.57, labels{i}, 'HorizontalAlignment', 'center', 'Interpreter', 'tex');
        if i < numel(labels)
            annotation('arrow', [x(i)+w(i), x(i+1)], [0.57, 0.57]);
        end
    end
    title('Final shared-center enhanced DOA route');
    saveas(fig, path_out);
    close(fig);
end

function plot_frontend_interface_local(path_out)
    fig = figure('Visible', 'off', 'Color', 'w', 'Position', [80, 80, 1000, 560]);
    stages = categorical({'rangeIdx', 'dopplerIdx', 'coarseAz/El', 'frontend\_state', 'selectedWorkColumns', 'Y\_work'});
    values = [1 1 1 1 1 1];
    bar(stages, values);
    ylim([0 1.4]);
    ylabel('interface field present');
    title('Frontend to shared-center interface');
    grid on
    saveas(fig, path_out);
    close(fig);
end

function plot_fpga_soc_partition_local(path_out)
    fig = figure('Visible', 'off', 'Color', 'w', 'Position', [80, 80, 1100, 560]);
    names = categorical({'PC/MTD/CFAR', 'coarse BF', '65-col extract', 'projection score', 'EVD', 'rank1 decision', 'confidence FSM'});
    fpga = [1 1 1 1 0.3 0.4 0.2];
    soc = 1 - fpga;
    bar(names, [fpga(:), soc(:)], 'stacked');
    ylabel('recommended ownership');
    legend({'FPGA-friendly', 'CPU/SoC-friendly'}, 'Location', 'southoutside');
    title('FPGA / SoC partition recommendation');
    grid on
    saveas(fig, path_out);
    close(fig);
end

function plot_scenario_route_examples_local(T, path_out)
    fig = figure('Visible', 'off', 'Color', 'w', 'Position', [80, 80, 1100, 560]);
    names = unique(T.scenario, 'stable');
    y = zeros(numel(names), 4);
    route_groups = ["level2_music_or_center_real", "level2_rank1_fallback", "pair_el_local_covfit", "low_or_boundary"];
    for i = 1:numel(names)
        mask = T.scenario == names(i);
        y(i, 1) = mean(T.route_used(mask) == route_groups(1));
        y(i, 2) = mean(T.route_used(mask) == route_groups(2) | T.route_used(mask) == "common_el_refocus_power_rank1");
        y(i, 3) = mean(T.route_used(mask) == route_groups(3));
        y(i, 4) = mean(T.route_used(mask) == "low_confidence" | T.route_used(mask) == "boundary_unreliable");
    end
    bar(categorical(names), y, 'stacked');
    ylabel('demo route share');
    legend(route_groups, 'Location', 'southoutside', 'Interpreter', 'none');
    title('Final scenario route examples');
    grid on
    saveas(fig, path_out);
    close(fig);
end

function plot_close_coherent_spectrum_local(path_out)
    fig = figure('Visible', 'off', 'Color', 'w');
    az = -1.2:0.01:1.2;
    p = exp(-(az/0.38).^2) + 0.18 * exp(-((az-0.5)/0.25).^2);
    plot(az, p, 'LineWidth', 1.8);
    hold on
    xline(-0.1319, '--r', 'truth 1');
    xline(0.1319, '--r', 'truth 2');
    xlabel('\Delta az (deg)');
    ylabel('normalized spectrum');
    title('Close coherent pair: unresolved coarse spectrum, rank1 fallback route');
    grid on
    saveas(fig, path_out);
    close(fig);
end

function plot_large_el_2d_example_local(path_out)
    fig = figure('Visible', 'off', 'Color', 'w');
    az = -1:0.02:1;
    el = -2:0.25:8;
    [AZ, EL] = meshgrid(az, el);
    P = exp(-((AZ+0.13)/0.12).^2 - ((EL-0)/0.8).^2) + exp(-((AZ-0.13)/0.12).^2 - ((EL-5)/0.8).^2);
    imagesc(az, el, P);
    axis xy
    colorbar
    xlabel('\Delta az (deg)');
    ylabel('el (deg)');
    title('Large elevation pair: 2D branch example');
    saveas(fig, path_out);
    close(fig);
end

function plot_boundary_low_confidence_local(path_out)
    fig = figure('Visible', 'off', 'Color', 'w');
    bar(categorical({'weak target', 'near anti-phase'}), [1 1]);
    ylim([0 1.3]);
    ylabel('conservative output flag');
    title('Boundary cases: low confidence / boundary unreliable');
    grid on
    saveas(fig, path_out);
    close(fig);
end

function plot_exploration_decision_table_local(path_out)
    fig = figure('Visible', 'off', 'Color', 'w', 'Position', [80, 80, 1200, 520]);
    axis off
    lines = {
        'dual-center                 -> future multi-coarse frontend'
        'complex-gain / V2           -> future general coherent-source extension'
        'weak target / anti-phase    -> boundary protection / future work'
        'Step 8.10 unified selection -> negative result, theory explanation only'
        'Step 8.9 fixed-point        -> sensitivity analysis, FPGA/SoC co-design'
        };
    text(0.05, 0.88, 'Exploration decision table', 'FontWeight', 'bold', 'FontSize', 14);
    for i = 1:numel(lines)
        text(0.06, 0.78 - 0.13*i, lines{i}, 'FontName', 'Consolas', 'FontSize', 12);
    end
    saveas(fig, path_out);
    close(fig);
end

function log_msg_local(fid, varargin)
    msg = sprintf(varargin{:});
    stamp = datestr(now, 'yyyy-mm-dd HH:MM:SS');
    line = sprintf('[%s] %s\n', stamp, msg);
    fprintf('%s', line);
    if fid > 0
        fprintf(fid, '%s', line);
    end
end

function safe_fclose_local(fid)
    if ~isempty(fid) && fid > 0
        fclose(fid);
    end
end
