clc
clear
close all

rng(20260515, 'twister');

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
qSmoothRatio_A1 = 0.2;

j = sqrt(-1);
position_full = d * (0:array_num-1).';
win_old = taylorwin(array_num, 25, -40)';
win_old = win_old / sqrt(win_old * win_old');

routeA1_beam_span = search_scale_A1 * bw_64;
M_old_A1 = round(search_scale_A1 * 50);
angle_recv_A1 = linspace(theta_c - routeA1_beam_span / 2, ...
                         theta_c + routeA1_beam_span / 2, ...
                         M_old_A1 + 1);
A1_beam_matrix = diag(win_old) * exp( ...
    j * 2 * pi * position_full / lambda * sin(angle_recv_A1 * pi / 180));

nsnap = numel(T_snap_list);
nbw = numel(bw_index_list);
raw_success_count = zeros(nsnap, nbw);
tol_success_count = zeros(nsnap, nbw);
rmse_sum_sqerr = zeros(nsnap, nbw);
rmse_valid_count = zeros(nsnap, nbw);
edge_hit_count = zeros(nsnap, nbw);

log_lines = {};
log_lines = append_log(log_lines, 'Step 07 Route A1');
log_lines = append_log(log_lines, 'Common experiment settings:');
log_lines = append_log(log_lines, 'snr=%.2f, Metkl=%d, tol_deg=%.3f', snr, Metkl, tol_deg);
log_lines = append_log(log_lines, 'T_snap_list=%s', mat2str(T_snap_list));
log_lines = append_log(log_lines, 'bw_index_list=%s', mat2str(bw_index_list));
log_lines = append_log(log_lines, 'Route A1 internal settings:');
log_lines = append_log(log_lines, 'search_scale_A1=%.2f, QSmoothRatio_A1=%.2f, M_old_A1=%d', ...
    search_scale_A1, qSmoothRatio_A1, M_old_A1);
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
        theta_search_A1 = search_scale_A1 * theta_sep;

        for metkl_num = 1:Metkl
            s1 = sqrt(10^(snr / 10)) * exp(j * 2 * pi * fc * t);
            s2 = sqrt(10^(snr / 10)) * exp(j * 2 * pi * fc * t);
            A_a = exp(-j * 2 * pi * d * (0:array_num-1) * sind(theta_a) / lambda);
            A_b = exp(-j * 2 * pi * d * (0:array_num-1) * sind(theta_b) / lambda);

            s11 = A_a.' * s1;
            s21 = A_b.' * s2;
            y = s11 + s21 + (1 / sqrt(2)) * (randn(array_num, T_snap) + ...
                j * randn(array_num, T_snap));

            sr_DBF_A1 = A1_beam_matrix.' * y;
            [doa_A1, edge_hit_flag] = DOA_three_music_hecheng_fangzhen_eval( ...
                sr_DBF_A1, array_num, A1_beam_matrix, RecvbeamC, theta_search_A1, qSmoothRatio_A1);

            if edge_hit_flag
                edge_hit_count(iSnap, ibw) = edge_hit_count(iSnap, ibw) + 1;
            end

            raw_ok = all(isfinite(doa_A1));
            tol_ok = is_valid_doa_success(doa_A1, target_theta, tol_deg);

            if raw_ok
                raw_success_count(iSnap, ibw) = raw_success_count(iSnap, ibw) + 1;
                sqerr = sum((sort(doa_A1(:).') - sort(target_theta(:).')).^2);
                rmse_sum_sqerr(iSnap, ibw) = rmse_sum_sqerr(iSnap, ibw) + sqerr;
                rmse_valid_count(iSnap, ibw) = rmse_valid_count(iSnap, ibw) + 1;
            end

            if tol_ok
                tol_success_count(iSnap, ibw) = tol_success_count(iSnap, ibw) + 1;
            end
        end

        current_rmse = NaN;
        if rmse_valid_count(iSnap, ibw) > 0
            current_rmse = sqrt(rmse_sum_sqerr(iSnap, ibw) / (2 * rmse_valid_count(iSnap, ibw)));
        end

        edge_hit_rate = edge_hit_count(iSnap, ibw) / Metkl;
        log_lines = append_log(log_lines, ...
            'bw/%d | raw=%d tol=%d RMSE=%.4f edge_hit=%.2f', ...
            angle_grid_num, raw_success_count(iSnap, ibw), ...
            tol_success_count(iSnap, ibw), current_rmse, edge_hit_rate);
    end
    log_lines = append_log(log_lines, '');
end

raw_success_rate = raw_success_count / Metkl;
tol_success_rate = tol_success_count / Metkl;
rmse = nan(nsnap, nbw);
valid_mask = rmse_valid_count > 0;
rmse(valid_mask) = sqrt(rmse_sum_sqerr(valid_mask) ./ (2 * rmse_valid_count(valid_mask)));
edge_hit_rate = edge_hit_count / Metkl;

output_dir = fileparts(mfilename('fullpath'));
fid = fopen(fullfile(output_dir, [mfilename, '.log']), 'w');
if fid < 0
    error('Failed to open log file.');
end
for ii = 1:numel(log_lines)
    fprintf(fid, '%s\n', log_lines{ii});
end
fclose(fid);

xvals = bw_index_list;
xlabels = arrayfun(@(k) sprintf('bw/%d', k), bw_index_list, 'UniformOutput', false);

figure('Name', 'Route A1 tol success rate', 'NumberTitle', 'off');
for iSnap = 1:nsnap
    subplot(nsnap, 1, iSnap);
    plot(xvals, squeeze(tol_success_rate(iSnap, :)), '-o', 'LineWidth', 1.2);
    grid on;
    xticks(xvals);
    xticklabels(xlabels);
    ylabel('tol success');
    title(sprintf('Route A1 tol success rate, T_{snap} = %d', T_snap_list(iSnap)));
end
xlabel('target separation');

figure('Name', 'Route A1 RMSE', 'NumberTitle', 'off');
for iSnap = 1:nsnap
    subplot(nsnap, 1, iSnap);
    plot(xvals, squeeze(rmse(iSnap, :)), '-o', 'LineWidth', 1.2);
    grid on;
    xticks(xvals);
    xticklabels(xlabels);
    ylabel('RMSE (deg)');
    title(sprintf('Route A1 RMSE, T_{snap} = %d', T_snap_list(iSnap)));
end
xlabel('target separation');

figure('Name', 'Route A1 raw success and edge hit', 'NumberTitle', 'off');
for iSnap = 1:nsnap
    subplot(nsnap, 1, iSnap);
    plot(xvals, squeeze(raw_success_rate(iSnap, :)), '-o', 'LineWidth', 1.2);
    hold on;
    plot(xvals, squeeze(edge_hit_rate(iSnap, :)), '-s', 'LineWidth', 1.2);
    hold off;
    grid on;
    xticks(xvals);
    xticklabels(xlabels);
    ylabel('rate');
    title(sprintf('Route A1 raw success / edge hit, T_{snap} = %d', T_snap_list(iSnap)));
    legend({'raw success', 'edge hit'}, 'Location', 'best');
end
xlabel('target separation');

function log_lines = append_log(log_lines, fmt, varargin)
line = sprintf(fmt, varargin{:});
fprintf('%s\n', line);
log_lines{end+1, 1} = line;
end
