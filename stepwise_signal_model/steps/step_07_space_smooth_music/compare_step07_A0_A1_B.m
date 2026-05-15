clc
clear
close all

c = 3e8;
array_num = 64;
fc = 2.7e9;
lambda = c / fc;
d = 0.047;

bw_64 = 50.8 * 1.45 * lambda / (array_num - 1) / d;
bw_64 = roundn(bw_64, -1);

theta_bw = [bw_64/1, bw_64/2, bw_64/3, bw_64/4, bw_64/5, ...
            bw_64/6, bw_64/7, bw_64/8, bw_64/9, bw_64/10];

theta_c = 13;
snr = 12;
Metkl = 50;
tol_deg = 0.1;
T_snap_list = [130, 260, 520];
bw_index_list = 1:10;

search_scale_A1 = 4;
search_scale_B = 4;
qSmoothRatio_A1 = 0.2;

subarray_num = array_num;
K_fbss = 56;
M_full = 48;
center_beam_count = 37;

if K_fbss >= subarray_num
    error('K_fbss must be smaller than subarray_num.');
end
if K_fbss <= 2
    error('K_fbss must be larger than Lc.');
end
if (subarray_num - K_fbss + 1) < 2
    error('subarray_num - K_fbss + 1 must be at least Lc.');
end
if center_beam_count <= 2
    error('center_beam_count must be larger than Lc.');
end
if center_beam_count > (M_full + 1)
    error('center_beam_count must be <= M_full + 1.');
end

route_names = {'A0_original', 'A1_eval_improved', 'B_true_FBSS_centerT'};
route_labels = { ...
    'A0 original Route A', ...
    'A1 eval improved Route A', ...
    'B true FBSS centerT'};
route_count = numel(route_names);

