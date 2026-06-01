% Final shared-center enhanced DOA demo.
% This script is the Step 09 runnable entry for thesis/report artifacts.

clc
clear
close all

script_dir = fileparts(mfilename('fullpath'));
if isempty(script_dir)
    script_dir = pwd;
end
addpath(fullfile(script_dir, 'main'));

result_dir = fullfile(script_dir, 'results');
if ~exist(result_dir, 'dir')
    mkdir(result_dir);
end

cfg = make_demo_cfg_local();
array_geom = make_demo_array_geom_local(cfg);
scenarios = make_demo_scenarios_local();

rows = cell(numel(scenarios), 1);
for i = 1:numel(scenarios)
    sc = scenarios(i);
    raw_cube = synthesize_raw_cube_local(array_geom, sc, cfg);
    out = shared_center_enhanced_doa(sc.frontend_out, raw_cube, array_geom, sc.cfg);
    rows{i} = make_summary_row_local(sc, out);
end

summary_tbl = struct2table([rows{:}]);
writetable(summary_tbl, fullfile(result_dir, 'final_summary.csv'));

keypoints_tbl = make_final_keypoints_table_local();
writetable(keypoints_tbl, fullfile(result_dir, 'final_keypoints.csv'));

plot_route_flowchart_local(fullfile(result_dir, 'final_route_flowchart.png'));
plot_frontend_interface_local(fullfile(result_dir, 'final_frontend_interface.png'));
plot_scenario_examples_local(summary_tbl, fullfile(result_dir, 'final_scenario_examples.png'));

disp('Final shared-center demo finished.');
disp(summary_tbl(:, {'scenario', 'frontend_state', 'route_name', 'status', 'confidence'}));
fprintf('Results written to: %s\n', result_dir);

function cfg = make_demo_cfg_local()
    cfg = struct();
    cfg.lambda = 1;
    cfg.Naz = 192;
    cfg.Nel = 32;
    cfg.radius = 14;
    cfg.dz = 0.45;
    cfg.Np = 12;
    cfg.Q_work_columns = 65;
    cfg.num_sources = 2;
    cfg.derotation_mode = 'none';
    cfg.az_grid_half_span_deg = 1.4;
    cfg.az_grid_step_deg = 0.04;
    cfg.el_grid_half_span_deg = 7;
    cfg.el_grid_step_deg = 0.5;
    cfg.min_pair_sep_deg = 0.15;
    cfg.max_pair_sep_deg = 1.1;
    cfg.music_peak2_ratio_min = 0.35;
    cfg.music_2d_peak2_ratio_min = 0.20;
    cfg.coherent_min_projection_score = 0.65;
    cfg.coherent_min_score_margin = 0;
end

function array_geom = make_demo_array_geom_local(cfg)
    phiCol = (0:cfg.Naz - 1) / cfg.Naz * 360;
    zRow = (0:cfg.Nel - 1) * cfg.dz;
    X = zeros(cfg.Naz, cfg.Nel);
    Y = zeros(cfg.Naz, cfg.Nel);
    Z = zeros(cfg.Naz, cfg.Nel);
    for k = 1:cfg.Naz
        X(k, :) = cfg.radius * cosd(phiCol(k));
        Y(k, :) = cfg.radius * sind(phiCol(k));
        Z(k, :) = zRow;
    end
    array_geom = struct('phiCol', phiCol, 'X', X, 'Y', Y, 'Z', Z, ...
        'lambda', cfg.lambda, 'Naz', cfg.Naz, 'Nel', cfg.Nel);
end

