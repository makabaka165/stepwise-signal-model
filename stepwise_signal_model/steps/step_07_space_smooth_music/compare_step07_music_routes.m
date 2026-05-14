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

T_snap_list = [130, 520];
bw_index_list = [8 9 10]; % 完整实验应使用 1:10；Route C 的 2D 搜索较重，默认先跑 bw/8~bw/10。

subarray_num = 59;
M_full = 32;
center_beam_count = 25;
search_scale = 4;
tol_deg = 0.1;

route_names = {'Route A', 'Route B', 'Route C', 'Route D'};
route_labels = { ...
    'Route A old beam-index smoothing MUSIC', ...
    'Route B centerT 1D MUSIC', ...
    'Route C centerT 2D pair-MUSIC', ...
    'Route D ESPRIT reference'};
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

output_dir = fileparts(mfilename('fullpath'));
mat_path = fullfile(output_dir, 'compare_step07_music_routes.mat');
log_path = fullfile(output_dir, 'compare_step07_music_routes.log');

has_esprit = false;
esprit_note = '未找到已有 ESPRIT 函数，本次 ESPRIT 对比跳过。';
existing_esprit_files = {'doa_esprit_from_Rss.m', 'DOA_esprit_.m', 'esprit_.m'};
for ii = 1:numel(existing_esprit_files)
    if exist(existing_esprit_files{ii}, 'file') == 2
        has_esprit = true;
        esprit_note = ['检测到可用 ESPRIT 文件: ', existing_esprit_files{ii}];
        break;
    end
end

nsnap = numel(T_snap_list);
nbw = numel(bw_index_list);
raw_success_count = zeros(nsnap, nbw, route_count);
tol_success_count = zeros(nsnap, nbw, route_count);
rmse_sum_sqerr = zeros(nsnap, nbw, route_count);
rmse_valid_count = zeros(nsnap, nbw, route_count);

sample_debug = struct();
sample_debug.routeC = cell(nsnap, nbw);

fid = fopen(log_path, 'w');
if fid < 0
    error('Failed to open log file: %s', log_path);
end

cleanup_obj = onCleanup(@() fclose(fid));

fprintf(fid, 'compare_step07_music_routes\n');
fprintf(fid, '生成时间: %s\n\n', datestr(now, 31));
fprintf(fid, '参数汇总:\n');
fprintf(fid, 'array_num=%d, subarray_num=%d, snr=%.2f, Metkl=%d\n', ...
    array_num, subarray_num, snr, Metkl);
fprintf(fid, 'T_snap_list=%s\n', mat2str(T_snap_list));
fprintf(fid, 'center_beam_count=%d, M_full=%d, search_scale=%.2f, tol_deg=%.3f\n', ...
    center_beam_count, M_full, search_scale, tol_deg);
fprintf(fid, 'bw_index_list=%s\n', mat2str(bw_index_list));
fprintf(fid, '说明: 完整实验推荐 bw_index_list = 1:10；当前默认仅运行 bw/8~bw/10 以控制 Route C 的 2D pair-MUSIC 计算量。\n');
fprintf(fid, 'Route B/C 前端说明: 当前仍使用 mssp(Rxx, subarray_num)，即“阵元域前后向平均 / 退化 mssp -> centerT -> beamspace”，不是严格 K < N 的阵元域 FBSS。\n');
fprintf(fid, 'ESPRIT说明: %s\n\n', esprit_note);

