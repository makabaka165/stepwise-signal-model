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

T_snap_list = [130, 260, 520];
bw_index_list = 1:10;

subarray_num = array_num;
K_fbss = 56;
M_full = 48;
center_beam_count = 37;
search_scale_A = 4;
search_scale_B = 4;
tol_deg = 0.1;

route_names = {'Route A eval', 'Route B'};
route_labels = { ...
    'Route A eval beam-index smoothing MUSIC', ...
    'Route B true array-domain FBSS / centerT beamspace MUSIC'};
route_count = numel(route_names);

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

j = sqrt(-1);
position_full = d * (0:array_num-1).';
win_old = taylorwin(array_num, 25, -40)';
win_old = win_old / sqrt(win_old * win_old');

M_old = 50;
routeA_beam_span = search_scale_A * bw_64;
angle_recv_old_template = linspace( ...
    theta_c - routeA_beam_span / 2, ...
    theta_c + routeA_beam_span / 2, ...
    M_old + 1);

nsnap = numel(T_snap_list);
nbw = numel(bw_index_list);
raw_success_count = zeros(nsnap, nbw, route_count);
tol_success_count = zeros(nsnap, nbw, route_count);
rmse_sum_sqerr = zeros(nsnap, nbw, route_count);
rmse_valid_count = zeros(nsnap, nbw, route_count);
edge_hit_count_A = zeros(nsnap, nbw);
sample_debug_B = cell(nsnap, nbw);

log_lines = {};
log_lines = append_log(log_lines, 'compare_step07_AB_only');
log_lines = append_log(log_lines, 'Active routes:');
log_lines = append_log(log_lines, '- Route A: legacy beam-index smoothing MUSIC (eval version for fair assessment)');
log_lines = append_log(log_lines, '- Route B: true array-domain FBSS -> centerT beamspace -> 1D MUSIC');
log_lines = append_log(log_lines, '');
log_lines = append_log(log_lines, 'Paused routes:');
log_lines = append_log(log_lines, '- Route C: 2D pair-MUSIC backend, archived');
log_lines = append_log(log_lines, '- Route D: ESPRIT reference comparison, archived or skipped');
log_lines = append_log(log_lines, '');
log_lines = append_log(log_lines, 'This run does not modify or evaluate Route C/D.');
log_lines = append_log(log_lines, '');
log_lines = append_log(log_lines, 'Parameter summary:');
log_lines = append_log(log_lines, 'array_num=%d, subarray_num=%d, K_fbss=%d, snr=%.2f, Metkl=%d', ...
    array_num, subarray_num, K_fbss, snr, Metkl);
log_lines = append_log(log_lines, 'T_snap_list=%s', mat2str(T_snap_list));
log_lines = append_log(log_lines, 'center_beam_count=%d, M_full=%d, search_scale_A=%.2f, search_scale_B=%.2f, tol_deg=%.3f', ...
    center_beam_count, M_full, search_scale_A, search_scale_B, tol_deg);
log_lines = append_log(log_lines, 'bw_index_list=%s', mat2str(bw_index_list));
log_lines = append_log(log_lines, 'Route B uses full array_num elements.');
log_lines = append_log(log_lines, 'K_fbss = %d.', K_fbss);
log_lines = append_log(log_lines, 'Rss = mssp_array_fb(Rxx, K_fbss).');
log_lines = append_log(log_lines, 'Psub = array_num - K_fbss + 1 = %d.', subarray_num - K_fbss + 1);
log_lines = append_log(log_lines, 'centerT/Tk is built internally from the K-dimensional subarray.');
log_lines = append_log(log_lines, 'Route B beam grid is adaptive per bw index: routeB_beam_span = 1.5 * theta_search_B.');
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
        theta_search_A = search_scale_A * theta_sep;
        theta_search_B = search_scale_B * theta_sep;
        routeB_beam_span = 1.5 * theta_search_B;
        beam_grid_full_deg = linspace( ...
            RecvbeamC - routeB_beam_span / 2, ...
            RecvbeamC + routeB_beam_span / 2, ...
            M_full + 1);

        for metkl_num = 1:Metkl
            s1 = sqrt(10^(snr / 10)) * exp(j * 2 * pi * fc * t);
            s2 = sqrt(10^(snr / 10)) * exp(j * 2 * pi * fc * t);
            A_a = exp(-j * 2 * pi * d * (0:array_num-1) * sind(theta_a) / lambda);
            A_b = exp(-j * 2 * pi * d * (0:array_num-1) * sind(theta_b) / lambda);

            s11 = A_a.' * s1;
            s21 = A_b.' * s2;
            y = s11 + s21 + (1 / sqrt(2)) * (randn(array_num, T_snap) + j * randn(array_num, T_snap));

            A_old = diag(win_old) * exp(j * 2 * pi * position_full / lambda * sin(angle_recv_old_template * pi / 180));
            sr_DBF_boshu = A_old.' * y;
            [doa_old_eval, debug_A] = DOA_three_music_hecheng_fangzhen_eval( ...
                sr_DBF_boshu, array_num, A_old, RecvbeamC, theta_search_A);

            if debug_A.edge_hit
                edge_hit_count_A(iSnap, ibw) = edge_hit_count_A(iSnap, ibw) + 1;
            end

            y_sub = y;
            [doa_center_1d, debug_B] = DOA_three_music_new_route_centerT( ...
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

            doa_all = {doa_old_eval, doa_center_1d};
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

        edge_hit_rate_A = edge_hit_count_A(iSnap, ibw) / Metkl;
        log_lines = append_log(log_lines, ['bw/%d | ', ...
            'A raw=%d tol=%d RMSE=%.4f edge_hit_rate=%.2f | ', ...
            'B raw=%d tol=%d RMSE=%.4f'], ...
            angle_grid_num, ...
            current_raw(1), current_tol(1), current_rmse(1), edge_hit_rate_A, ...
            current_raw(2), current_tol(2), current_rmse(2));
    end
    log_lines = append_log(log_lines, '');
end

raw_success_rate = raw_success_count / Metkl;
tol_success_rate = tol_success_count / Metkl;
rmse = nan(nsnap, nbw, route_count);
valid_all = rmse_valid_count > 0;
rmse(valid_all) = sqrt(rmse_sum_sqerr(valid_all) ./ (2 * rmse_valid_count(valid_all)));
edge_hit_rate_A = edge_hit_count_A / Metkl;

log_lines = append_log(log_lines, 'Summary conclusions:');
for iSnap = 1:nsnap
    log_lines = append_log(log_lines, 'Route A edge_hit_rate @ T_snap=%d = %s', ...
        T_snap_list(iSnap), mat2str(squeeze(edge_hit_rate_A(iSnap, :)), 4));
    log_lines = append_log(log_lines, 'Route B tol_success_rate @ T_snap=%d = %s', ...
        T_snap_list(iSnap), mat2str(squeeze(tol_success_rate(iSnap, :, 2)), 4));
    log_lines = append_log(log_lines, 'Route B RMSE @ T_snap=%d = %s', ...
        T_snap_list(iSnap), mat2str(squeeze(rmse(iSnap, :, 2)), 4));
end

figure(1);
for iSnap = 1:nsnap
    subplot(nsnap, 1, iSnap);
    plot(bw_index_list, squeeze(tol_success_rate(iSnap, :, 1)), '-o', 'LineWidth', 1.2);
    hold on;
    plot(bw_index_list, squeeze(tol_success_rate(iSnap, :, 2)), '-s', 'LineWidth', 1.2);
    hold off;
    grid on;
    xticks(bw_index_list);
    xlabel('bw index');
    ylabel('tol success');
    title(sprintf('A/B tol success, T_{snap} = %d', T_snap_list(iSnap)));
    legend(route_labels, 'Location', 'best');
end

figure(2);
for iSnap = 1:nsnap
    subplot(nsnap, 1, iSnap);
    plot(bw_index_list, squeeze(rmse(iSnap, :, 1)), '-o', 'LineWidth', 1.2);
    hold on;
    plot(bw_index_list, squeeze(rmse(iSnap, :, 2)), '-s', 'LineWidth', 1.2);
    hold off;
    grid on;
    xticks(bw_index_list);
    xlabel('bw index');
    ylabel('RMSE (deg)');
    title(sprintf('A/B RMSE, T_{snap} = %d', T_snap_list(iSnap)));
    legend(route_labels, 'Location', 'best');
end

figure(3);
plot(bw_index_list, squeeze(tol_success_rate(1, :, 2)), '-o', 'LineWidth', 1.2);
hold on;
plot(bw_index_list, squeeze(tol_success_rate(2, :, 2)), '-s', 'LineWidth', 1.2);
plot(bw_index_list, squeeze(tol_success_rate(3, :, 2)), '-d', 'LineWidth', 1.2);
hold off;
grid on;
xticks(bw_index_list);
xlabel('bw index');
ylabel('tol success');
title('Route B tol success snapshot comparison');
legend({'Route B T=130', 'Route B T=260', 'Route B T=520'}, 'Location', 'best');

figure(4);
plot(bw_index_list, squeeze(rmse(1, :, 2)), '-o', 'LineWidth', 1.2);
hold on;
plot(bw_index_list, squeeze(rmse(2, :, 2)), '-s', 'LineWidth', 1.2);
plot(bw_index_list, squeeze(rmse(3, :, 2)), '-d', 'LineWidth', 1.2);
hold off;
grid on;
xticks(bw_index_list);
xlabel('bw index');
ylabel('RMSE (deg)');
title('Route B RMSE snapshot comparison');
legend({'Route B T=130', 'Route B T=260', 'Route B T=520'}, 'Location', 'best');

results = struct();
results.params = struct( ...
    'c', c, ...
    'array_num', array_num, ...
    'fc', fc, ...
    'lambda', lambda, ...
    'd', d, ...
    'bw_64', bw_64, ...
    'theta_c', theta_c, ...
    'snr', snr, ...
    'Metkl', Metkl, ...
    'T_snap_list', T_snap_list, ...
    'bw_index_list', bw_index_list, ...
    'subarray_num', subarray_num, ...
    'K_fbss', K_fbss, ...
    'M_full', M_full, ...
    'center_beam_count', center_beam_count, ...
    'search_scale_A', search_scale_A, ...
    'search_scale_B', search_scale_B, ...
    'tol_deg', tol_deg);
results.theta_bw = theta_bw;
results.route_names = route_names;
results.route_labels = route_labels;
results.raw_success_rate = raw_success_rate;
results.tol_success_rate = tol_success_rate;
results.rmse = rmse;
results.raw_success_count = raw_success_count;
results.tol_success_count = tol_success_count;
results.rmse_sum_sqerr = rmse_sum_sqerr;
results.rmse_valid_count = rmse_valid_count;
results.edge_hit_rate_A = edge_hit_rate_A;
results.sample_debug_B = sample_debug_B;
results.log_lines = log_lines;

function log_lines = append_log(log_lines, fmt, varargin)
    line = sprintf(fmt, varargin{:});
    fprintf('%s\n', line);
    log_lines{end+1, 1} = line;
end
