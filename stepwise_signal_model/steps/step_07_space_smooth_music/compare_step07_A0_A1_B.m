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
    error('K_fbss 必须小于 subarray_num。');
end
if K_fbss <= 2
    error('K_fbss 必须大于目标数 Lc。');
end
if (subarray_num - K_fbss + 1) < 2
    error('重叠子阵数 subarray_num-K_fbss+1 不能小于 Lc。');
end
if center_beam_count <= 2
    error('center_beam_count 必须大于目标数 Lc。');
end
if center_beam_count > (M_full + 1)
    error('center_beam_count 不能大于 M_full + 1。');
end

route_names = {'A0_original', 'A1_eval_improved', 'B_true_FBSS_centerT'};
route_labels = { ...
    'A0 原始旧路线', ...
    'A1 评估改进路线', ...
    'B 严格 FBSS + centerT'};
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
log_lines = append_log(log_lines, '第 7 步 A0 / A1 / B 三路线对比');
log_lines = append_log(log_lines, 'A0_original：');
log_lines = append_log(log_lines, '    原始 Route A，保留旧搜索假定。');
log_lines = append_log(log_lines, '    search_width = theta_sep。');
log_lines = append_log(log_lines, '    用于复现旧结果。');
log_lines = append_log(log_lines, '    该路线带有受限搜索先验，不作为完全公平的一般搜索基线。');
log_lines = append_log(log_lines, '');
log_lines = append_log(log_lines, 'A1_eval_improved：');
log_lines = append_log(log_lines, '    搜索宽度与目标间隔解耦。');
log_lines = append_log(log_lines, '    search_width = 4 * theta_sep。');
log_lines = append_log(log_lines, '    使用无边界峰值检测。');
log_lines = append_log(log_lines, '    beam grid 密度保持与原始 A 一致：M_old_A1 = round(search_scale_A1 * 50)。');
log_lines = append_log(log_lines, '    QSmoothRatio = %.2f。', qSmoothRatio_A1);
log_lines = append_log(log_lines, '');
log_lines = append_log(log_lines, 'B_true_FBSS_centerT：');
log_lines = append_log(log_lines, '    严格阵元域 FBSS -> centerT 波束域投影 -> 一维 MUSIC。');
log_lines = append_log(log_lines, '    使用 N=%d, K=%d, Psub=%d。', array_num, K_fbss, array_num - K_fbss + 1);
log_lines = append_log(log_lines, '');
log_lines = append_log(log_lines, '参数汇总：');
log_lines = append_log(log_lines, 'snr=%.2f, Metkl=%d, tol_deg=%.3f', snr, Metkl, tol_deg);
log_lines = append_log(log_lines, 'T_snap_list=%s', mat2str(T_snap_list));
log_lines = append_log(log_lines, 'bw_index_list=%s', mat2str(bw_index_list));
log_lines = append_log(log_lines, '');

for iSnap = 1:nsnap
    T_snap = T_snap_list(iSnap);
    t = linspace(0, 1, T_snap);
    log_lines = append_log(log_lines, '=== 快拍数 T_snap = %d ===', T_snap);

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

            [doa_B, debug_B] = DOA_three_music_new_route_centerT( ...
                y, ...
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

figure('Name', 'A0/A1/B 容差成功率', 'NumberTitle', 'off');
for iSnap = 1:nsnap
    subplot(nsnap, 1, iSnap);
    plot(bw_index_list, squeeze(tol_success_rate(iSnap, :, 1)), '-o', 'LineWidth', 1.2);
    hold on;
    plot(bw_index_list, squeeze(tol_success_rate(iSnap, :, 2)), '-s', 'LineWidth', 1.2);
    plot(bw_index_list, squeeze(tol_success_rate(iSnap, :, 3)), '-d', 'LineWidth', 1.2);
    hold off;
    grid on;
    xticks(bw_index_list);
    xlabel('角间隔档位');
    ylabel('容差成功率');
    title(sprintf('T_{snap} = %d 时的容差成功率', T_snap_list(iSnap)));
    legend(route_labels, 'Location', 'best');
end

figure('Name', 'A0/A1/B 均方根误差', 'NumberTitle', 'off');
for iSnap = 1:nsnap
    subplot(nsnap, 1, iSnap);
    plot(bw_index_list, squeeze(rmse(iSnap, :, 1)), '-o', 'LineWidth', 1.2);
    hold on;
    plot(bw_index_list, squeeze(rmse(iSnap, :, 2)), '-s', 'LineWidth', 1.2);
    plot(bw_index_list, squeeze(rmse(iSnap, :, 3)), '-d', 'LineWidth', 1.2);
    hold off;
    grid on;
    xticks(bw_index_list);
    xlabel('角间隔档位');
    ylabel('均方根误差（度）');
    title(sprintf('T_{snap} = %d 时的均方根误差', T_snap_list(iSnap)));
    legend(route_labels, 'Location', 'best');
end

figure('Name', 'A0 边界命中率与 A1 边缘命中率', 'NumberTitle', 'off');
for iSnap = 1:nsnap
    subplot(nsnap, 1, iSnap);
    plot(bw_index_list, squeeze(boundary_like_hit_rate_A0(iSnap, :)), '-o', 'LineWidth', 1.2);
    hold on;
    plot(bw_index_list, squeeze(edge_hit_rate_A1(iSnap, :)), '-s', 'LineWidth', 1.2);
    hold off;
    grid on;
    xticks(bw_index_list);
    xlabel('角间隔档位');
    ylabel('命中率');
    title(sprintf('T_{snap} = %d 时的 A0 边界命中与 A1 边缘命中', T_snap_list(iSnap)));
    legend({'A0 边界命中', 'A1 边缘命中'}, 'Location', 'best');
end

figure('Name', '路线 B 不同快拍数对比', 'NumberTitle', 'off');
plot(bw_index_list, squeeze(tol_success_rate(1, :, 3)), '-o', 'LineWidth', 1.2);
hold on;
plot(bw_index_list, squeeze(tol_success_rate(2, :, 3)), '-s', 'LineWidth', 1.2);
plot(bw_index_list, squeeze(tol_success_rate(3, :, 3)), '-d', 'LineWidth', 1.2);
hold off;
grid on;
xticks(bw_index_list);
xlabel('角间隔档位');
ylabel('容差成功率');
title('路线 B 在不同快拍数下的容差成功率对比');
legend({'路线 B，T=130', '路线 B，T=260', '路线 B，T=520'}, 'Location', 'best');

fid = fopen(fullfile(fileparts(mfilename('fullpath')), 'compare_step07_A0_A1_B.log'), 'w');
if fid < 0
    error('无法打开日志文件。');
end
for ii = 1:numel(log_lines)
    fprintf(fid, '%s\n', log_lines{ii});
end
fclose(fid);

function log_lines = append_log(log_lines, fmt, varargin)
    line = sprintf(fmt, varargin{:});
    fprintf('%s\n', line);
    log_lines{end+1, 1} = line;
end
