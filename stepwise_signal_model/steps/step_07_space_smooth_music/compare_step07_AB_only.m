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
    '路线 A 评估版 beam-index smoothing MUSIC', ...
    '路线 B 严格阵元域 FBSS / centerT 波束域 MUSIC'};
route_count = numel(route_names);

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
log_lines = append_log(log_lines, '第 7 步路线 A/B 对比');
log_lines = append_log(log_lines, '当前启用路线：');
log_lines = append_log(log_lines, '- 路线 A：旧路线 beam-index smoothing MUSIC（评估版）');
log_lines = append_log(log_lines, '- 路线 B：严格阵元域 FBSS -> centerT 波束域投影 -> 一维 MUSIC');
log_lines = append_log(log_lines, '');
log_lines = append_log(log_lines, '暂停路线：');
log_lines = append_log(log_lines, '- 路线 C：二维 pair-MUSIC 后端，已归档');
log_lines = append_log(log_lines, '- 路线 D：ESPRIT 参考对比，已归档或跳过');
log_lines = append_log(log_lines, '');
log_lines = append_log(log_lines, '本次运行不修改也不评估路线 C/D。');
log_lines = append_log(log_lines, '');
log_lines = append_log(log_lines, '参数汇总：');
log_lines = append_log(log_lines, 'array_num=%d, subarray_num=%d, K_fbss=%d, snr=%.2f, Metkl=%d', ...
    array_num, subarray_num, K_fbss, snr, Metkl);
log_lines = append_log(log_lines, 'T_snap_list=%s', mat2str(T_snap_list));
log_lines = append_log(log_lines, 'center_beam_count=%d, M_full=%d, search_scale_A=%.2f, search_scale_B=%.2f, tol_deg=%.3f', ...
    center_beam_count, M_full, search_scale_A, search_scale_B, tol_deg);
log_lines = append_log(log_lines, 'bw_index_list=%s', mat2str(bw_index_list));
log_lines = append_log(log_lines, '路线 B 使用完整的 array_num 阵元。');
log_lines = append_log(log_lines, 'K_fbss = %d。', K_fbss);
log_lines = append_log(log_lines, 'Rss = mssp_array_fb(Rxx, K_fbss)。');
log_lines = append_log(log_lines, 'Psub = array_num - K_fbss + 1 = %d。', subarray_num - K_fbss + 1);
log_lines = append_log(log_lines, 'centerT/Tk 在函数内部基于 K 维子阵构造。');
log_lines = append_log(log_lines, '路线 B 的波束网格按每个 bw 档位自适应：routeB_beam_span = 1.5 * theta_search_B。');
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

            [doa_center_1d, debug_B] = DOA_three_music_new_route_centerT( ...
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

log_lines = append_log(log_lines, '结果汇总：');
for iSnap = 1:nsnap
    log_lines = append_log(log_lines, '路线 A 在 T_snap=%d 时的边界命中率 = %s', ...
        T_snap_list(iSnap), mat2str(squeeze(edge_hit_rate_A(iSnap, :)), 4));
    log_lines = append_log(log_lines, '路线 B 在 T_snap=%d 时的容差成功率 = %s', ...
        T_snap_list(iSnap), mat2str(squeeze(tol_success_rate(iSnap, :, 2)), 4));
    log_lines = append_log(log_lines, '路线 B 在 T_snap=%d 时的均方根误差 = %s', ...
        T_snap_list(iSnap), mat2str(squeeze(rmse(iSnap, :, 2)), 4));
end

figure('Name', '路线 A/B 容差成功率', 'NumberTitle', 'off');
for iSnap = 1:nsnap
    subplot(nsnap, 1, iSnap);
    plot(bw_index_list, squeeze(tol_success_rate(iSnap, :, 1)), '-o', 'LineWidth', 1.2);
    hold on;
    plot(bw_index_list, squeeze(tol_success_rate(iSnap, :, 2)), '-s', 'LineWidth', 1.2);
    hold off;
    grid on;
    xticks(bw_index_list);
    xlabel('角间隔档位');
    ylabel('容差成功率');
    title(sprintf('A/B 在 T_{snap} = %d 时的容差成功率', T_snap_list(iSnap)));
    legend(route_labels, 'Location', 'best');
end

figure('Name', '路线 A/B 均方根误差', 'NumberTitle', 'off');
for iSnap = 1:nsnap
    subplot(nsnap, 1, iSnap);
    plot(bw_index_list, squeeze(rmse(iSnap, :, 1)), '-o', 'LineWidth', 1.2);
    hold on;
    plot(bw_index_list, squeeze(rmse(iSnap, :, 2)), '-s', 'LineWidth', 1.2);
    hold off;
    grid on;
    xticks(bw_index_list);
    xlabel('角间隔档位');
    ylabel('均方根误差（度）');
    title(sprintf('A/B 在 T_{snap} = %d 时的均方根误差', T_snap_list(iSnap)));
    legend(route_labels, 'Location', 'best');
end

figure('Name', '路线 B 不同快拍数容差成功率', 'NumberTitle', 'off');
plot(bw_index_list, squeeze(tol_success_rate(1, :, 2)), '-o', 'LineWidth', 1.2);
hold on;
plot(bw_index_list, squeeze(tol_success_rate(2, :, 2)), '-s', 'LineWidth', 1.2);
plot(bw_index_list, squeeze(tol_success_rate(3, :, 2)), '-d', 'LineWidth', 1.2);
hold off;
grid on;
xticks(bw_index_list);
xlabel('角间隔档位');
ylabel('容差成功率');
title('路线 B 在不同快拍数下的容差成功率对比');
legend({'路线 B，T=130', '路线 B，T=260', '路线 B，T=520'}, 'Location', 'best');

figure('Name', '路线 B 不同快拍数均方根误差', 'NumberTitle', 'off');
plot(bw_index_list, squeeze(rmse(1, :, 2)), '-o', 'LineWidth', 1.2);
hold on;
plot(bw_index_list, squeeze(rmse(2, :, 2)), '-s', 'LineWidth', 1.2);
plot(bw_index_list, squeeze(rmse(3, :, 2)), '-d', 'LineWidth', 1.2);
hold off;
grid on;
xticks(bw_index_list);
xlabel('角间隔档位');
ylabel('均方根误差（度）');
title('路线 B 在不同快拍数下的均方根误差对比');
legend({'路线 B，T=130', '路线 B，T=260', '路线 B，T=520'}, 'Location', 'best');

fid = fopen(fullfile(fileparts(mfilename('fullpath')), 'compare_step07_AB_only.log'), 'w');
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
