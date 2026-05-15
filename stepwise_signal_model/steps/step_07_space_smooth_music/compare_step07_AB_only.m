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

subarray_num = 59;
M_full = 32;
center_beam_count = 25;
search_scale = 4;
tol_deg = 0.1;

route_names = {'Route A', 'Route B'};
route_labels = { ...
    'Route A legacy beam-index smoothing MUSIC', ...
    'Route B current new-route centerT / beamspace MUSIC'};
route_count = numel(route_names);

if center_beam_count > (M_full + 1)
    error('center_beam_count must be <= M_full + 1.');
end

if center_beam_count <= 2
    error('center_beam_count must be > Lc.');
end

j = sqrt(-1);
position_full = d * (0:array_num-1).';
position_center = d * (0:subarray_num-1).';
win_old = taylorwin(array_num, 25, -40)';
win_old = win_old / sqrt(win_old * win_old');
win_center = taylorwin(subarray_num, 25, -40)';
win_center = win_center / sqrt(win_center * win_center');

M_old = 50;
angle_recv_old_template = linspace(theta_c - bw_64 / 2, theta_c + bw_64 / 2, M_old + 1);
angle_recv_full = linspace(theta_c - bw_64 / 2, theta_c + bw_64 / 2, M_full + 1);
T_full = diag(win_center) * exp(j * 2 * pi * position_center / lambda * sin(angle_recv_full * pi / 180));
beam_start = floor((size(T_full, 2) - center_beam_count) / 2) + 1;
T_center = T_full(:, beam_start:beam_start + center_beam_count - 1);

if size(T_center, 1) ~= subarray_num
    error('T_center row count must equal subarray_num.');
end

nsnap = numel(T_snap_list);
nbw = numel(bw_index_list);
raw_success_count = zeros(nsnap, nbw, route_count);
tol_success_count = zeros(nsnap, nbw, route_count);
rmse_sum_sqerr = zeros(nsnap, nbw, route_count);
rmse_valid_count = zeros(nsnap, nbw, route_count);

log_lines = {};
log_lines = append_log(log_lines, 'compare_step07_AB_only');
log_lines = append_log(log_lines, 'Active routes:');
log_lines = append_log(log_lines, '- Route A: legacy beam-index smoothing MUSIC');
log_lines = append_log(log_lines, '- Route B: current new-route centerT / beamspace MUSIC');
log_lines = append_log(log_lines, '');
log_lines = append_log(log_lines, 'Paused routes:');
log_lines = append_log(log_lines, '- Route C: 2D pair-MUSIC backend, archived');
log_lines = append_log(log_lines, '- Route D: ESPRIT reference comparison, archived or skipped');
log_lines = append_log(log_lines, '');
log_lines = append_log(log_lines, 'This run does not modify or evaluate Route C/D.');
log_lines = append_log(log_lines, '');
log_lines = append_log(log_lines, 'Parameter summary:');
log_lines = append_log(log_lines, 'array_num=%d, subarray_num=%d, snr=%.2f, Metkl=%d', ...
    array_num, subarray_num, snr, Metkl);
log_lines = append_log(log_lines, 'T_snap_list=%s', mat2str(T_snap_list));
log_lines = append_log(log_lines, 'center_beam_count=%d, M_full=%d, search_scale=%.2f, tol_deg=%.3f', ...
    center_beam_count, M_full, search_scale, tol_deg);
log_lines = append_log(log_lines, 'bw_index_list=%s', mat2str(bw_index_list));
log_lines = append_log(log_lines, 'Frontend note: current Route B still uses mssp(Rxx, subarray_num), i.e. degraded mssp / forward-backward averaging -> centerT -> beamspace.');
log_lines = append_log(log_lines, '');

for iSnap = 1:nsnap
    T_snap = T_snap_list(iSnap);
    t = linspace(0, 1, T_snap);
    log_lines = append_log(log_lines, '=== T_snap = %d ===', T_snap);

    for ibw = 1:nbw
        angle_grid_num = bw_index_list(ibw);
        theta_a = theta_c - theta_bw(angle_grid_num) / 2;
        theta_b = theta_c + theta_bw(angle_grid_num) / 2;
        target_theta = [theta_a, theta_b];
        RecvbeamC = mean(target_theta);
        theta_search_new = search_scale * theta_bw(angle_grid_num);

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
            doa_old = DOA_three_music_hecheng_fangzhen( ...
                sr_DBF_boshu, array_num, A_old, RecvbeamC, theta_bw(angle_grid_num));

            y_sub = y(1:subarray_num, :);
            doa_center_1d = DOA_three_music_new_route_centerT( ...
                y_sub, subarray_num, T_center, RecvbeamC, theta_search_new);

            doa_all = {doa_old, doa_center_1d};
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

        log_lines = append_log(log_lines, ['bw/%d | ', ...
            'A raw=%d tol=%d RMSE=%.4f | ', ...
            'B raw=%d tol=%d RMSE=%.4f'], ...
            angle_grid_num, ...
            current_raw(1), current_tol(1), current_rmse(1), ...
            current_raw(2), current_tol(2), current_rmse(2));
    end
    log_lines = append_log(log_lines, '');
end

raw_success_rate = raw_success_count / Metkl;
tol_success_rate = tol_success_count / Metkl;
rmse = nan(nsnap, nbw, route_count);
valid_all = rmse_valid_count > 0;
rmse(valid_all) = sqrt(rmse_sum_sqerr(valid_all) ./ (2 * rmse_valid_count(valid_all)));

log_lines = append_log(log_lines, 'Summary conclusions:');
for iSnap = 1:nsnap
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
    'M_full', M_full, ...
    'center_beam_count', center_beam_count, ...
    'search_scale', search_scale, ...
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
results.log_lines = log_lines;

function log_lines = append_log(log_lines, fmt, varargin)
    line = sprintf(fmt, varargin{:});
    fprintf('%s\n', line);
    log_lines{end+1, 1} = line;
end
