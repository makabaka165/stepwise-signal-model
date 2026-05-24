clc
clear
close all

script_dir = fileparts(mfilename('fullpath'));
steps_dir = fileparts(script_dir);
project_dir = fileparts(steps_dir);
step08_dir = fullfile(steps_dir, 'step_08_routeB_innovation');
step75_dir = fullfile(steps_dir, 'step_07_5_space_smooth_beamspace_MUSIC_monte_carlo');

addpath(fullfile(project_dir, 'core', 'config'));
addpath(fullfile(project_dir, 'core', 'array'));
addpath(step75_dir);
addpath(step08_dir);

cfg = sim_cfg();

result_dir = fullfile(script_dir, 'results_step8_5_cylindrical_arc_proto10');
if ~exist(result_dir, 'dir')
    mkdir(result_dir);
end

log_path = fullfile(result_dir, 'step8_5_cylindrical_arc_proto10.log');
fid_log = fopen(log_path, 'w');
cleanup_log = onCleanup(@() fclose(fid_log));

log_msg(fid_log, 'Step 08.5 Prototype 10.A: cylindrical arc ULA approximation');
log_msg(fid_log, 'Script: %s', mfilename('fullpath'));
log_msg(fid_log, 'Frozen algorithm paths: %s ; %s', step08_dir, step75_dir);

sep_factor_list = [1, 2, 3, 5, 7, 10];
snr_list = -4:2:30;
Metkl = 200;
T_snap = 260;
tol_deg = 0.1;
tol_rel_ratio = 0.25;
base_seed = 20260601;
azCtr_deg = 0;
N_arc = 32;
iel_select = round(cfg.arr.Nel / 2);
K_fbss = 28;
Lc = 2;
search_scale_B = 4;
M_full = 24;
center_beam_count = 19;
el_a = 0;
el_b = 0;
theta_c = azCtr_deg;

j = sqrt(-1);
t = linspace(0, 1, T_snap);
% 完全同相相干源，与第 8 步 proto6 一致，不引入任何相位偏置。
s1 = exp(j * 2*pi * cfg.arr.fc * t);
s2 = exp(j * 2*pi * cfg.arr.fc * t);

route_names = { ...
    'cylindrical_grid_music_baseline', ...
    'cylindrical_root_music_proto10', ...
    'pure_ula_root_music_reference'};
nroutes = numel(route_names);
route_name_64 = 'pure_ula_root_music_64ch_proto6_replay';

arrInfo = arr_cyl(cfg, azCtr_deg);
col_mid = round((cfg.beam.subNaz + 1) / 2);
col_select = (col_mid - N_arc/2 + 1):(col_mid + N_arc/2);
pos_xyz = [arrInfo.XAct(col_select, iel_select), ...
           arrInfo.YAct(col_select, iel_select), ...
           arrInfo.ZAct(col_select, iel_select)];

