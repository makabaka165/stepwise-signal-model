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
bw_index_list = 1:10;
search_scale_A1 = 4;
tol_deg = 0.1;

j = sqrt(-1);
position_full = d * (0:array_num-1).';
win_old = taylorwin(array_num, 25, -40)';
win_old = win_old / sqrt(win_old * win_old');

routeA1_beam_span = search_scale_A1 * bw_64;
M_old_A1 = round(search_scale_A1 * 50);
angle_recv_A1 = linspace(theta_c - routeA1_beam_span/2, ...
                         theta_c + routeA1_beam_span/2, ...
                         M_old_A1 + 1);
A1_beam_matrix = diag(win_old) * exp( ...
    j * 2*pi * position_full / lambda * sin(angle_recv_A1 * pi / 180));

variant_names = { ...
    'A1_ratio_center', ...
    'A1_fixed41_center', ...
    'A1_fixedPhysical_center', ...
    'A1_ratio_manifold', ...
    'A1_fixed41_manifold'};
variant_labels = { ...
    'A1 比例窗 + 中心谱', ...
    'A1 固定41窗 + 中心谱', ...
    'A1 固定物理窗 + 中心谱', ...
    'A1 比例窗 + 流形谱', ...
    'A1 固定41窗 + 流形谱'};
variant_count = numel(variant_names);

nsnap = numel(T_snap_list);
nbw = numel(bw_index_list);
raw_success_count = zeros(nsnap, nbw, variant_count);
tol_success_count = zeros(nsnap, nbw, variant_count);
rmse_sum_sqerr = zeros(nsnap, nbw, variant_count);
rmse_valid_count = zeros(nsnap, nbw, variant_count);
sum_num_peaks = zeros(nsnap, nbw, variant_count);
sum_nearest_peak_error = zeros(nsnap, nbw, variant_count);
count_nearest_peak_error = zeros(nsnap, nbw, variant_count);
sample_debug = cell(nsnap, nbw, variant_count);

log_lines = {};
log_lines = append_log(log_lines, '第 7 步 A1 路线诊断对比');
log_lines = append_log(log_lines, '变体列表：');
for iv = 1:variant_count
    log_lines = append_log(log_lines, '- %s（%s）', variant_names{iv}, variant_labels{iv});
end
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
        theta_search_A1 = search_scale_A1 * theta_sep;

        for metkl_num = 1:Metkl
            s1 = sqrt(10^(snr / 10)) * exp(j * 2 * pi * fc * t);
            s2 = sqrt(10^(snr / 10)) * exp(j * 2 * pi * fc * t);
            A_a = exp(-j * 2 * pi * d * (0:array_num-1) * sind(theta_a) / lambda);
            A_b = exp(-j * 2 * pi * d * (0:array_num-1) * sind(theta_b) / lambda);

            s11 = A_a.' * s1;
            s21 = A_b.' * s2;
            y = s11 + s21 + (1 / sqrt(2)) * (randn(array_num, T_snap) + j * randn(array_num, T_snap));
            sr_DBF_A1 = A1_beam_matrix.' * y;

            for iv = 1:variant_count
                switch variant_names{iv}
                    case 'A1_ratio_center'
                        [doa_est, dbg] = DOA_three_music_hecheng_fangzhen_eval( ...
                            sr_DBF_A1, array_num, A1_beam_matrix, RecvbeamC, theta_search_A1, ...
                            'Lc', 2, ...
                            'QSmoothRatio', 0.2, ...
                            'CellnMode', 'ratio', ...
                            'SpectrumMode', 'center', ...
                            'TargetTheta', target_theta);
                    case 'A1_fixed41_center'
                        [doa_est, dbg] = DOA_three_music_hecheng_fangzhen_eval( ...
                            sr_DBF_A1, array_num, A1_beam_matrix, RecvbeamC, theta_search_A1, ...
                            'Lc', 2, ...
                            'CellnMode', 'fixed_celln', ...
                            'FixedCelln', 41, ...
                            'SpectrumMode', 'center', ...
                            'TargetTheta', target_theta);
                    case 'A1_fixedPhysical_center'
                        [doa_est, dbg] = DOA_three_music_hecheng_fangzhen_eval( ...
                            sr_DBF_A1, array_num, A1_beam_matrix, RecvbeamC, theta_search_A1, ...
                            'Lc', 2, ...
                            'CellnMode', 'fixed_physical', ...
                            'FixedPhysicalSpanDeg', 0.8 * bw_64, ...
                            'SpectrumMode', 'center', ...
                            'TargetTheta', target_theta);
                    case 'A1_ratio_manifold'
                        [doa_est, dbg] = DOA_three_music_hecheng_fangzhen_eval( ...
                            sr_DBF_A1, array_num, A1_beam_matrix, RecvbeamC, theta_search_A1, ...
                            'Lc', 2, ...
                            'QSmoothRatio', 0.2, ...
                            'CellnMode', 'ratio', ...
                            'SpectrumMode', 'manifold', ...
                            'TargetTheta', target_theta);
                    case 'A1_fixed41_manifold'
                        [doa_est, dbg] = DOA_three_music_hecheng_fangzhen_eval( ...
                            sr_DBF_A1, array_num, A1_beam_matrix, RecvbeamC, theta_search_A1, ...
                            'Lc', 2, ...
                            'CellnMode', 'fixed_celln', ...
                            'FixedCelln', 41, ...
                            'SpectrumMode', 'manifold', ...
                            'TargetTheta', target_theta);
                    otherwise
                        error('未知的 A1 诊断变体。');
                end

                if metkl_num == 1
                    sample_debug{iSnap, ibw, iv} = dbg;
                end

                sum_num_peaks(iSnap, ibw, iv) = sum_num_peaks(iSnap, ibw, iv) + dbg.num_peaks;

                if isfield(dbg, 'nearest_peak_error_to_target') && any(isfinite(dbg.nearest_peak_error_to_target))
                    valid_err = dbg.nearest_peak_error_to_target(isfinite(dbg.nearest_peak_error_to_target));
                    sum_nearest_peak_error(iSnap, ibw, iv) = sum_nearest_peak_error(iSnap, ibw, iv) + mean(valid_err);
                    count_nearest_peak_error(iSnap, ibw, iv) = count_nearest_peak_error(iSnap, ibw, iv) + 1;
                end

                raw_ok = all(isfinite(doa_est));
                tol_ok = is_valid_doa_success(doa_est, target_theta, tol_deg);

                if raw_ok
                    raw_success_count(iSnap, ibw, iv) = raw_success_count(iSnap, ibw, iv) + 1;
                    sqerr = sum((sort(doa_est(:).') - sort(target_theta(:).')).^2);
                    rmse_sum_sqerr(iSnap, ibw, iv) = rmse_sum_sqerr(iSnap, ibw, iv) + sqerr;
                    rmse_valid_count(iSnap, ibw, iv) = rmse_valid_count(iSnap, ibw, iv) + 1;
                end

                if tol_ok
                    tol_success_count(iSnap, ibw, iv) = tol_success_count(iSnap, ibw, iv) + 1;
                end
            end
        end

        log_lines = append_log(log_lines, 'bw/%d 诊断完成。', angle_grid_num);
    end
    log_lines = append_log(log_lines, '');
end

raw_success_rate = raw_success_count / Metkl;
tol_success_rate = tol_success_count / Metkl;
rmse = nan(nsnap, nbw, variant_count);
valid_all = rmse_valid_count > 0;
rmse(valid_all) = sqrt(rmse_sum_sqerr(valid_all) ./ (2 * rmse_valid_count(valid_all)));

mean_num_peaks = sum_num_peaks / Metkl;
mean_nearest_peak_error_to_target = nan(nsnap, nbw, variant_count);
mask_err = count_nearest_peak_error > 0;
mean_nearest_peak_error_to_target(mask_err) = ...
    sum_nearest_peak_error(mask_err) ./ count_nearest_peak_error(mask_err);

log_lines = append_log(log_lines, '诊断汇总：');
for iv = 1:variant_count
    log_lines = append_log(log_lines, '%s 在 T=130 时的容差成功率：%s', ...
        variant_names{iv}, mat2str(squeeze(tol_success_rate(1, :, iv)), 4));
    log_lines = append_log(log_lines, '%s 在 T=520 时的容差成功率：%s', ...
        variant_names{iv}, mat2str(squeeze(tol_success_rate(2, :, iv)), 4));
end

params = struct();
params.array_num = array_num;
params.theta_c = theta_c;
params.snr = snr;
params.Metkl = Metkl;
params.T_snap_list = T_snap_list;
params.bw_index_list = bw_index_list;
params.search_scale_A1 = search_scale_A1;
params.tol_deg = tol_deg;
params.M_old_A1 = M_old_A1;
params.routeA1_beam_span = routeA1_beam_span;

output_dir = fileparts(mfilename('fullpath'));
fid = fopen(fullfile(output_dir, 'compare_routeA1_diagnostics.log'), 'w');
if fid < 0
    error('无法打开日志文件。');
end
for ii = 1:numel(log_lines)
    fprintf(fid, '%s\n', log_lines{ii});
end
fclose(fid);

xvals = bw_index_list;
xlabels = arrayfun(@(k) sprintf('bw/%d', k), bw_index_list, 'UniformOutput', false);

figure('Name', 'A1 各变体容差成功率', 'NumberTitle', 'off');
for iSnap = 1:nsnap
    subplot(nsnap, 1, iSnap);
    hold on;
    for iv = 1:variant_count
        plot(xvals, squeeze(tol_success_rate(iSnap, :, iv)), 'LineWidth', 1.2);
    end
    hold off;
    grid on;
    xticks(xvals);
    xticklabels(xlabels);
    ylabel('容差成功率');
    title(sprintf('T_{snap} = %d 时的容差成功率', T_snap_list(iSnap)));
    if iSnap == 1
        legend(variant_labels, 'Location', 'best');
    end
end
xlabel('角间隔档位');

figure('Name', 'A1 各变体均方根误差', 'NumberTitle', 'off');
for iSnap = 1:nsnap
    subplot(nsnap, 1, iSnap);
    hold on;
    for iv = 1:variant_count
        plot(xvals, squeeze(rmse(iSnap, :, iv)), 'LineWidth', 1.2);
    end
    hold off;
    grid on;
    xticks(xvals);
    xticklabels(xlabels);
    ylabel('均方根误差（度）');
    title(sprintf('T_{snap} = %d 时的均方根误差', T_snap_list(iSnap)));
    if iSnap == 1
        legend(variant_labels, 'Location', 'best');
    end
end
xlabel('角间隔档位');

figure('Name', 'A1 各变体平均峰数', 'NumberTitle', 'off');
for iSnap = 1:nsnap
    subplot(nsnap, 1, iSnap);
    hold on;
    for iv = 1:variant_count
        plot(xvals, squeeze(mean_num_peaks(iSnap, :, iv)), 'LineWidth', 1.2);
    end
    hold off;
    grid on;
    xticks(xvals);
    xticklabels(xlabels);
    ylabel('平均峰数');
    title(sprintf('T_{snap} = %d 时的平均峰数', T_snap_list(iSnap)));
    if iSnap == 1
        legend(variant_labels, 'Location', 'best');
    end
end
xlabel('角间隔档位');

function log_lines = append_log(log_lines, fmt, varargin)
    line = sprintf(fmt, varargin{:});
    fprintf('%s\n', line);
    log_lines{end+1, 1} = line;
end