function scenarios = make_demo_scenarios_local()
    base_cfg = make_demo_cfg_local();
    scenarios = repmat(struct(), 4, 1);

    scenarios(1).scenario = 'close_coherent_unresolved_cluster';
    scenarios(1).az = [-0.25, 0.25];
    scenarios(1).el = [0, 0];
    scenarios(1).amp = [1, 0.95];
    scenarios(1).coherent = true;
    scenarios(1).frontend_out = make_frontend_local('single_peak_in_scope', 0, 0, true, false, false);
    scenarios(1).cfg = base_cfg;

    scenarios(2).scenario = 'large_elevation_pair';
    scenarios(2).az = [-0.28, 0.28];
    scenarios(2).el = [0, 5];
    scenarios(2).amp = [1, 0.9];
    scenarios(2).coherent = false;
    scenarios(2).frontend_out = make_frontend_local('single_peak_in_scope', 0, 2.5, true, true, false);
    scenarios(2).cfg = base_cfg;

    scenarios(3).scenario = 'near_antiphase_boundary';
    scenarios(3).az = [-0.18, 0.18];
    scenarios(3).el = [0, 0];
    scenarios(3).amp = [1, 1];
    scenarios(3).coherent = true;
    scenarios(3).frontend_out = make_frontend_local('single_peak_in_scope', 0, 0, true, false, true);
    scenarios(3).cfg = base_cfg;

    scenarios(4).scenario = 'two_separated_coarse_peaks';
    scenarios(4).az = [-2.0, 2.0];
    scenarios(4).el = [0, 0];
    scenarios(4).amp = [1, 1];
    scenarios(4).coherent = false;
    scenarios(4).frontend_out = make_frontend_local('two_separated_peaks_out_of_scope', 0, 0, false, false, false);
    scenarios(4).cfg = base_cfg;
end

function frontend_out = make_frontend_local(state, coarseAz, coarseEl, unresolved, need2d, boundary)
    frontend_out = struct();
    frontend_out.rangeIdx = 1;
    frontend_out.dopplerIdx = 1;
    frontend_out.coarseAz = coarseAz;
    frontend_out.coarseEl = coarseEl;
    frontend_out.frontend_state = state;
    frontend_out.unresolved_cluster_flag = unresolved;
    frontend_out.need_2d_refinement = need2d;
    frontend_out.boundary_unreliable_flag = boundary;
end

function raw_cube = synthesize_raw_cube_local(array_geom, sc, cfg)
    raw_cube = zeros(cfg.Naz, cfg.Nel, cfg.Np);
    n = 0:cfg.Np - 1;
    if sc.coherent
        sig = exp(1j * 2 * pi * 0.07 * n);
        sigs = [sig; sig .* exp(1j * pi / 5)];
    else
        sigs = [exp(1j * 2 * pi * 0.07 * n); exp(1j * 2 * pi * 0.19 * n)];
    end
    for k = 1:numel(sc.az)
        a = steering_full_local(array_geom, sc.az(k), sc.el(k));
        for ip = 1:cfg.Np
            raw_cube(:, :, ip) = raw_cube(:, :, ip) + sc.amp(k) * a * sigs(k, ip);
        end
    end
    raw_cube = raw_cube + 0.01 * (randn(size(raw_cube)) + 1j * randn(size(raw_cube)));
end

function a = steering_full_local(array_geom, az_deg, el_deg)
    kx = cosd(el_deg) * cosd(az_deg);
    ky = cosd(el_deg) * sind(az_deg);
    kz = sind(el_deg);
    phase = 2 * pi / array_geom.lambda * (array_geom.X * kx + array_geom.Y * ky + array_geom.Z * kz);
    a = exp(1j * phase);
end

function row = make_summary_row_local(sc, out)
    row = struct();
    row.scenario = string(sc.scenario);
    row.frontend_state = string(out.frontend_state);
    row.route_name = string(out.route_name);
    row.status = string(out.status);
    row.confidence = string(out.confidence);
    row.az_est = string(mat2str(out.az_est, 4));
    row.el_est = string(mat2str(out.el_est, 4));
    row.selectedCenterColumn = getfield_default_local(out, 'selectedCenterColumn', NaN);
    row.Y_work_shape = string(mat2str(getfield_default_local(out, 'Y_work_shape', [])));
    row.reject_reason = string(getfield_default_local(out, 'reject_reason', ''));