% --------------------------------------------------------------------------
% 圆柱阵 -> 局部 ULA 等效的必要预处理：视轴方向相位归一化
%
% 物理动机：
%   圆柱阵阵元在视轴方向（azCtr=0 deg）的几何距离不一致。
%   即便信号从视轴方向入射，y 在阵元间的相位也不是 ULA 的常相位。
%   直接喂给 ULA-Root-MUSIC 算法会让 sanity check 失败。
%
% 处理方法：
%   把 y 点除视轴方向的 steering 向量 A_ref，等价于把每个阵元的
%   视轴方向相位归零。归一化后，从 theta 约等于 azCtr 方向入射的信号
%   在阵元间的相位差，近似等于 ULA 流形
%   exp(-j*2*pi*d_eq*n*sin(theta-azCtr)/lambda)。
%
% 适用边界：
%   仅在弧段跨度约 <= +/-30 deg 时近似成立。本脚本 N_arc=32 跨 58.125 deg
%   在该范围内。详细失配边界由 rho(theta) 几何分析给出。
% --------------------------------------------------------------------------
unit_ref = [cosd(0) * cosd(azCtr_deg), cosd(0) * sind(azCtr_deg), sind(0)];
A_ref = exp(-j * 2*pi / cfg.arr.lambda * pos_xyz * unit_ref.');

d_eq = 2*pi * cfg.arr.R / cfg.arr.Naz;
arc_dist = d_eq;
arc_over_lambda = arc_dist / cfg.arr.lambda;
subArc_span_deg = (cfg.beam.subNaz - 1) * cfg.arr.dPhi;
N_arc_span_deg = (N_arc - 1) * cfg.arr.dPhi;
edge_offset_deg = N_arc_span_deg / 2;
d_eq_over_lambda = d_eq / cfg.arr.lambda;
bw_eq = 50.8 * 1.45 * cfg.arr.lambda / (N_arc - 1) / d_eq;
bw_eq = round(bw_eq * 100) / 100;
posK = d_eq * (0:K_fbss-1).';

N_64 = 64;
d_64 = 0.047;
fc_64 = 2.7e9;
lambda_64 = 3e8 / fc_64;
bw_64 = 50.8 * 1.45 * lambda_64 / (N_64 - 1) / d_64;
bw_64 = round(bw_64 * 10) / 10;
theta_c_64 = 13;
K_fbss_64 = 56;
sep_factor_list_64 = [7, 8, 9, 10];
snr_list_64 = 14:2:28;
pos_N64 = d_64 * (0:N_64-1).';
t_64 = linspace(0, 1, T_snap);
s1_64 = exp(j * 2*pi * fc_64 * t_64);
s2_64 = exp(j * 2*pi * fc_64 * t_64);

log_msg(fid_log, '');
log_msg(fid_log, 'Layer 1 geometry health check');
log_msg(fid_log, 'cfg.arr.Naz=%d, cfg.arr.Nel=%d, cfg.arr.R=%.6f m, cfg.arr.dPhi=%.6f deg', ...
    cfg.arr.Naz, cfg.arr.Nel, cfg.arr.R, cfg.arr.dPhi);
log_msg(fid_log, 'cfg.beam.sectorHalf=%.6f deg, cfg.beam.subNaz=%d', cfg.beam.sectorHalf, cfg.beam.subNaz);
log_msg(fid_log, 'arc_dist=%.8f m', arc_dist);
log_msg(fid_log, 'arc/lambda=%.8f', arc_over_lambda);
log_msg(fid_log, 'subArc_span_deg=%.6f deg', subArc_span_deg);
log_msg(fid_log, 'N_arc_span_deg=%.6f deg', N_arc_span_deg);
log_msg(fid_log, 'edge_offset_deg=%.6f deg', edge_offset_deg);
log_msg(fid_log, 'd_eq/lambda=%.8f', d_eq_over_lambda);
log_msg(fid_log, 'bw_eq=%.6f deg', bw_eq);
log_msg(fid_log, 'proto6 replay params: N_64=%d, d_64=%.6f m, fc_64=%.3g Hz, lambda_64=%.8f m, bw_64=%.3f deg, theta_c_64=%.3f deg, K_fbss_64=%d', ...
    N_64, d_64, fc_64, lambda_64, bw_64, theta_c_64, K_fbss_64);
log_msg(fid_log, 'col_select=%s within the 65-column working sector', mat2str(col_select));
log_msg(fid_log, 'selected global cols=%s', mat2str(arrInfo.colsAct(col_select)));
log_msg(fid_log, 'selected relative phi first/last = %.6f / %.6f deg', ...
    arrInfo.phiActRel(col_select(1)), arrInfo.phiActRel(col_select(end)));
log_msg(fid_log, 'pos_xyz first=[%.8f %.8f %.8f] m', pos_xyz(1, 1), pos_xyz(1, 2), pos_xyz(1, 3));
log_msg(fid_log, 'pos_xyz last =[%.8f %.8f %.8f] m', pos_xyz(end, 1), pos_xyz(end, 2), pos_xyz(end, 3));

assert(abs(arc_dist - 2*pi*0.4/192) / (2*pi*0.4/192) < 0.01, 'arc_dist geometry check failed.');
assert(arc_over_lambda >= 0.4 && arc_over_lambda <= 0.5, 'arc/lambda geometry check failed.');
assert(abs(subArc_span_deg - 120) / 120 < 0.01, 'subArc_span_deg geometry check failed.');
assert(abs(N_arc_span_deg - 58.125) / 58.125 < 0.01, 'N_arc_span_deg geometry check failed.');
assert(abs(edge_offset_deg - 29.0625) / 29.0625 < 0.01, 'edge_offset_deg geometry check failed.');
assert(abs(d_eq_over_lambda - arc_over_lambda) < 1e-12, 'd_eq/lambda geometry check failed.');
assert(abs(bw_eq - 5.45) / 5.45 < 0.01, 'bw_eq geometry check failed.');
log_msg(fid_log, 'Layer 1 passed.');

log_msg(fid_log, '');
log_msg(fid_log, 'Layer 2 fully in-phase single-sample sanity check');
log_msg(fid_log, 'Local sector phase reference: cylindrical y is premultiplied by conj(A_ref) for azCtr=%.3f deg.', azCtr_deg);
log_msg(fid_log, 'Source model: coherent equal-power deterministic pair, s1 == s2, no phase offset.');
sep_factor_sanity = 5;
snr_sanity = 28;
theta_sep_sanity = bw_eq / sep_factor_sanity;
theta_a_sanity = theta_c - theta_sep_sanity/2;
theta_b_sanity = theta_c + theta_sep_sanity/2;
unit_a = [cosd(el_a)*cosd(theta_a_sanity), cosd(el_a)*sind(theta_a_sanity), sind(el_a)];
unit_b = [cosd(el_b)*cosd(theta_b_sanity), cosd(el_b)*sind(theta_b_sanity), sind(el_b)];
A_a = exp(-j * 2*pi / cfg.arr.lambda * pos_xyz * unit_a.');
A_b = exp(-j * 2*pi / cfg.arr.lambda * pos_xyz * unit_b.');
y_clean = conj(A_ref) .* (A_a * s1 + A_b * s2);
rng(base_seed, 'twister');
noise_power = mean(abs(y_clean(:)).^2) / 10^(snr_sanity / 10);
noise = sqrt(noise_power / 2) * (randn(size(y_clean)) + j * randn(size(y_clean)));
y = y_clean + noise;
[doa_sanity, dbg_sanity] = doa_root_music_array(y, K_fbss, cfg.arr.lambda, d_eq, Lc);
sanity_err = max(abs(sort(doa_sanity) - sort([theta_a_sanity, theta_b_sanity])));
sanity_cyl_ok = all(isfinite(doa_sanity)) && sanity_err < 0.2;
log_msg(fid_log, 'Cylindrical root sanity: pass=%d, doa=[%.4f, %.4f], true=[%.4f, %.4f], max_err=%.4f deg, lambda2_over_noise=%.4g', ...
    sanity_cyl_ok, doa_sanity(1), doa_sanity(2), theta_a_sanity, theta_b_sanity, sanity_err, dbg_sanity.lambda2_over_noise);
if ~sanity_cyl_ok
    diag_cyl_sanity = root_music_diagnostic_local(y, K_fbss, cfg.arr.lambda, d_eq);
    log_root_diagnostic(fid_log, 'sanity_cylindrical_root_music_proto10', base_seed, diag_cyl_sanity);
end

A_a_ula_sanity = exp(-j * 2*pi * d_eq * (0:N_arc-1).' * sind(theta_a_sanity) / cfg.arr.lambda);
A_b_ula_sanity = exp(-j * 2*pi * d_eq * (0:N_arc-1).' * sind(theta_b_sanity) / cfg.arr.lambda);
y_clean_ula_sanity = A_a_ula_sanity * s1 + A_b_ula_sanity * s2;
rng(base_seed, 'twister');
noise_power_ula_sanity = mean(abs(y_clean_ula_sanity(:)).^2) / 10^(snr_sanity / 10);
noise_ula_sanity = sqrt(noise_power_ula_sanity / 2) * (randn(size(y_clean_ula_sanity)) + j * randn(size(y_clean_ula_sanity)));
y_ula_sanity = y_clean_ula_sanity + noise_ula_sanity;
[doa_ula_sanity, dbg_ula_sanity] = doa_root_music_array(y_ula_sanity, K_fbss, cfg.arr.lambda, d_eq, Lc);
sanity_ula_err = max(abs(sort(doa_ula_sanity) - sort([theta_a_sanity, theta_b_sanity])));
sanity_ula_ok = all(isfinite(doa_ula_sanity)) && sanity_ula_err < 0.2;
log_msg(fid_log, 'Pure ULA N=32 sanity: pass=%d, doa=[%.4f, %.4f], true=[%.4f, %.4f], max_err=%.4f deg, lambda2_over_noise=%.4g', ...
    sanity_ula_ok, doa_ula_sanity(1), doa_ula_sanity(2), theta_a_sanity, theta_b_sanity, sanity_ula_err, dbg_ula_sanity.lambda2_over_noise);
if ~sanity_ula_ok
    diag_ula_sanity = root_music_diagnostic_local(y_ula_sanity, K_fbss, cfg.arr.lambda, d_eq);
    log_root_diagnostic(fid_log, 'sanity_pure_ula_root_music_reference', base_seed, diag_ula_sanity);
end

theta_sep_64_sanity = bw_64 / sep_factor_sanity;
theta_a_64_sanity = theta_c_64 - theta_sep_64_sanity/2;
theta_b_64_sanity = theta_c_64 + theta_sep_64_sanity/2;
A_a_64_sanity = exp(-j * 2*pi * pos_N64 * sind(theta_a_64_sanity) / lambda_64);
A_b_64_sanity = exp(-j * 2*pi * pos_N64 * sind(theta_b_64_sanity) / lambda_64);
y_clean_64_sanity = A_a_64_sanity * s1_64 + A_b_64_sanity * s2_64;
rng(base_seed, 'twister');
noise_power_64_sanity = mean(abs(y_clean_64_sanity(:)).^2) / 10^(snr_sanity / 10);
noise_64_sanity = sqrt(noise_power_64_sanity / 2) * (randn(size(y_clean_64_sanity)) + j * randn(size(y_clean_64_sanity)));
y_64_sanity = y_clean_64_sanity + noise_64_sanity;
[doa_64_sanity, dbg_64_sanity] = doa_root_music_array(y_64_sanity, K_fbss_64, lambda_64, d_64, Lc);
sanity_64_err = max(abs(sort(doa_64_sanity) - sort([theta_a_64_sanity, theta_b_64_sanity])));
sanity_64_ok = all(isfinite(doa_64_sanity)) && sanity_64_err < 0.05;
log_msg(fid_log, 'Pure ULA N=64 proto6 replay sanity: pass=%d, doa=[%.4f, %.4f], true=[%.4f, %.4f], max_err=%.4f deg, lambda2_over_noise=%.4g', ...
    sanity_64_ok, doa_64_sanity(1), doa_64_sanity(2), theta_a_64_sanity, theta_b_64_sanity, sanity_64_err, dbg_64_sanity.lambda2_over_noise);
if ~sanity_64_ok
    diag_64_sanity = root_music_diagnostic_local(y_64_sanity, K_fbss_64, lambda_64, d_64);
    log_root_diagnostic(fid_log, 'sanity_pure_ula_root_music_64ch_proto6_replay', base_seed, diag_64_sanity);
end

nsep = numel(sep_factor_list);
nsnr = numel(snr_list);
raw_success_count = zeros(nroutes, nsep, nsnr);
tol_success_count = zeros(nroutes, nsep, nsnr);
tol_success_count_rel = zeros(nroutes, nsep, nsnr);
rmse_sum_sqerr = zeros(nroutes, nsep, nsnr);
rmse_valid_count = zeros(nroutes, nsep, nsnr);
sum_num_peaks = zeros(nroutes, nsep, nsnr);
est_sum = zeros(nroutes, nsep, nsnr, Lc);
lambda2_over_noise_sum = zeros(nroutes, nsep, nsnr);
lambda2_count = zeros(nroutes, nsep, nsnr);
degraded_sample_count = zeros(nroutes, nsep, nsnr);

theta_sep_deg = nan(nsep, 1);
theta_a_deg = nan(nsep, 1);
theta_b_deg = nan(nsep, 1);
debug_samples = cell(nsep, nsnr);

log_msg(fid_log, '');
log_msg(fid_log, 'Layer 3 full fair comparison starts');
log_msg(fid_log, 'sep_factor_list=%s', mat2str(sep_factor_list));
log_msg(fid_log, 'snr_list=%s, Metkl=%d, T_snap=%d, tol_deg=%.3f, tol_rel_ratio=%.2f', ...
    mat2str(snr_list), Metkl, T_snap, tol_deg, tol_rel_ratio);
log_msg(fid_log, 'K_fbss=%d, M_full=%d, center_beam_count=%d, search_scale_B=%.2f, base_seed=%d', ...
    K_fbss, M_full, center_beam_count, search_scale_B, base_seed);

tic;
for iSep = 1:nsep
    sep_factor = sep_factor_list(iSep);
    theta_sep = bw_eq / sep_factor;
    theta_a = theta_c - theta_sep / 2;
    theta_b = theta_c + theta_sep / 2;
    target_theta = [theta_a, theta_b];
    tol_deg_rel = tol_rel_ratio * theta_sep;
    theta_search_B = search_scale_B * theta_sep;
    routeB_beam_span = 1.5 * theta_search_B;
    [beam_grid_full, beam_grid_center, Tk] = build_centerT_from_center_local( ...
        mean(target_theta), routeB_beam_span, M_full, center_beam_count, posK, cfg.arr.lambda);

    theta_sep_deg(iSep) = theta_sep;
    theta_a_deg(iSep) = theta_a;
    theta_b_deg(iSep) = theta_b;

    unit_a = [cosd(el_a)*cosd(theta_a), cosd(el_a)*sind(theta_a), sind(el_a)];
    unit_b = [cosd(el_b)*cosd(theta_b), cosd(el_b)*sind(theta_b), sind(el_b)];
    A_a_cyl = exp(-j * 2*pi / cfg.arr.lambda * pos_xyz * unit_a.');
    A_b_cyl = exp(-j * 2*pi / cfg.arr.lambda * pos_xyz * unit_b.');
    y_clean_cyl = conj(A_ref) .* (A_a_cyl * s1 + A_b_cyl * s2);

    A_a_ula = exp(-j * 2*pi * d_eq * (0:N_arc-1).' * sind(theta_a) / cfg.arr.lambda);
    A_b_ula = exp(-j * 2*pi * d_eq * (0:N_arc-1).' * sind(theta_b) / cfg.arr.lambda);
    y_clean_ula = A_a_ula * s1 + A_b_ula * s2;

    log_msg(fid_log, 'sep_factor=%d, theta_sep=%.6f deg, theta_a=%.6f deg, theta_b=%.6f deg, tol_rel=%.6f deg', ...
        sep_factor, theta_sep, theta_a, theta_b, tol_deg_rel);

    for iSNR = 1:nsnr
        snr_db = snr_list(iSNR);
        noise_power_cyl = mean(abs(y_clean_cyl(:)).^2) / 10^(snr_db / 10);
        noise_power_ula = mean(abs(y_clean_ula(:)).^2) / 10^(snr_db / 10);

        for metkl_num = 1:Metkl
            seed_now = base_seed + 100000*iSep + 1000*iSNR + metkl_num;

            rng(seed_now, 'twister');
            noise_cyl = sqrt(noise_power_cyl / 2) * (randn(size(y_clean_cyl)) + j * randn(size(y_clean_cyl)));
            y_cyl = y_clean_cyl + noise_cyl;

            rng(seed_now, 'twister');
            noise_ula = sqrt(noise_power_ula / 2) * (randn(size(y_clean_ula)) + j * randn(size(y_clean_ula)));
            y_ula = y_clean_ula + noise_ula;

            [doa_grid_cyl, num_peaks_grid] = doa_grid_music_ula_local( ...
                y_cyl, K_fbss, Tk, mean(target_theta), theta_search_B, cfg.arr.lambda, d_eq, Lc);
            [doa_root_cyl, debug_root_cyl] = doa_root_music_array(y_cyl, K_fbss, cfg.arr.lambda, d_eq, Lc);
            [doa_root_ula, debug_root_ula] = doa_root_music_array(y_ula, K_fbss, cfg.arr.lambda, d_eq, Lc);

            doa_all = {doa_grid_cyl, doa_root_cyl, doa_root_ula};
            num_peaks_all = [num_peaks_grid, double(all(isfinite(doa_root_cyl))) * Lc, double(all(isfinite(doa_root_ula))) * Lc];
            debug_all = {struct('lambda2_over_noise', NaN), debug_root_cyl, debug_root_ula};
            y_all = {y_cyl, y_cyl, y_ula};
            lambda_all = [cfg.arr.lambda, cfg.arr.lambda, cfg.arr.lambda];
            d_all = [d_eq, d_eq, d_eq];
            K_all = [K_fbss, K_fbss, K_fbss];

            for iroute = 1:nroutes
                doa_now = doa_all{iroute};
                raw_ok = all(isfinite(doa_now));
                tol_ok_abs = is_valid_doa_success(doa_now, target_theta, tol_deg);
                tol_ok_rel = is_valid_doa_success(doa_now, target_theta, tol_deg_rel);
                doa_degraded = true;

                if raw_ok
                    raw_success_count(iroute, iSep, iSNR) = raw_success_count(iroute, iSep, iSNR) + 1;
                    doa_sorted = sort(doa_now(:).');
                    target_sorted = sort(target_theta(:).');
                    err = doa_sorted - target_sorted;
                    doa_degraded = max(abs(err)) > 1.0;
                    rmse_sum_sqerr(iroute, iSep, iSNR) = rmse_sum_sqerr(iroute, iSep, iSNR) + sum(err.^2);
                    rmse_valid_count(iroute, iSep, iSNR) = rmse_valid_count(iroute, iSep, iSNR) + 1;
                    est_sum(iroute, iSep, iSNR, :) = squeeze(est_sum(iroute, iSep, iSNR, :)).' + doa_sorted;
                end

                if doa_degraded
                    degraded_sample_count(iroute, iSep, iSNR) = degraded_sample_count(iroute, iSep, iSNR) + 1;
                    if iroute >= 2
                        diag_now = root_music_diagnostic_local(y_all{iroute}, K_all(iroute), lambda_all(iroute), d_all(iroute));
                        log_degraded_sample(fid_log, route_names{iroute}, seed_now, sep_factor, snr_db, ...
                            metkl_num, target_theta, doa_now, diag_now);
                    else
                        log_degraded_grid_sample(fid_log, route_names{iroute}, seed_now, sep_factor, snr_db, ...
                            metkl_num, target_theta, doa_now);
                    end
                end

                if tol_ok_abs
                    tol_success_count(iroute, iSep, iSNR) = tol_success_count(iroute, iSep, iSNR) + 1;
                end

                if tol_ok_rel
                    tol_success_count_rel(iroute, iSep, iSNR) = tol_success_count_rel(iroute, iSep, iSNR) + 1;
                end

                sum_num_peaks(iroute, iSep, iSNR) = sum_num_peaks(iroute, iSep, iSNR) + num_peaks_all(iroute);

                if isfield(debug_all{iroute}, 'lambda2_over_noise') && isfinite(debug_all{iroute}.lambda2_over_noise)
                    lambda2_over_noise_sum(iroute, iSep, iSNR) = lambda2_over_noise_sum(iroute, iSep, iSNR) + ...
                        debug_all{iroute}.lambda2_over_noise;
                    lambda2_count(iroute, iSep, iSNR) = lambda2_count(iroute, iSep, iSNR) + 1;
                end
            end

            if metkl_num == 1
                sample = struct();
                sample.seed_now = seed_now;
                sample.sep_factor = sep_factor;
                sample.theta_sep_deg = theta_sep;
                sample.snr_db = snr_db;
                sample.target_theta = target_theta;
                sample.tol_deg_rel = tol_deg_rel;
                sample.beam_grid_full = beam_grid_full;
                sample.beam_grid_center = beam_grid_center;
                sample.doa_grid_cyl = doa_grid_cyl;
                sample.doa_root_cyl = doa_root_cyl;
                sample.doa_root_ula = doa_root_ula;
                sample.debug_root_cyl = debug_root_cyl;
                sample.debug_root_ula = debug_root_ula;
                debug_samples{iSep, iSNR} = sample;
            end
        end
    end

    partial_path = fullfile(result_dir, 'step8_5_cylindrical_arc_proto10_result_partial.mat');
    save(partial_path, ...
        'route_names', 'sep_factor_list', 'snr_list', 'theta_sep_deg', 'theta_a_deg', 'theta_b_deg', ...
        'raw_success_count', 'tol_success_count', 'tol_success_count_rel', ...
        'rmse_sum_sqerr', 'rmse_valid_count', 'sum_num_peaks', 'est_sum', ...
        'lambda2_over_noise_sum', 'lambda2_count', 'degraded_sample_count', 'debug_samples');

    log_msg(fid_log, 'sep_factor=%d finished, elapsed=%.1f s', sep_factor, toc);
end

raw_success_rate = raw_success_count / Metkl;
tol_success_rate = tol_success_count / Metkl;
tol_success_rate_rel = tol_success_count_rel / Metkl;
mean_num_peaks = sum_num_peaks / Metkl;
rmse = sqrt(rmse_sum_sqerr ./ max(rmse_valid_count, 1) / Lc);
rmse(rmse_valid_count == 0) = NaN;
lambda2_over_noise = lambda2_over_noise_sum ./ max(lambda2_count, 1);
lambda2_over_noise(lambda2_count == 0) = NaN;

mean_az_a_est = nan(nroutes, nsep, nsnr);
mean_az_b_est = nan(nroutes, nsep, nsnr);
mean_bias_deg = nan(nroutes, nsep, nsnr);
max_bias_deg = nan(nroutes, nsep, nsnr);
for iroute = 1:nroutes
    for iSep = 1:nsep
        for iSNR = 1:nsnr
            count_now = rmse_valid_count(iroute, iSep, iSNR);
            if count_now > 0
                mean_pair = squeeze(est_sum(iroute, iSep, iSNR, :)).' / count_now;
                mean_az_a_est(iroute, iSep, iSNR) = mean_pair(1);
                mean_az_b_est(iroute, iSep, iSNR) = mean_pair(2);
                bias_pair = mean_pair - [theta_a_deg(iSep), theta_b_deg(iSep)];
                mean_bias_deg(iroute, iSep, iSNR) = mean(bias_pair);
                max_bias_deg(iroute, iSep, iSNR) = max(abs(bias_pair));
            end
        end
    end
end

snr90 = nan(nroutes, nsep);
snr90_rel = nan(nroutes, nsep);
for iroute = 1:nroutes
    for iSep = 1:nsep
        idx_abs = find(squeeze(tol_success_rate(iroute, iSep, :)) >= 0.9, 1, 'first');
        if ~isempty(idx_abs)
            snr90(iroute, iSep) = snr_list(idx_abs);
        end
        idx_rel = find(squeeze(tol_success_rate_rel(iroute, iSep, :)) >= 0.9, 1, 'first');
        if ~isempty(idx_rel)
            snr90_rel(iroute, iSep) = snr_list(idx_rel);
        end
    end
end

nsep64 = numel(sep_factor_list_64);
nsnr64 = numel(snr_list_64);
raw_success_count_64 = zeros(nsep64, nsnr64);
tol_success_count_64 = zeros(nsep64, nsnr64);
tol_success_count_rel_64 = zeros(nsep64, nsnr64);
rmse_sum_sqerr_64 = zeros(nsep64, nsnr64);
rmse_valid_count_64 = zeros(nsep64, nsnr64);
sum_num_peaks_64 = zeros(nsep64, nsnr64);
est_sum_64 = zeros(nsep64, nsnr64, Lc);
lambda2_over_noise_sum_64 = zeros(nsep64, nsnr64);
lambda2_count_64 = zeros(nsep64, nsnr64);
degraded_sample_count_64 = zeros(nsep64, nsnr64);
theta_sep_deg_64 = nan(nsep64, 1);
theta_a_deg_64 = nan(nsep64, 1);
theta_b_deg_64 = nan(nsep64, 1);
debug_samples_64 = cell(nsep64, nsnr64);

log_msg(fid_log, '');
log_msg(fid_log, 'Layer 3 proto6 replay starts: %s', route_name_64);
log_msg(fid_log, 'sep_factor_list_64=%s, snr_list_64=%s, N_64=%d, K_fbss_64=%d, d_64=%.6f, lambda_64=%.8f, bw_64=%.3f, theta_c_64=%.3f', ...
    mat2str(sep_factor_list_64), mat2str(snr_list_64), N_64, K_fbss_64, d_64, lambda_64, bw_64, theta_c_64);

for iSep64 = 1:nsep64
    sep_factor_64 = sep_factor_list_64(iSep64);
    theta_sep_64 = bw_64 / sep_factor_64;
    theta_a_64 = theta_c_64 - theta_sep_64 / 2;
    theta_b_64 = theta_c_64 + theta_sep_64 / 2;
    target_theta_64 = [theta_a_64, theta_b_64];
    tol_deg_rel_64 = tol_rel_ratio * theta_sep_64;
    theta_sep_deg_64(iSep64) = theta_sep_64;
    theta_a_deg_64(iSep64) = theta_a_64;
    theta_b_deg_64(iSep64) = theta_b_64;

    A_a_64 = exp(-j * 2*pi * pos_N64 * sind(theta_a_64) / lambda_64);
    A_b_64 = exp(-j * 2*pi * pos_N64 * sind(theta_b_64) / lambda_64);
    y_clean_64 = A_a_64 * s1_64 + A_b_64 * s2_64;

    log_msg(fid_log, 'proto6 replay sep_factor=%d, theta_sep=%.6f deg, theta_a=%.6f deg, theta_b=%.6f deg, tol_rel=%.6f deg', ...
        sep_factor_64, theta_sep_64, theta_a_64, theta_b_64, tol_deg_rel_64);

    for iSNR64 = 1:nsnr64
        snr_db_64 = snr_list_64(iSNR64);
        noise_power_64 = mean(abs(y_clean_64(:)).^2) / 10^(snr_db_64 / 10);

        for metkl_num = 1:Metkl
            seed_64 = base_seed + 100000 * (iSep64 + 100) + 1000 * iSNR64 + metkl_num;
            rng(seed_64, 'twister');
            noise_64 = sqrt(noise_power_64 / 2) * (randn(size(y_clean_64)) + j * randn(size(y_clean_64)));
            y_64 = y_clean_64 + noise_64;

            [doa_64, dbg_64] = doa_root_music_array(y_64, K_fbss_64, lambda_64, d_64, Lc);
            raw_ok_64 = all(isfinite(doa_64));
            tol_ok_abs_64 = is_valid_doa_success(doa_64, target_theta_64, tol_deg);
            tol_ok_rel_64 = is_valid_doa_success(doa_64, target_theta_64, tol_deg_rel_64);
            doa_degraded_64 = true;

            if raw_ok_64
                raw_success_count_64(iSep64, iSNR64) = raw_success_count_64(iSep64, iSNR64) + 1;
                doa_sorted_64 = sort(doa_64(:).');
                target_sorted_64 = sort(target_theta_64(:).');
                err_64 = doa_sorted_64 - target_sorted_64;
                doa_degraded_64 = max(abs(err_64)) > 1.0;
                rmse_sum_sqerr_64(iSep64, iSNR64) = rmse_sum_sqerr_64(iSep64, iSNR64) + sum(err_64.^2);
                rmse_valid_count_64(iSep64, iSNR64) = rmse_valid_count_64(iSep64, iSNR64) + 1;
                est_sum_64(iSep64, iSNR64, :) = squeeze(est_sum_64(iSep64, iSNR64, :)).' + doa_sorted_64;
            end

            if doa_degraded_64
                degraded_sample_count_64(iSep64, iSNR64) = degraded_sample_count_64(iSep64, iSNR64) + 1;
                diag_64 = root_music_diagnostic_local(y_64, K_fbss_64, lambda_64, d_64);
                log_degraded_sample(fid_log, route_name_64, seed_64, sep_factor_64, snr_db_64, ...
                    metkl_num, target_theta_64, doa_64, diag_64);
            end

            if tol_ok_abs_64
                tol_success_count_64(iSep64, iSNR64) = tol_success_count_64(iSep64, iSNR64) + 1;
            end

            if tol_ok_rel_64
                tol_success_count_rel_64(iSep64, iSNR64) = tol_success_count_rel_64(iSep64, iSNR64) + 1;
            end

            sum_num_peaks_64(iSep64, iSNR64) = sum_num_peaks_64(iSep64, iSNR64) + double(raw_ok_64) * Lc;

            if isfinite(dbg_64.lambda2_over_noise)
                lambda2_over_noise_sum_64(iSep64, iSNR64) = lambda2_over_noise_sum_64(iSep64, iSNR64) + dbg_64.lambda2_over_noise;
                lambda2_count_64(iSep64, iSNR64) = lambda2_count_64(iSep64, iSNR64) + 1;
            end

            if metkl_num == 1
                sample64 = struct();
                sample64.seed_64 = seed_64;
                sample64.sep_factor = sep_factor_64;
                sample64.theta_sep_deg = theta_sep_64;
                sample64.snr_db = snr_db_64;
                sample64.target_theta = target_theta_64;
                sample64.tol_deg_rel = tol_deg_rel_64;
                sample64.doa_64 = doa_64;
                sample64.debug_64 = dbg_64;
                debug_samples_64{iSep64, iSNR64} = sample64;
            end
        end
    end
end

raw_success_rate_64 = raw_success_count_64 / Metkl;
tol_success_rate_64 = tol_success_count_64 / Metkl;
tol_success_rate_rel_64 = tol_success_count_rel_64 / Metkl;
mean_num_peaks_64 = sum_num_peaks_64 / Metkl;
rmse_64 = sqrt(rmse_sum_sqerr_64 ./ max(rmse_valid_count_64, 1) / Lc);
rmse_64(rmse_valid_count_64 == 0) = NaN;
lambda2_over_noise_64 = lambda2_over_noise_sum_64 ./ max(lambda2_count_64, 1);
lambda2_over_noise_64(lambda2_count_64 == 0) = NaN;

mean_az_a_est_64 = nan(nsep64, nsnr64);
mean_az_b_est_64 = nan(nsep64, nsnr64);
mean_bias_deg_64 = nan(nsep64, nsnr64);
max_bias_deg_64 = nan(nsep64, nsnr64);
for iSep64 = 1:nsep64
    for iSNR64 = 1:nsnr64
        count_now_64 = rmse_valid_count_64(iSep64, iSNR64);
        if count_now_64 > 0
            mean_pair_64 = squeeze(est_sum_64(iSep64, iSNR64, :)).' / count_now_64;
            mean_az_a_est_64(iSep64, iSNR64) = mean_pair_64(1);
            mean_az_b_est_64(iSep64, iSNR64) = mean_pair_64(2);
            bias_pair_64 = mean_pair_64 - [theta_a_deg_64(iSep64), theta_b_deg_64(iSep64)];
            mean_bias_deg_64(iSep64, iSNR64) = mean(bias_pair_64);
            max_bias_deg_64(iSep64, iSNR64) = max(abs(bias_pair_64));
        end
    end
end

snr90_64 = nan(1, nsep64);
snr90_rel_64 = nan(1, nsep64);
for iSep64 = 1:nsep64
    idx_abs_64 = find(tol_success_rate_64(iSep64, :) >= 0.9, 1, 'first');
    if ~isempty(idx_abs_64)
        snr90_64(iSep64) = snr_list_64(idx_abs_64);
    end
    idx_rel_64 = find(tol_success_rate_rel_64(iSep64, :) >= 0.9, 1, 'first');
    if ~isempty(idx_rel_64)
        snr90_rel_64(iSep64) = snr_list_64(idx_rel_64);
    end
end

for iSep = 1:nsep
    log_msg(fid_log, 'sep_factor=%d | SNR90 abs01 -> grid=%s, cyl-root=%s, pure-ula=%s', ...
        sep_factor_list(iSep), fmt_snr90(snr90(1, iSep)), fmt_snr90(snr90(2, iSep)), fmt_snr90(snr90(3, iSep)));
    log_msg(fid_log, 'sep_factor=%d | SNR90 rel025 -> grid=%s, cyl-root=%s, pure-ula=%s', ...
        sep_factor_list(iSep), fmt_snr90(snr90_rel(1, iSep)), fmt_snr90(snr90_rel(2, iSep)), fmt_snr90(snr90_rel(3, iSep)));
end
for iSep64 = 1:nsep64
    log_msg(fid_log, 'proto6 replay sep_factor=%d | SNR90 abs01=%s, rel025=%s, degraded_rate_at_snr90=%s', ...
        sep_factor_list_64(iSep64), fmt_snr90(snr90_64(iSep64)), fmt_snr90(snr90_rel_64(iSep64)), ...
        fmt_degraded_at_snr(snr90_64(iSep64), snr_list_64, degraded_sample_count_64(iSep64, :), Metkl));
end

idx_sep10 = find(sep_factor_list == 10, 1);
idx_snr24 = find(snr_list == 24, 1);
layer3_axis_rate = tol_success_rate(2, idx_sep10, idx_snr24);
layer3_axis_ok = layer3_axis_rate >= 0.85;
layer3_baseline_ok = true;
for iSep = 1:nsep
    root_snr90 = snr90(2, iSep);
    grid_snr90 = snr90(1, iSep);
    if isfinite(root_snr90) && isfinite(grid_snr90)
        layer3_baseline_ok = layer3_baseline_ok && ~(root_snr90 > grid_snr90 + 4);
    elseif ~isfinite(root_snr90) && isfinite(grid_snr90)
        layer3_baseline_ok = false;
    end
end

hist_sep = [7, 8, 9, 10];
hist_snr90 = [14, 16, 20, 22];
layer3_proto6_replay_ok = true;
for kk = 1:numel(hist_sep)
    idx64 = find(sep_factor_list_64 == hist_sep(kk), 1);
    layer3_proto6_replay_ok = layer3_proto6_replay_ok && isfinite(snr90_64(idx64)) && abs(snr90_64(idx64) - hist_snr90(kk)) <= 2;
end

layer3_pure32_gap_ok = true;
pure32_gap_db = nan(1, nsep);
for iSep = 1:nsep
    if isfinite(snr90(2, iSep)) && isfinite(snr90(3, iSep))
        pure32_gap_db(iSep) = abs(snr90(3, iSep) - snr90(2, iSep));
        layer3_pure32_gap_ok = layer3_pure32_gap_ok && pure32_gap_db(iSep) <= 4;
    else
        layer3_pure32_gap_ok = false;
    end
end

snr90_advantage_vs_grid_db = squeeze(snr90(1, :) - snr90(2, :));
layer3_cyl_vs_grid_any_advantage = any(isfinite(snr90_advantage_vs_grid_db) & snr90_advantage_vs_grid_db >= 2);

log_msg(fid_log, '');
log_msg(fid_log, 'Layer 3 acceptance checks');
log_msg(fid_log, 'sep_factor=10, SNR=24 dB, cylindrical_root tol_rate_abs01=%.6f, pass=%d', ...
    layer3_axis_rate, layer3_axis_ok);
log_msg(fid_log, 'cylindrical_root SNR90 not worse than grid baseline by >4 dB, pass=%d', layer3_baseline_ok);
log_msg(fid_log, '3a proto6 replay SNR90 vs historical [14,16,20,22] dB with +/-2 dB tolerance, pass=%d', layer3_proto6_replay_ok);
log_msg(fid_log, '3c pure ULA N=32 and cylindrical root SNR90 gap <=4 dB for every sep_factor, pass=%d, gaps=%s dB', ...
    layer3_pure32_gap_ok, mat2str(pure32_gap_db, 4));
log_msg(fid_log, '3d cylindrical root SNR90 advantage vs grid baseline by sep_factor=%s dB, any >=2 dB pass=%d (report-only)', ...
    mat2str(snr90_advantage_vs_grid_db, 4), layer3_cyl_vs_grid_any_advantage);

params = struct();
params.base_seed = base_seed;
params.sep_factor_list = sep_factor_list;
params.snr_list = snr_list;
params.Metkl = Metkl;
params.T_snap = T_snap;
params.tol_deg = tol_deg;
params.tol_rel_ratio = tol_rel_ratio;
params.azCtr_deg = azCtr_deg;
params.N_arc = N_arc;
params.iel_select = iel_select;
params.col_select = col_select;
params.global_col_select = arrInfo.colsAct(col_select);
params.K_fbss = K_fbss;
params.M_full = M_full;
params.center_beam_count = center_beam_count;
params.search_scale_B = search_scale_B;
params.el_a = el_a;
params.el_b = el_b;
params.theta_c = theta_c;
params.d_eq = d_eq;
params.bw_eq = bw_eq;
params.arc_dist = arc_dist;
params.arc_over_lambda = arc_over_lambda;
params.subArc_span_deg = subArc_span_deg;
params.N_arc_span_deg = N_arc_span_deg;
params.edge_offset_deg = edge_offset_deg;
params.local_sector_phase_reference = true;
params.source_model = 'fully in-phase coherent pair, s1 == s2';
params.sanity_cyl_ok = sanity_cyl_ok;
params.sanity_ula_ok = sanity_ula_ok;
params.sanity_64_ok = sanity_64_ok;
params.N_64 = N_64;
params.d_64 = d_64;
params.fc_64 = fc_64;
params.lambda_64 = lambda_64;
params.bw_64 = bw_64;
params.theta_c_64 = theta_c_64;
params.K_fbss_64 = K_fbss_64;
params.sep_factor_list_64 = sep_factor_list_64;
params.snr_list_64 = snr_list_64;

summary_path = fullfile(result_dir, 'step8_5_cylindrical_arc_proto10_summary.csv');
write_summary_csv(summary_path, route_names, sep_factor_list, snr_list, theta_sep_deg, theta_a_deg, theta_b_deg, ...
    raw_success_count, tol_success_count, tol_success_count_rel, raw_success_rate, tol_success_rate, tol_success_rate_rel, ...
    rmse, rmse_valid_count, mean_num_peaks, snr90, snr90_rel, mean_bias_deg, max_bias_deg, ...
    mean_az_a_est, mean_az_b_est, lambda2_over_noise, degraded_sample_count, ...
    route_name_64, sep_factor_list_64, snr_list_64, theta_sep_deg_64, theta_a_deg_64, theta_b_deg_64, ...
    raw_success_count_64, tol_success_count_64, tol_success_count_rel_64, raw_success_rate_64, tol_success_rate_64, ...
    tol_success_rate_rel_64, rmse_64, rmse_valid_count_64, mean_num_peaks_64, snr90_64, snr90_rel_64, ...
    mean_bias_deg_64, max_bias_deg_64, mean_az_a_est_64, mean_az_b_est_64, lambda2_over_noise_64, degraded_sample_count_64);

keypoints_path = fullfile(result_dir, 'step8_5_cylindrical_arc_proto10_keypoints.csv');
write_keypoints_csv(keypoints_path, route_names, sep_factor_list, snr_list, raw_success_rate, tol_success_rate, ...
    tol_success_rate_rel, rmse, mean_num_peaks, mean_bias_deg, max_bias_deg, mean_az_a_est, mean_az_b_est, snr90, ...
    degraded_sample_count, route_name_64, sep_factor_list_64, snr_list_64, raw_success_rate_64, tol_success_rate_64, ...
    tol_success_rate_rel_64, rmse_64, mean_num_peaks_64, mean_bias_deg_64, max_bias_deg_64, ...
    mean_az_a_est_64, mean_az_b_est_64, snr90_64, degraded_sample_count_64);

mat_path = fullfile(result_dir, 'step8_5_cylindrical_arc_proto10_result.mat');
save(mat_path, ...
    'params', 'route_names', 'sep_factor_list', 'snr_list', 'theta_sep_deg', 'theta_a_deg', 'theta_b_deg', ...
    'raw_success_count', 'tol_success_count', 'tol_success_count_rel', ...
    'raw_success_rate', 'tol_success_rate', 'tol_success_rate_rel', ...
    'rmse_sum_sqerr', 'rmse_valid_count', 'rmse', 'sum_num_peaks', 'mean_num_peaks', ...
    'est_sum', 'mean_bias_deg', 'max_bias_deg', 'mean_az_a_est', 'mean_az_b_est', ...
    'snr90', 'snr90_rel', 'lambda2_over_noise', 'degraded_sample_count', ...
    'route_name_64', 'sep_factor_list_64', 'snr_list_64', 'theta_sep_deg_64', 'theta_a_deg_64', 'theta_b_deg_64', ...
    'raw_success_count_64', 'tol_success_count_64', 'tol_success_count_rel_64', ...
    'raw_success_rate_64', 'tol_success_rate_64', 'tol_success_rate_rel_64', ...
    'rmse_sum_sqerr_64', 'rmse_valid_count_64', 'rmse_64', 'sum_num_peaks_64', 'mean_num_peaks_64', ...
    'est_sum_64', 'mean_bias_deg_64', 'max_bias_deg_64', 'mean_az_a_est_64', 'mean_az_b_est_64', ...
    'snr90_64', 'snr90_rel_64', 'lambda2_over_noise_64', 'degraded_sample_count_64', ...
    'debug_samples', 'debug_samples_64', 'pos_xyz', 'arrInfo');

plot_tol_success(fullfile(result_dir, 'step8_5_cylindrical_arc_proto10_tol_success.png'), ...
    route_names, sep_factor_list, snr_list, tol_success_rate);
plot_rmse(fullfile(result_dir, 'step8_5_cylindrical_arc_proto10_rmse.png'), ...
    route_names, sep_factor_list, snr_list, rmse);
plot_mean_bias(fullfile(result_dir, 'step8_5_cylindrical_arc_proto10_mean_bias.png'), ...
    sep_factor_list, snr_list, mean_bias_deg, route_names);
plot_geometry_diag(fullfile(result_dir, 'step8_5_cylindrical_arc_proto10_geometry_diag.png'), ...
    cfg, arrInfo, col_select, iel_select, pos_xyz, N_arc, d_eq, azCtr_deg);
plot_proto6_replay(fullfile(result_dir, 'step8_5_cylindrical_arc_proto10_proto6_replay.png'), ...
    sep_factor_list_64, snr90_64, hist_snr90, tol_success_rate_64, snr_list_64);

idx_snr30 = find(snr_list == 30, 1);
bias_cyl_30 = squeeze(mean_bias_deg(2, :, idx_snr30));
bias_ula_30 = squeeze(mean_bias_deg(3, :, idx_snr30));
rho_theta = 0:0.1:60;
rho_curve = calc_rho_curve(pos_xyz, N_arc, d_eq, cfg.arr.lambda, azCtr_deg, rho_theta);
idx_rho_099 = find(rho_curve < 0.99, 1, 'first');
idx_rho_095 = find(rho_curve < 0.95, 1, 'first');
if isempty(idx_rho_099)
    rho099_deg = NaN;
else
    rho099_deg = rho_theta(idx_rho_099);
end
if isempty(idx_rho_095)
    rho095_deg = NaN;
else
    rho095_deg = rho_theta(idx_rho_095);
end

log_msg(fid_log, '');
log_msg(fid_log, 'Layer 4 mismatch boundary diagnostics');
log_msg(fid_log, 'mean_bias at 30 dB, cylindrical root by sep_factor=%s', mat2str(bias_cyl_30.', 6));
log_msg(fid_log, 'mean_bias at 30 dB, pure ULA root by sep_factor=%s', mat2str(bias_ula_30.', 6));
log_msg(fid_log, 'rho(theta) falls below 0.99 at theta=%s deg and below 0.95 at theta=%s deg.', fmt_num(rho099_deg), fmt_num(rho095_deg));
log_msg(fid_log, 'Generated figures: tol_success, rmse, mean_bias, geometry_diag, proto6_replay.');
log_msg(fid_log, 'Result directory: %s', result_dir);

disp('Step 08.5 Prototype 10.A finished.');
disp('route_names =');
disp(route_names);
disp('snr90_abs01 =');
disp(snr90);
disp('snr90_rel025 =');
disp(snr90_rel);
disp('snr90_64_abs01 =');
disp(snr90_64);
disp('result_dir =');
disp(result_dir);

function [doa_value, num_peaks] = doa_grid_music_ula_local( ...
    y, K, Tk, angle_recv, search_width_deg, lambda, d, Lc)
    j = sqrt(-1);
    [~, T_snap] = size(y);
    posK = d * (0:K-1).';

    Rxx = y * y' / T_snap;
    Rxx = 0.5 * (Rxx + Rxx');
    Rss = mssp_array_fb(Rxx, K);
    Rss = 0.5 * (Rss + Rss');

    Rb = Tk.' * Rss * conj(Tk);
    Rb = 0.5 * (Rb + Rb');

    [E, D] = eig(Rb);
    eigvals = real(diag(D));
    [~, idx] = sort(eigvals, 'descend');
    E = E(:, idx);
    if size(E, 2) <= Lc
        doa_value = nan(1, Lc);
        num_peaks = 0;
        return;
    end
    En = E(:, Lc+1:end);

    angle_search = angle_recv - search_width_deg/2 : 0.01 : angle_recv + search_width_deg/2;
    Pmu = zeros(1, numel(angle_search));
    for ii = 1:numel(angle_search)
        theta = angle_search(ii);
        aK = exp(-j * 2*pi/lambda * posK * sind(theta));
        bK = Tk.' * aK;
        den = real(bK' * En * En' * bK);
        num = real(bK' * bK);
        Pmu(ii) = num / max(den, eps);
    end

    [~, peak_ind] = FindLocalPeak_NoEdge_Fun(abs(Pmu));
    num_peaks = numel(peak_ind);
    if num_peaks < Lc
        doa_value = nan(1, Lc);
        return;
    end
    doa_value = sort(angle_search(peak_ind(1:Lc)));
end

function [beam_grid_full_deg, beam_grid_center_deg, Tk] = build_centerT_from_center_local( ...
    center_deg, routeB_beam_span, M_full, center_beam_count, posK, lambda)
    j = sqrt(-1);
    beam_grid_full_deg = linspace( ...
        center_deg - routeB_beam_span / 2, ...
        center_deg + routeB_beam_span / 2, ...
        M_full + 1);

    full_beam_count = numel(beam_grid_full_deg);
    center_idx = floor((full_beam_count + 1) / 2);
    half_left = floor((center_beam_count - 1) / 2);
    half_right = center_beam_count - half_left - 1;
    center_indices = (center_idx - half_left):(center_idx + half_right);
    beam_grid_center_deg = beam_grid_full_deg(center_indices);

    Wcenter = exp(j * 2*pi/lambda * posK * sind(beam_grid_center_deg));
    [Tk, ~] = qr(Wcenter, 0);
end

function write_summary_csv(path_out, route_names, sep_factor_list, snr_list, theta_sep_deg, theta_a_deg, theta_b_deg, ...
    raw_success_count, tol_success_count, tol_success_count_rel, raw_success_rate, tol_success_rate, tol_success_rate_rel, ...
    rmse, rmse_valid_count, mean_num_peaks, snr90, snr90_rel, mean_bias_deg, max_bias_deg, ...
    mean_az_a_est, mean_az_b_est, lambda2_over_noise, degraded_sample_count, ...
    route_name_64, sep_factor_list_64, snr_list_64, theta_sep_deg_64, theta_a_deg_64, theta_b_deg_64, ...
    raw_success_count_64, tol_success_count_64, tol_success_count_rel_64, raw_success_rate_64, tol_success_rate_64, ...
    tol_success_rate_rel_64, rmse_64, rmse_valid_count_64, mean_num_peaks_64, snr90_64, snr90_rel_64, ...
    mean_bias_deg_64, max_bias_deg_64, mean_az_a_est_64, mean_az_b_est_64, lambda2_over_noise_64, degraded_sample_count_64)

    fid = fopen(path_out, 'w');
    cleanup = onCleanup(@() fclose(fid));
    fprintf(fid, ['route_name,sep_factor,theta_sep_deg,theta_a_deg,theta_b_deg,snr_db,' ...
        'raw_success_count,tol_success_count,tol_success_count_rel,' ...
        'raw_success_rate,tol_success_rate,tol_success_rate_rel,' ...
        'rmse_deg,rmse_valid_count,mean_num_peaks,' ...
        'snr90_db,snr90_rel_db,mean_bias_deg,max_bias_deg,mean_az_a_est,mean_az_b_est,lambda2_over_noise,degraded_sample_count\n']);

    nroutes = numel(route_names);
    for iroute = 1:nroutes
        for iSep = 1:numel(sep_factor_list)
            for iSNR = 1:numel(snr_list)
                fprintf(fid, ['%s,%d,%.6f,%.6f,%.6f,%d,' ...
                    '%d,%d,%d,%.6f,%.6f,%.6f,%.6f,%d,%.6f,' ...
                    '%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%d\n'], ...
                    route_names{iroute}, sep_factor_list(iSep), theta_sep_deg(iSep), theta_a_deg(iSep), theta_b_deg(iSep), ...
                    snr_list(iSNR), raw_success_count(iroute, iSep, iSNR), ...
                    tol_success_count(iroute, iSep, iSNR), tol_success_count_rel(iroute, iSep, iSNR), ...
                    raw_success_rate(iroute, iSep, iSNR), tol_success_rate(iroute, iSep, iSNR), ...
                    tol_success_rate_rel(iroute, iSep, iSNR), rmse(iroute, iSep, iSNR), ...
                    rmse_valid_count(iroute, iSep, iSNR), mean_num_peaks(iroute, iSep, iSNR), ...
                    snr90(iroute, iSep), snr90_rel(iroute, iSep), ...
                    mean_bias_deg(iroute, iSep, iSNR), max_bias_deg(iroute, iSep, iSNR), ...
                    mean_az_a_est(iroute, iSep, iSNR), mean_az_b_est(iroute, iSep, iSNR), ...
                    lambda2_over_noise(iroute, iSep, iSNR), degraded_sample_count(iroute, iSep, iSNR));
            end
        end
    end

    for iSep64 = 1:numel(sep_factor_list_64)
        for iSNR64 = 1:numel(snr_list_64)
            fprintf(fid, ['%s,%d,%.6f,%.6f,%.6f,%d,' ...
                '%d,%d,%d,%.6f,%.6f,%.6f,%.6f,%d,%.6f,' ...
                '%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%d\n'], ...
                route_name_64, sep_factor_list_64(iSep64), theta_sep_deg_64(iSep64), ...
                theta_a_deg_64(iSep64), theta_b_deg_64(iSep64), snr_list_64(iSNR64), ...
                raw_success_count_64(iSep64, iSNR64), tol_success_count_64(iSep64, iSNR64), ...
                tol_success_count_rel_64(iSep64, iSNR64), raw_success_rate_64(iSep64, iSNR64), ...
                tol_success_rate_64(iSep64, iSNR64), tol_success_rate_rel_64(iSep64, iSNR64), ...
                rmse_64(iSep64, iSNR64), rmse_valid_count_64(iSep64, iSNR64), mean_num_peaks_64(iSep64, iSNR64), ...
                snr90_64(iSep64), snr90_rel_64(iSep64), mean_bias_deg_64(iSep64, iSNR64), ...
                max_bias_deg_64(iSep64, iSNR64), mean_az_a_est_64(iSep64, iSNR64), ...
                mean_az_b_est_64(iSep64, iSNR64), lambda2_over_noise_64(iSep64, iSNR64), ...
                degraded_sample_count_64(iSep64, iSNR64));
        end
    end
end

function write_keypoints_csv(path_out, route_names, sep_factor_list, snr_list, raw_success_rate, tol_success_rate, ...
    tol_success_rate_rel, rmse, mean_num_peaks, mean_bias_deg, max_bias_deg, mean_az_a_est, mean_az_b_est, snr90, ...
    degraded_sample_count, route_name_64, sep_factor_list_64, snr_list_64, raw_success_rate_64, tol_success_rate_64, ...
    tol_success_rate_rel_64, rmse_64, mean_num_peaks_64, mean_bias_deg_64, max_bias_deg_64, ...
    mean_az_a_est_64, mean_az_b_est_64, snr90_64, degraded_sample_count_64)

    fid = fopen(path_out, 'w');
    cleanup = onCleanup(@() fclose(fid));
    fprintf(fid, 'route_name,sep_factor,snr_db,raw_success_rate,tol_success_rate_abs01,tol_success_rate_rel025,rmse_deg,mean_num_peaks,mean_bias_deg,max_bias_deg,mean_az_a_est,mean_az_b_est,degraded_sample_count\n');

    for iSep = 1:numel(sep_factor_list)
        key_snr_list = unique([min(snr_list), 24, 30, snr90(:, iSep).']);
        key_snr_list = key_snr_list(isfinite(key_snr_list));
        key_snr_list = key_snr_list(key_snr_list >= min(snr_list) & key_snr_list <= max(snr_list));
        key_snr_list = sort(key_snr_list);
        for is = 1:numel(key_snr_list)
            snr_key = key_snr_list(is);
            idx = find(snr_list == snr_key, 1, 'first');
            if isempty(idx)
                continue;
            end
            for iroute = 1:numel(route_names)
                fprintf(fid, '%s,%d,%d,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%d\n', ...
                    route_names{iroute}, sep_factor_list(iSep), snr_key, raw_success_rate(iroute, iSep, idx), ...
                    tol_success_rate(iroute, iSep, idx), tol_success_rate_rel(iroute, iSep, idx), ...
                    rmse(iroute, iSep, idx), mean_num_peaks(iroute, iSep, idx), ...
                    mean_bias_deg(iroute, iSep, idx), max_bias_deg(iroute, iSep, idx), ...
                    mean_az_a_est(iroute, iSep, idx), mean_az_b_est(iroute, iSep, idx), ...
                    degraded_sample_count(iroute, iSep, idx));
            end
        end
    end

    for iSep64 = 1:numel(sep_factor_list_64)
        key_snr_list_64 = unique([min(snr_list_64), 24, 28, snr90_64(iSep64)]);
        key_snr_list_64 = key_snr_list_64(isfinite(key_snr_list_64));
        key_snr_list_64 = key_snr_list_64(key_snr_list_64 >= min(snr_list_64) & key_snr_list_64 <= max(snr_list_64));
        key_snr_list_64 = sort(key_snr_list_64);
        for is = 1:numel(key_snr_list_64)
            snr_key = key_snr_list_64(is);
            idx = find(snr_list_64 == snr_key, 1, 'first');
            if isempty(idx)
                continue;
            end
            fprintf(fid, '%s,%d,%d,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%d\n', ...
                route_name_64, sep_factor_list_64(iSep64), snr_key, raw_success_rate_64(iSep64, idx), ...
                tol_success_rate_64(iSep64, idx), tol_success_rate_rel_64(iSep64, idx), ...
                rmse_64(iSep64, idx), mean_num_peaks_64(iSep64, idx), ...
                mean_bias_deg_64(iSep64, idx), max_bias_deg_64(iSep64, idx), ...
                mean_az_a_est_64(iSep64, idx), mean_az_b_est_64(iSep64, idx), ...
                degraded_sample_count_64(iSep64, idx));
        end
    end
end

function plot_tol_success(path_out, route_names, sep_factor_list, snr_list, tol_success_rate)
    fig = figure('Visible', 'off', 'Position', [80, 80, 1100, 900]);
    for iSep = 1:numel(sep_factor_list)
        subplot(numel(sep_factor_list), 1, iSep);
        for iroute = 1:numel(route_names)
            plot(snr_list, squeeze(tol_success_rate(iroute, iSep, :)), 'LineWidth', 1.1);
            hold on
        end
        hold off
        grid on
        ylim([-0.05, 1.05]);
        ylabel('tol rate');
        title(sprintf('Prototype10 tol success, bw/%d', sep_factor_list(iSep)));
        if iSep == 1
            legend(route_names, 'Location', 'best', 'Interpreter', 'none');
        end
    end
    xlabel('SNR (dB)');
    saveas(fig, path_out);
    close(fig);
end

function plot_rmse(path_out, route_names, sep_factor_list, snr_list, rmse)
    fig = figure('Visible', 'off', 'Position', [80, 80, 1100, 900]);
    for iSep = 1:numel(sep_factor_list)
        subplot(numel(sep_factor_list), 1, iSep);
        for iroute = 1:numel(route_names)
            plot(snr_list, squeeze(rmse(iroute, iSep, :)), 'LineWidth', 1.1);
            hold on
        end
        hold off
        grid on
        ylabel('RMSE (deg)');
        title(sprintf('Prototype10 RMSE, bw/%d', sep_factor_list(iSep)));
        if iSep == 1
            legend(route_names, 'Location', 'best', 'Interpreter', 'none');
        end
    end
    xlabel('SNR (dB)');
    saveas(fig, path_out);
    close(fig);
end

function plot_mean_bias(path_out, sep_factor_list, snr_list, mean_bias_deg, route_names)
    idx_snr30 = find(snr_list == 30, 1);
    fig = figure('Visible', 'off', 'Position', [100, 100, 900, 520]);
    plot(sep_factor_list, squeeze(mean_bias_deg(2, :, idx_snr30)), '-o', 'LineWidth', 1.3);
    hold on
    plot(sep_factor_list, squeeze(mean_bias_deg(3, :, idx_snr30)), '-s', 'LineWidth', 1.3);
    yline(0, '--k');
    hold off
    grid on
    xlabel('sep factor');
    ylabel('mean(est - true) (deg)');
    title('Mean bias at 30 dB');
    legend({route_names{2}, route_names{3}}, 'Location', 'best', 'Interpreter', 'none');
    xticks(sep_factor_list);
    saveas(fig, path_out);
    close(fig);
end

function plot_geometry_diag(path_out, cfg, arrInfo, col_select, iel_select, pos_xyz, N_arc, d_eq, azCtr_deg)
    fig = figure('Visible', 'off', 'Position', [100, 100, 1250, 900]);
    phi = arrInfo.phiCol;
    x_all = cfg.arr.R * cosd(phi);
    y_all = cfg.arr.R * sind(phi);
    x_work = arrInfo.XAct(:, iel_select);
    y_work = arrInfo.YAct(:, iel_select);
    x_doa = pos_xyz(:, 1);
    y_doa = pos_xyz(:, 2);

    subplot(2, 2, 1);
    plot(x_all, y_all, '.', 'Color', [0.65 0.65 0.65]);
    hold on
    plot(x_work, y_work, 'r.', 'MarkerSize', 12);
    plot(x_doa, y_doa, 'b.', 'MarkerSize', 15);
    axis equal
    grid on
    xlabel('X (m)');
    ylabel('Y (m)');
    title('Top view: full array / work sector / DOA arc');
    legend({'192 columns', '65 work columns', '32 DOA columns'}, 'Location', 'best');

    subplot(2, 2, 2);
    z = arrInfo.zRow;
    plot(zeros(size(z)), z, 'k.', 'MarkerSize', 12);
    hold on
    plot(0, z(iel_select), 'bo', 'MarkerSize', 9, 'LineWidth', 1.5);
    hold off
    grid on
    xlabel('layer marker');
    ylabel('Z (m)');
    title(sprintf('Side view: selected layer iel=%d', iel_select));
    ylim([min(z)-0.02, max(z)+0.02]);

    subplot(2, 2, 3);
    plot(x_doa, y_doa, 'bo-', 'LineWidth', 1.1);
    hold on
    n_centered = ((0:N_arc-1).' - (N_arc-1)/2);
    tangent = [-sind(azCtr_deg), cosd(azCtr_deg)];
    center_xy = [cfg.arr.R*cosd(azCtr_deg), cfg.arr.R*sind(azCtr_deg)];
    xy_ula = center_xy + n_centered * d_eq .* tangent;
    plot(xy_ula(:, 1), xy_ula(:, 2), 'k--', 'LineWidth', 1.2);
    hold off
    axis equal
    grid on
    xlabel('X (m)');
    ylabel('Y (m)');
    title('DOA arc vs equivalent ULA line');
    legend({'cylindrical arc', 'equivalent ULA'}, 'Location', 'best');

    subplot(2, 2, 4);
    theta_grid = 0:0.1:60;
    rho = calc_rho_curve(pos_xyz, N_arc, d_eq, cfg.arr.lambda, azCtr_deg, theta_grid);
    plot(theta_grid, rho, 'LineWidth', 1.3);
    grid on
    xlabel('azimuth offset from boresight (deg)');
    ylabel('rho');
    ylim([0, 1.02]);
    title('Cylindrical steering vs ULA steering correlation');
    saveas(fig, path_out);
    close(fig);
end

function rho = calc_rho_curve(pos_xyz, N_arc, d_eq, lambda, azCtr_deg, theta_grid)
    j = sqrt(-1);
    n = (0:N_arc-1).';
    u0 = [cosd(azCtr_deg), sind(azCtr_deg), 0];
    rho = zeros(size(theta_grid));
    for ii = 1:numel(theta_grid)
        theta = theta_grid(ii);
        u = [cosd(azCtr_deg + theta), sind(azCtr_deg + theta), 0];
        a_cyl = exp(-j * 2*pi/lambda * pos_xyz * (u - u0).');
        a_ula = exp(-j * 2*pi/lambda * d_eq * n * sind(theta));
        rho(ii) = abs(a_cyl' * a_ula) / (norm(a_cyl) * norm(a_ula));
    end
end

function plot_proto6_replay(path_out, sep_factor_list_64, snr90_64, hist_snr90, tol_success_rate_64, snr_list_64)
    fig = figure('Visible', 'off', 'Position', [120, 120, 980, 620]);
    subplot(2, 1, 1);
    plot(sep_factor_list_64, snr90_64, '-or', 'LineWidth', 1.4, 'MarkerSize', 6);
    hold on
    plot(sep_factor_list_64, hist_snr90, '--ks', 'LineWidth', 1.2, 'MarkerSize', 5);
    hold off
    grid on
    xlabel('sep factor');
    ylabel('SNR90 abs01 (dB)');
    title('64-channel ULA proto6 replay vs historical SNR90');
    legend({'v2 replay', 'historical proto6 [14 16 20 22]'}, 'Location', 'best');
    xticks(sep_factor_list_64);

    subplot(2, 1, 2);
    imagesc(snr_list_64, sep_factor_list_64, tol_success_rate_64);
    set(gca, 'YDir', 'normal');
    colorbar;
    caxis([0, 1]);
    xlabel('SNR (dB)');
    ylabel('sep factor');
    title('64-channel ULA proto6 replay tol success rate');
    saveas(fig, path_out);
    close(fig);
end

function diag_info = root_music_diagnostic_local(y, K, lambda, d)
    j = sqrt(-1); %#ok<NASGU>
    T_snap = size(y, 2);
    Rxx = (y * y') / T_snap;
    Rxx = 0.5 * (Rxx + Rxx');
    Rss = mssp_array_fb(Rxx, K);
    Rss = 0.5 * (Rss + Rss');

    [V, Dm] = eig(Rss);
    eigvals = real(diag(Dm));
    [eigvals, idx] = sort(eigvals, 'descend');
    V = V(:, idx);
    Lc = 2;
    if size(V, 2) <= Lc
        rts = [];
    else
        En = V(:, Lc+1:end);
        C = En * En';
        M = K;
        poly_coeffs = zeros(1, 2 * M - 1);
        lag_list = -(M-1):(M-1);
        for ii = 1:numel(lag_list)
            poly_coeffs(ii) = sum(diag(C, lag_list(ii)));
        end
        rts = roots(fliplr(poly_coeffs));
    end

    diag_info = struct();
    diag_info.Rss_eig_first5 = eigvals(1:min(5, numel(eigvals))).';
    diag_info.root_abs = abs(rts(:)).';
    diag_info.root_angle = angle(rts(:)).';
    diag_info.lambda = lambda;
    diag_info.d = d;
end

function log_degraded_sample(fid, route_name, seed_now, sep_factor, snr_db, metkl_num, target_theta, doa_now, diag_info)
    fprintf(fid, ['DEGRADED route=%s seed=%d sep_factor=%d snr_db=%d metkl=%d ' ...
        'target=[%.6f %.6f] doa=[%.6f %.6f]\n'], ...
        route_name, seed_now, sep_factor, snr_db, metkl_num, target_theta(1), target_theta(2), doa_now(1), doa_now(2));
    fprintf(fid, '  Rss eig first5=%s\n', mat2str(diag_info.Rss_eig_first5, 8));
    fprintf(fid, '  root abs=%s\n', mat2str(diag_info.root_abs, 5));
    fprintf(fid, '  root angle=%s\n', mat2str(diag_info.root_angle, 5));
end

function log_degraded_grid_sample(fid, route_name, seed_now, sep_factor, snr_db, metkl_num, target_theta, doa_now)
    fprintf(fid, ['DEGRADED route=%s seed=%d sep_factor=%d snr_db=%d metkl=%d ' ...
        'target=[%.6f %.6f] doa=[%.6f %.6f] (grid route: no Root-MUSIC root diagnostic)\n'], ...
        route_name, seed_now, sep_factor, snr_db, metkl_num, target_theta(1), target_theta(2), doa_now(1), doa_now(2));
end

function log_root_diagnostic(fid, label, seed_now, diag_info)
    fprintf(fid, 'DIAGNOSTIC label=%s seed=%d\n', label, seed_now);
    fprintf(fid, '  Rss eig first5=%s\n', mat2str(diag_info.Rss_eig_first5, 8));
    fprintf(fid, '  root abs=%s\n', mat2str(diag_info.root_abs, 5));
    fprintf(fid, '  root angle=%s\n', mat2str(diag_info.root_angle, 5));
end

function out = fmt_snr90(x)
    if isfinite(x)
        out = sprintf('%.0f dB', x);
    else
        out = 'NaN';
    end
end

function out = fmt_degraded_at_snr(snr90_now, snr_list_now, degraded_counts_now, Metkl)
    if ~isfinite(snr90_now)
        out = 'NaN';
        return;
    end
    idx = find(snr_list_now == snr90_now, 1, 'first');
    if isempty(idx)
        out = 'NaN';
        return;
    end
    out = sprintf('%.4f', degraded_counts_now(idx) / Metkl);
end

function out = fmt_num(x)
    if isfinite(x)
        out = sprintf('%.2f', x);
    else
        out = 'NaN';
    end
end

function log_msg(fid, fmt, varargin)
    line = sprintf(fmt, varargin{:});
    fprintf('%s\n', line);
    fprintf(fid, '%s\n', line);
end