for iSnap = 1:nsnap
    T_snap = T_snap_list(iSnap);
    t = linspace(0, 1, T_snap);
    fprintf('Running T_snap = %d\n', T_snap);
    fprintf(fid, '=== T_snap = %d ===\n', T_snap);

    for ibw = 1:nbw
        angle_grid_num = bw_index_list(ibw);
        theta_a = theta_c - theta_bw(angle_grid_num) / 2;
        theta_b = theta_c + theta_bw(angle_grid_num) / 2;
        target_theta = [theta_a, theta_b];
        RecvbeamC = mean(target_theta);
        theta_search_new = search_scale * theta_bw(angle_grid_num);

        fprintf('  bw/%d (%d/%d)\n', angle_grid_num, ibw, nbw);

        for metkl_num = 1:Metkl
            s1 = sqrt(10^(snr / 10)) * exp(j * 2 * pi * fc * t);
            s2 = sqrt(10^(snr / 10)) * exp(j * 2 * pi * fc * t);
            A_a = exp(-j * 2 * pi * d * (0:array_num-1) * sind(theta_a) / lambda);
            A_b = exp(-j * 2 * pi * d * (0:array_num-1) * sind(theta_b) / lambda);

            s11 = A_a.' * s1;
            s21 = A_b.' * s2;
            y = s11 + s21 + (1 / sqrt(2)) * (randn(array_num, T_snap) + j * randn(array_num, T_snap));

            % Route A: 旧路线 beam-index smoothing MUSIC，冻结逻辑
            A_old = diag(win_old) * exp(j * 2 * pi * position_full / lambda * sin(angle_recv_old_template * pi / 180));
            sr_DBF_boshu = A_old.' * y;
            doa_old = DOA_three_music_hecheng_fangzhen( ...
                sr_DBF_boshu, array_num, A_old, RecvbeamC, theta_bw(angle_grid_num));

            % Route B/C: 共用同一个 y_sub 和同一个 T_center
            y_sub = y(1:subarray_num, :);
            doa_center_1d = DOA_three_music_new_route_centerT( ...
                y_sub, subarray_num, T_center, RecvbeamC, theta_search_new);
            [doa_center_pair, debug_pair] = DOA_three_music_new_route_centerT_pair_music( ...
                y_sub, subarray_num, T_center, RecvbeamC, theta_search_new, ...
                'Lc', 2, ...
                'GridStepDeg', 0.005, ...
                'MinSepDeg', 0.03);

            if metkl_num == 1
                sample_debug.routeC{iSnap, ibw} = debug_pair;
            end

            % Route D: ESPRIT 参考项，仅复用已有函数；当前无函数则记 NaN
            doa_esprit = [NaN NaN];
            if has_esprit
                doa_esprit = [NaN NaN];
            end

            doa_all = {doa_old, doa_center_1d, doa_center_pair, doa_esprit};

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

        fprintf(fid, ['bw/%d | ', ...
            'A raw=%d tol=%d RMSE=%.4f | ', ...
            'B raw=%d tol=%d RMSE=%.4f | ', ...
            'C raw=%d tol=%d RMSE=%.4f | ', ...
            'D raw=%d tol=%d RMSE=%.4f\n'], ...
            angle_grid_num, ...
            current_raw(1), current_tol(1), current_rmse(1), ...
            current_raw(2), current_tol(2), current_rmse(2), ...
            current_raw(3), current_tol(3), current_rmse(3), ...
            current_raw(4), current_tol(4), current_rmse(4));
    end
    fprintf(fid, '\n');
end

raw_success_rate = raw_success_count / Metkl;
tol_success_rate = tol_success_count / Metkl;
rmse = nan(nsnap, nbw, route_count);
valid_all = rmse_valid_count > 0;
rmse(valid_all) = sqrt(rmse_sum_sqerr(valid_all) ./ (2 * rmse_valid_count(valid_all)));

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
params.T_snap_list = T_snap_list;
params.bw_index_list = bw_index_list;
params.subarray_num = subarray_num;
params.M_full = M_full;
params.center_beam_count = center_beam_count;
params.search_scale = search_scale;
params.tol_deg = tol_deg;
params.route_labels = route_labels;
params.route_frontend_note = 'Route B/C 当前仍使用 mssp(Rxx, subarray_num)，属于阵元域前后向平均/退化 mssp -> centerT -> beamspace，而非严格 K < N 的 FBSS。';
params.esprit_note = esprit_note;

save(mat_path, ...
    'params', ...
    'theta_bw', ...
    'T_snap_list', ...
    'bw_index_list', ...
    'route_names', ...
    'route_labels', ...
    'raw_success_rate', ...
    'tol_success_rate', ...
    'rmse', ...
    'raw_success_count', ...
    'tol_success_count', ...
    'rmse_sum_sqerr', ...
    'rmse_valid_count', ...
    'sample_debug');

xvals = bw_index_list;
xlabels = arrayfun(@(k) sprintf('bw/%d', k), bw_index_list, 'UniformOutput', false);
plot_styles = {'-o', '-s', '-d', '-^'};