j = sqrt(-1);
position_full = d * (0:array_num-1).';
win_old = taylorwin(array_num, 25, -40)';
win_old = win_old / sqrt(win_old * win_old');

routeA0_beam_span = bw_64;
M_old_A0 = 50;
angle_recv_A0 = linspace(theta_c - routeA0_beam_span/2, ...
                         theta_c + routeA0_beam_span/2, ...
                         M_old_A0 + 1);
A0_beam_matrix = diag(win_old) * exp( ...
    j * 2*pi * position_full / lambda * sin(angle_recv_A0 * pi / 180));

routeA1_beam_span = search_scale_A1 * bw_64;
M_old_A1 = round(search_scale_A1 * 50);
angle_recv_A1 = linspace(theta_c - routeA1_beam_span/2, ...
                         theta_c + routeA1_beam_span/2, ...
                         M_old_A1 + 1);
A1_beam_matrix = diag(win_old) * exp( ...
    j * 2*pi * position_full / lambda * sin(angle_recv_A1 * pi / 180));

nsnap = numel(T_snap_list);
nbw = numel(bw_index_list);
raw_success_count = zeros(nsnap, nbw, route_count);
tol_success_count = zeros(nsnap, nbw, route_count);
rmse_sum_sqerr = zeros(nsnap, nbw, route_count);
rmse_valid_count = zeros(nsnap, nbw, route_count);
boundary_like_hit_count_A0 = zeros(nsnap, nbw);
edge_hit_count_A1 = zeros(nsnap, nbw);
sample_debug_B = cell(nsnap, nbw);

log_lines = {};
log_lines = append_log(log_lines, 'compare_step07_A0_A1_B');
log_lines = append_log(log_lines, 'A0_original:');
log_lines = append_log(log_lines, '    原始 Route A，保留旧搜索假定。');
log_lines = append_log(log_lines, '    search_width = theta_sep。');
log_lines = append_log(log_lines, '    用于复现旧结果。');
log_lines = append_log(log_lines, '    该路线带有受限搜索先验，不作为完全公平的一般搜索基线。');
log_lines = append_log(log_lines, '');
log_lines = append_log(log_lines, 'A1_eval_improved:');
log_lines = append_log(log_lines, '    搜索宽度与目标间隔解耦。');
log_lines = append_log(log_lines, '    search_width = 4 * theta_sep。');
log_lines = append_log(log_lines, '    使用 no-edge peak detection。');
log_lines = append_log(log_lines, '    beam grid 密度保持与原始 A 一致：M_old_A1 = round(search_scale_A1 * 50)。');
log_lines = append_log(log_lines, '    QSmoothRatio = %.2f。', qSmoothRatio_A1);
log_lines = append_log(log_lines, '');
log_lines = append_log(log_lines, 'B_true_FBSS_centerT:');
log_lines = append_log(log_lines, '    true array-domain FBSS -> centerT beamspace -> 1D MUSIC。');
log_lines = append_log(log_lines, '    使用 N=%d, K=%d, Psub=%d。', array_num, K_fbss, array_num - K_fbss + 1);
log_lines = append_log(log_lines, '');
log_lines = append_log(log_lines, 'Parameter summary:');
log_lines = append_log(log_lines, 'snr=%.2f, Metkl=%d, tol_deg=%.3f', snr, Metkl, tol_deg);
log_lines = append_log(log_lines, 'T_snap_list=%s', mat2str(T_snap_list));
log_lines = append_log(log_lines, 'bw_index_list=%s', mat2str(bw_index_list));
log_lines = append_log(log_lines, '');

for iSnap = 1:nsnap
    T_snap = T_snap_list(iSnap);
    t = linspace(0, 1, T_snap);
    log_lines = append_log(log_lines, '=== T_snap = %d ===', T_snap);

    for ibw = 1:nbw
        angle_grid_num = bw_index_list(ibw);
        theta_sep = theta_bw(angle_grid_num);
        theta_a = theta_c - theta_sep / 2;
        theta_b = theta_c + theta_sep / 2;
        target_theta = [theta_a, theta_b];
        RecvbeamC = mean(target_theta);

        theta_search_A0 = theta_sep;
        theta_search_A1 = search_scale_A1 * theta_sep;
        theta_search_B = search_scale_B * theta_sep;

        routeB_beam_span = 1.5 * theta_search_B;
        beam_grid_full_deg = linspace(RecvbeamC - routeB_beam_span/2, ...
                                      RecvbeamC + routeB_beam_span/2, ...
                                      M_full + 1);

        for metkl_num = 1:Metkl
            s1 = sqrt(10^(snr / 10)) * exp(j * 2 * pi * fc * t);
            s2 = sqrt(10^(snr / 10)) * exp(j * 2 * pi * fc * t);
            A_a = exp(-j * 2 * pi * d * (0:array_num-1) * sind(theta_a) / lambda);
            A_b = exp(-j * 2 * pi * d * (0:array_num-1) * sind(theta_b) / lambda);

            s11 = A_a.' * s1;
            s21 = A_b.' * s2;
            y = s11 + s21 + (1 / sqrt(2)) * (randn(array_num, T_snap) + j * randn(array_num, T_snap));

            sr_DBF_A0 = A0_beam_matrix.' * y;
            doa_A0 = DOA_three_music_hecheng_fangzhen( ...
                sr_DBF_A0, array_num, A0_beam_matrix, RecvbeamC, theta_search_A0);

            A0_left = RecvbeamC - theta_search_A0/2;
            A0_right = RecvbeamC + theta_search_A0/2;
            edge_tol = 1e-9;
            boundary_like_hit_A0 = all(isfinite(doa_A0)) && ...
                (any(abs(doa_A0 - A0_left) < edge_tol) || ...
                 any(abs(doa_A0 - A0_right) < edge_tol));
            if boundary_like_hit_A0
                boundary_like_hit_count_A0(iSnap, ibw) = boundary_like_hit_count_A0(iSnap, ibw) + 1;
            end

            sr_DBF_A1 = A1_beam_matrix.' * y;
            [doa_A1, debug_A1] = DOA_three_music_hecheng_fangzhen_eval( ...
                sr_DBF_A1, array_num, A1_beam_matrix, RecvbeamC, theta_search_A1, ...
                'Lc', 2, ...
                'QSmoothRatio', qSmoothRatio_A1);
            if debug_A1.edge_hit
                edge_hit_count_A1(iSnap, ibw) = edge_hit_count_A1(iSnap, ibw) + 1;
            end

            y_sub = y;
            [doa_B, debug_B] = DOA_three_music_new_route_centerT( ...
                y_sub, ...
                K_fbss, ...
                beam_grid_full_deg, ...
                center_beam_count, ...
                RecvbeamC, ...
                theta_search_B, ...
                'Lc', 2, ...
                'GridStepDeg', 0.01, ...
                'UseQR', true);
            if metkl_num == 1
                sample_debug_B{iSnap, ibw} = debug_B;
            end

            doa_all = {doa_A0, doa_A1, doa_B};
            for iroute = 1:route_count
                doa_est = doa_all{iroute};
                raw_ok = all(isfinite(doa_est));
                tol_ok = is_valid_doa_success(doa_est, target_theta, tol_deg);

                if raw_ok
                    raw_success_count(iSnap, ibw, iroute) = raw_success_count(iSnap, ibw, iroute) + 1;
                    sqerr = sum((sort(doa_est(:).') - sort(target_theta(:).')).^2);
                    rmse_sum_sqerr(iSnap, ibw, iroute) = rmse_sum_sqerr(iSnap, ibw, iroute) + sqerr;
                    rmse_valid_count(iSnap, ibw, iroute) = rmse_valid_count(iSnap, ibw, iroute) + 1;
                end

                if tol_ok
                    tol_success_count(iSnap, ibw, iroute) = tol_success_count(iSnap, ibw, iroute) + 1;
                end
            end
        end

        current_raw = squeeze(raw_success_count(iSnap, ibw, :)).';
        current_tol = squeeze(tol_success_count(iSnap, ibw, :)).';
        current_rmse = nan(1, route_count);
        valid_mask = squeeze(rmse_valid_count(iSnap, ibw, :)) > 0;
        current_rmse(valid_mask) = sqrt( ...
            squeeze(rmse_sum_sqerr(iSnap, ibw, valid_mask)) ./ ...
            (2 * squeeze(rmse_valid_count(iSnap, ibw, valid_mask))) );

        boundary_like_rate_A0 = boundary_like_hit_count_A0(iSnap, ibw) / Metkl;
        edge_hit_rate_A1_now = edge_hit_count_A1(iSnap, ibw) / Metkl;
        sample_num_peaks_B = sample_debug_B{iSnap, ibw}.num_peaks;

        log_lines = append_log(log_lines, ['bw/%d | ', ...
            'A0 raw=%d tol=%d RMSE=%.4f boundary_like=%.2f | ', ...
            'A1 raw=%d tol=%d RMSE=%.4f edge_hit=%.2f | ', ...
            'B raw=%d tol=%d RMSE=%.4f num_peaks_sample=%d'], ...
            angle_grid_num, ...
            current_raw(1), current_tol(1), current_rmse(1), boundary_like_rate_A0, ...
            current_raw(2), current_tol(2), current_rmse(2), edge_hit_rate_A1_now, ...
            current_raw(3), current_tol(3), current_rmse(3), sample_num_peaks_B);
    end
    log_lines = append_log(log_lines, '');
end

raw_success_rate = raw_success_count / Metkl;
tol_success_rate = tol_success_count / Metkl;
rmse = nan(nsnap, nbw, route_count);
valid_all = rmse_valid_count > 0;
rmse(valid_all) = sqrt(rmse_sum_sqerr(valid_all) ./ (2 * rmse_valid_count(valid_all)));
boundary_like_hit_rate_A0 = boundary_like_hit_count_A0 / Metkl;
edge_hit_rate_A1 = edge_hit_count_A1 / Metkl;

params = struct();
params.c = c;
params.array_num = array_num;
params.fc = fc;
params.lambda = lambda;
params.d = d;
params.bw_64 = bw_64;
params.theta_c = theta_c;
params.snr = snr;
params.Metkl = Metkl;
params.tol_deg = tol_deg;
params.T_snap_list = T_snap_list;
params.bw_index_list = bw_index_list;
params.search_scale_A1 = search_scale_A1;
params.search_scale_B = search_scale_B;
params.qSmoothRatio_A1 = qSmoothRatio_A1;
params.M_old_A0 = M_old_A0;
params.M_old_A1 = M_old_A1;
params.K_fbss = K_fbss;
params.center_beam_count = center_beam_count;
params.M_full = M_full;

result_struct = struct();
result_struct.params = params;
result_struct.route_names = route_names;
result_struct.route_labels = route_labels;
result_struct.raw_success_rate = raw_success_rate;
result_struct.tol_success_rate = tol_success_rate;
result_struct.rmse = rmse;
result_struct.boundary_like_hit_rate_A0 = boundary_like_hit_rate_A0;
result_struct.edge_hit_rate_A1 = edge_hit_rate_A1;
result_struct.sample_debug_B = sample_debug_B;
result_struct.log_lines = log_lines;

output_dir = fileparts(mfilename('fullpath'));
mat_path = fullfile(output_dir, 'compare_step07_A0_A1_B.mat');
log_path = fullfile(output_dir, 'compare_step07_A0_A1_B.log');
save(mat_path, '-struct', 'result_struct');

fid = fopen(log_path, 'w');
if fid < 0
    error('Failed to open log file.');
end
for ii = 1:numel(log_lines)
    fprintf(fid, '%s\n', log_lines{ii});
end
fclose(fid);

xvals = bw_index_list;
xlabels = arrayfun(@(k) sprintf('bw/%d', k), bw_index_list, 'UniformOutput', false);

fig1 = figure('Visible', 'off');
for iSnap = 1:nsnap
    subplot(nsnap, 1, iSnap);
    plot(xvals, squeeze(tol_success_rate(iSnap, :, 1)), '-o', 'LineWidth', 1.2);
    hold on;
    plot(xvals, squeeze(tol_success_rate(iSnap, :, 2)), '-s', 'LineWidth', 1.2);
    plot(xvals, squeeze(tol_success_rate(iSnap, :, 3)), '-d', 'LineWidth', 1.2);
    hold off;
    grid on;
    xticks(xvals);
    xticklabels(xlabels);
    ylabel('tol success');
    title(sprintf('T_{snap} = %d tol success', T_snap_list(iSnap)));
    if iSnap == 1
        legend(route_labels, 'Location', 'best');
    end
end
xlabel('bw index');
saveas(fig1, fullfile(output_dir, 'fig_A0_A1_B_tol_success.png'));
close(fig1);

fig2 = figure('Visible', 'off');
for iSnap = 1:nsnap
    subplot(nsnap, 1, iSnap);
    plot(xvals, squeeze(rmse(iSnap, :, 1)), '-o', 'LineWidth', 1.2);
    hold on;
    plot(xvals, squeeze(rmse(iSnap, :, 2)), '-s', 'LineWidth', 1.2);
    plot(xvals, squeeze(rmse(iSnap, :, 3)), '-d', 'LineWidth', 1.2);
    hold off;
    grid on;
    xticks(xvals);
    xticklabels(xlabels);
    ylabel('RMSE (deg)');
    title(sprintf('T_{snap} = %d RMSE', T_snap_list(iSnap)));
    if iSnap == 1
        legend(route_labels, 'Location', 'best');
    end
end
xlabel('bw index');
saveas(fig2, fullfile(output_dir, 'fig_A0_A1_B_rmse.png'));
close(fig2);

fig3 = figure('Visible', 'off');
for iSnap = 1:nsnap
    subplot(nsnap, 1, iSnap);
    plot(xvals, squeeze(boundary_like_hit_rate_A0(iSnap, :)), '-o', 'LineWidth', 1.2);
    hold on;
    plot(xvals, squeeze(edge_hit_rate_A1(iSnap, :)), '-s', 'LineWidth', 1.2);
    hold off;
    grid on;
    xticks(xvals);
    xticklabels(xlabels);
    ylabel('edge hit rate');
    title(sprintf('T_{snap} = %d A0 boundary-like vs A1 edge-hit', T_snap_list(iSnap)));
    if iSnap == 1
        legend({'A0 boundary-like', 'A1 edge-hit'}, 'Location', 'best');
    end
end
xlabel('bw index');
saveas(fig3, fullfile(output_dir, 'fig_A_boundary_vs_eval_edge.png'));
close(fig3);

fig4 = figure('Visible', 'off');
plot(xvals, squeeze(tol_success_rate(1, :, 3)), '-o', 'LineWidth', 1.2);
hold on;
plot(xvals, squeeze(tol_success_rate(2, :, 3)), '-s', 'LineWidth', 1.2);
plot(xvals, squeeze(tol_success_rate(3, :, 3)), '-d', 'LineWidth', 1.2);
hold off;
grid on;
xticks(xvals);
xticklabels(xlabels);
xlabel('bw index');
ylabel('tol success');
title('Route B snapshot comparison');
legend({'B T=130', 'B T=260', 'B T=520'}, 'Location', 'best');
saveas(fig4, fullfile(output_dir, 'fig_B_snapshot_compare.png'));
close(fig4);

function log_lines = append_log(log_lines, fmt, varargin)
    line = sprintf(fmt, varargin{:});
    fprintf('%s\n', line);
    log_lines{end+1, 1} = line;
end