end

function T = make_final_keypoints_table_local()
    T = table( ...
        "shared-center MUSIC enhanced DOA", ...
        "single_peak_in_scope / unresolved local cluster", ...
        65, "65 x 32 x Np", "none", ...
        0.764705882352941, 0, 0, 0.376998770503756, ...
        1, 0.916666666666667, 0.916666666666667, 0, 0, ...
        0, "quantization_not_closed", ...
        0, "unified_model_selection_not_safe", ...
        "keep pruned shared-center cascade; archive unified/fixed-point/dual-center as negative or future work", ...
        'VariableNames', {'final_route_name', 'frontend_scope', 'Q_work_columns', ...
        'Y_work_shape', 'default_derotation_mode', ...
        'step87_lazy_success_rate_all', 'step87_false_high_rate_all', ...
        'step87_boundary_missed_rate_all', 'step87_mean_runtime_reduction_all', ...
        'step88_cfar_detection_rate_overall', 'step88_single_coarse_peak_rate_overall', ...
        'step88_in_scope_shared_center_rate', 'step88_false_high_rate_in_scope', ...
        'step88_boundary_missed_rate_in_scope', 'step89_fixed_point_pass_flag', ...
        'step89_blocker', 'step810_adopt_unified_model_selection_flag', ...
        'step810_blocker', 'final_recommendation'});
end

function plot_route_flowchart_local(path_out)
    fig = figure('Visible', 'off', 'Color', 'w', 'Position', [80, 80, 1300, 480]);
    axis off
    labels = {{'frontend detection', 'coarse angle'}, {'shared-center', '65 columns'}, ...
        {'Y\_work', '65 x 32 x Np'}, {'local cylindrical', 'MUSIC'}, ...
        {'rank1 refocus', 'fallback'}, {'local 2-D', 'refinement'}, ...
        {'low confidence', 'boundary reject'}};
    x = linspace(0.035, 0.845, numel(labels));
    w = 0.11;
    for i = 1:numel(labels)
        rectangle('Position', [x(i), 0.46, w, 0.22], 'LineWidth', 1.2);
        text(x(i) + w / 2, 0.57, labels{i}, 'HorizontalAlignment', 'center', ...
            'VerticalAlignment', 'middle', 'Interpreter', 'tex', 'FontSize', 9);
        if i < numel(labels)
            annotation('arrow', [x(i) + w, x(i + 1)], [0.57, 0.57]);
        end
    end
    title('Final shared-center MUSIC enhanced DOA route');
    saveas(fig, path_out);
    close(fig);
end

function plot_frontend_interface_local(path_out)
    fig = figure('Visible', 'off', 'Color', 'w', 'Position', [80, 80, 900, 480]);
    names = categorical({'rangeIdx', 'dopplerIdx', 'coarseAz', 'coarseEl', 'frontend\_state', 'Y\_work'});
    bar(names, ones(1, numel(names)));
    ylim([0, 1.25]);
    ylabel('field present');
    title('Frontend interface into shared-center route');
    grid on
    saveas(fig, path_out);
    close(fig);
end

function plot_scenario_examples_local(summary_tbl, path_out)
    fig = figure('Visible', 'off', 'Color', 'w', 'Position', [80, 80, 1000, 520]);
    routes = categorical(summary_tbl.route_name);
    route_names = categories(routes);
    route_counts = countcats(routes);
    bar(categorical(route_names), route_counts);
    ylabel('demo count');
    title('Scenario outputs in final Step 09 demo');
    grid on
    saveas(fig, path_out);
    close(fig);
end

function value = getfield_default_local(s, name, default_value)
    if isstruct(s) && isfield(s, name) && ~isempty(s.(name))
        value = s.(name);
    else
        value = default_value;
    end
end