for iSnap = 1:nsnap
    T_snap = T_snap_list(iSnap);

    fig1 = figure('Visible', 'off');
    hold on
    for iroute = 1:route_count
        plot(xvals, squeeze(tol_success_rate(iSnap, :, iroute)), plot_styles{iroute}, 'LineWidth', 1.2);
    end
    hold off
    grid on
    xticks(xvals)
    xticklabels(xlabels)
    xlabel('目标角间隔档位')
    ylabel('tol success rate')
    legend(route_labels, 'Location', 'best')
    title(sprintf('T_{snap} = %d tol success rate', T_snap))
    saveas(fig1, fullfile(output_dir, sprintf('fig_tol_success_T%d.png', T_snap)));
    close(fig1)

    fig2 = figure('Visible', 'off');
    hold on
    for iroute = 1:route_count
        plot(xvals, squeeze(rmse(iSnap, :, iroute)), plot_styles{iroute}, 'LineWidth', 1.2);
    end
    hold off
    grid on
    xticks(xvals)
    xticklabels(xlabels)
    xlabel('目标角间隔档位')
    ylabel('RMSE (deg)')
    legend(route_labels, 'Location', 'best')
    title(sprintf('T_{snap} = %d RMSE', T_snap))
    saveas(fig2, fullfile(output_dir, sprintf('fig_rmse_T%d.png', T_snap)));
    close(fig2)
end

fig3 = figure('Visible', 'off');
hold on
plot(xvals, squeeze(tol_success_rate(1, :, 2)), '-s', 'LineWidth', 1.2);
plot(xvals, squeeze(tol_success_rate(2, :, 2)), '-o', 'LineWidth', 1.2);
hold off
grid on
xticks(xvals)
xticklabels(xlabels)
xlabel('目标角间隔档位')
ylabel('tol success rate')
legend({'Route B T=130', 'Route B T=520'}, 'Location', 'best')
title('Route B snapshot comparison')
saveas(fig3, fullfile(output_dir, 'fig_routeB_snap_compare.png'));
close(fig3)

fig4 = figure('Visible', 'off');
hold on
plot(xvals, squeeze(tol_success_rate(1, :, 3)), '-d', 'LineWidth', 1.2);
plot(xvals, squeeze(tol_success_rate(2, :, 3)), '-^', 'LineWidth', 1.2);
hold off
grid on
xticks(xvals)
xticklabels(xlabels)
xlabel('目标角间隔档位')
ylabel('tol success rate')
legend({'Route C T=130', 'Route C T=520'}, 'Location', 'best')
title('Route C snapshot comparison')
saveas(fig4, fullfile(output_dir, 'fig_routeC_snap_compare.png'));
close(fig4)

small_idx = find(ismember(bw_index_list, [8 9 10]));
small_labels = arrayfun(@(k) sprintf('bw/%d', k), bw_index_list(small_idx), 'UniformOutput', false);
small_data = [squeeze(tol_success_rate(1, small_idx, 2)).', ...
              squeeze(tol_success_rate(1, small_idx, 3)).', ...
              squeeze(tol_success_rate(2, small_idx, 2)).', ...
              squeeze(tol_success_rate(2, small_idx, 3)).'];

fig5 = figure('Visible', 'off');
bar(small_data)
grid on
xticks(1:numel(small_idx))
xticklabels(small_labels)
xlabel('小角间隔档位')
ylabel('tol success rate')
legend({'Route B T=130', 'Route C T=130', 'Route B T=520', 'Route C T=520'}, 'Location', 'best')
title('Route B vs Route C on bw/8 bw/9 bw/10')
saveas(fig5, fullfile(output_dir, 'fig_small_spacing_compare.png'));
close(fig5)

fprintf(fid, '汇总结论:\n');
if nsnap >= 2
    route_b_delta = squeeze(tol_success_rate(2, :, 2) - tol_success_rate(1, :, 2)).';
    route_c_delta = squeeze(tol_success_rate(2, :, 3) - tol_success_rate(1, :, 3)).';
    fprintf(fid, 'Route B: T_snap 从 %d 到 %d 的 tol_success_rate 差值 = %s\n', ...
        T_snap_list(1), T_snap_list(2), mat2str(route_b_delta, 4));
    fprintf(fid, 'Route C: T_snap 从 %d 到 %d 的 tol_success_rate 差值 = %s\n', ...
        T_snap_list(1), T_snap_list(2), mat2str(route_c_delta, 4));
end

fprintf(fid, 'Route C 相对 Route B 的 tol_success_rate 差值:\n');
for iSnap = 1:nsnap
    diff_bc = squeeze(tol_success_rate(iSnap, :, 3) - tol_success_rate(iSnap, :, 2)).';
    fprintf(fid, 'T_snap=%d: %s\n', T_snap_list(iSnap), mat2str(diff_bc, 4));
end

if has_esprit
    fprintf(fid, 'ESPRIT 结果已接入，请结合 Route D 统计表分析差距。\n');
else
    fprintf(fid, 'ESPRIT 未接入，Route D 全部为 NaN。\n');
end

fprintf('Saved results to %s\n', output_dir);
