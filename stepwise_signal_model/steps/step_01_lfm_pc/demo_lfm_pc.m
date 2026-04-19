thisDir = fileparts(mfilename('fullpath'));
run(fullfile(thisDir, '..', '..', 'setup_paths.m'));

clc;
clear;
close all;

% 第 1-2 步：LFM、单通道回波、距离向脉压。
cfg = sim_cfg();
rng(cfg.sim.seed);

% 发射 LFM 与单目标回波。
[sTx, tTx] = tx_lfm(cfg.wf);
[echoMat, truth] = echo_1ch(cfg);

% 未加窗和 Hamming 窗脉压结果。
[pcMatNoWin, pcInfoNoWin] = pc_range(echoMat, sTx, cfg, false);
[pcMat, pcInfo] = pc_range(echoMat, sTx, cfg, true);

% 快时间对应距离轴。
rAxis = truth.rAxis;
% 目标理论时延对应的最近采样点。
[~, idxRef] = min(abs(cfg.wf.tFast - truth.taup(1)));

fprintf('第 1-2 步：LFM 与脉压验证\n');
fprintf('当前为等效单通道回波，还没有接入阵元维和波束形成。\n');
fprintf('fc = %.2f GHz\n', cfg.arr.fc / 1e9);
fprintf('B = %.2f MHz\n', cfg.wf.B / 1e6);
fprintf('Tp = %.2f us\n', cfg.wf.Tp * 1e6);
fprintf('Fs = %.2f MHz\n', cfg.wf.Fs / 1e6);
fprintf('PRI = %.2f us, 脉冲数 = %d\n', cfg.wf.PRI * 1e6, cfg.wf.Np);
fprintf('距离分辨率 = %.3f m\n', cfg.wf.dR);
fprintf('最大无模糊距离 = %.3f m\n', cfg.wf.Rmax);
fprintf('目标初始距离 = %.3f m\n', cfg.tgt.R0);
fprintf('目标速度 = %.3f m/s\n', cfg.tgt.v);
fprintf('初始往返时延 = %.3f us\n', truth.taup(1) * 1e6);
fprintf('目标多普勒 = %.3f Hz\n', truth.fd);
fprintf('脉冲间相位步进 = %.3f rad\n', truth.dphi);

fprintf('\n距离向脉压结果\n');
fprintf('加窗方式 = %s\n', pcInfo.winName);
fprintf('脉压峰值距离 = %.3f m\n', pcInfo.rPk);
fprintf('峰值距离误差 = %.3f m\n', pcInfo.peakErr);
fprintf('-3 dB 主瓣宽度 = %.3f m\n', pcInfo.bw3dB);
fprintf('理论距离分辨率 = %.3f m\n', pcInfo.dR);

figure('Name', '第 1 步 LFM 基础建模');
tiledlayout(3, 1, 'TileSpacing', 'compact', 'Padding', 'compact');

nexttile;
% 图1：发射复基带 LFM 的实部和虚部。
plot(tTx * 1e6, real(sTx), 'LineWidth', 1.1);
hold on;
plot(tTx * 1e6, imag(sTx), '--', 'LineWidth', 1.1);
grid on;
xlabel('时间 (us)');
ylabel('幅值');
title('发射复基带 LFM 波形');
legend('实部', '虚部', 'Location', 'best');

nexttile;
% 图2：脉压前回波幅值。
plot(rAxis, abs(echoMat(1, :)), 'LineWidth', 1.1);
hold on;
plot(rAxis, abs(echoMat(end, :)), '--', 'LineWidth', 1.1);
xline(truth.Rp(1), ':', 'LineWidth', 1.0);
xline(truth.Rp(end), ':', 'LineWidth', 1.0);
xlim([truth.Rp(1) - 250, truth.Rp(1) + 250]);
grid on;
xlabel('距离 (m)');
ylabel('幅值');
title('脉压前回波幅值');
legend('第 1 个脉冲', '最后 1 个脉冲', '真实距离', 'Location', 'best');

nexttile;
% 图3：目标距离处的慢时间相位。
plot(cfg.wf.tSlow * 1e3, unwrap(angle(echoMat(:, idxRef))), 'o-', 'LineWidth', 1.1, 'MarkerSize', 4);
grid on;
xlabel('慢时间 (ms)');
ylabel('展开相位 (rad)');
title('目标距离处的慢时间相位');

figure('Name', '第 2 步 距离向脉压验证');
tiledlayout(2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');

nexttile;
% 图4：脉压后距离像。
plot(pcInfo.rAxis, abs(pcMat(1, :)), 'LineWidth', 1.1);
hold on;
plot(pcInfo.rAxis, abs(pcMat(end, :)), '--', 'LineWidth', 1.1);
xline(cfg.tgt.R0, ':', 'LineWidth', 1.0);
xline(pcInfo.rPk, '--r', 'LineWidth', 1.0);
xlim([cfg.tgt.R0 - 60, cfg.tgt.R0 + 60]);
grid on;
xlabel('距离 (m)');
ylabel('幅值');
title('脉压后距离像');
legend('第 1 个脉冲', '最后 1 个脉冲', '真实距离', '脉压峰值', 'Location', 'best');

nexttile;
% 图5：脉压后主瓣局部放大，并标出 -3 dB 主瓣宽度。
plot(pcInfo.rAxis, pcInfo.profDb, 'LineWidth', 1.1);
hold on;
yline(-3, ':k', 'LineWidth', 1.0);
xline(pcInfo.left3dB, '--k', 'LineWidth', 1.0);
xline(pcInfo.right3dB, '--k', 'LineWidth', 1.0);
xline(cfg.tgt.R0, ':', 'LineWidth', 1.0);
xlim([cfg.tgt.R0 - 20, cfg.tgt.R0 + 20]);
ylim([-40, 2]);
grid on;
xlabel('距离 (m)');
ylabel('归一化幅值 (dB)');
title('-3 dB 主瓣宽度测量');
legend('脉压结果', '-3 dB', '左边界', '右边界', '真实距离', 'Location', 'best');

% 取消注释可查看加窗前后对比。
% figure('Name', '加窗前后对比');
% tiledlayout(2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
% nexttile;
% plot(pcInfoNoWin.rAxis, pcInfoNoWin.profDb, 'LineWidth', 1.1);
% hold on;
% plot(pcInfo.rAxis, pcInfo.profDb, '--', 'LineWidth', 1.1);
% yline(-3, ':k', 'LineWidth', 1.0);
% xline(cfg.tgt.R0, ':', 'LineWidth', 1.0);
% xlim([cfg.tgt.R0 - 20, cfg.tgt.R0 + 20]);
% ylim([-40, 2]);
% grid on;
% xlabel('距离 (m)');
% ylabel('归一化幅值 (dB)');
% title('加窗前后主峰对比');
% legend('未加窗', 'Hamming 窗', '-3 dB', '真实距离', 'Location', 'best');
% nexttile;
% plot(pcInfoNoWin.rAxis, pcInfoNoWin.profDb, 'LineWidth', 1.1);
% hold on;
% plot(pcInfo.rAxis, pcInfo.profDb, '--', 'LineWidth', 1.1);
% xline(cfg.tgt.R0, ':', 'LineWidth', 1.0);
% xlim([cfg.tgt.R0 - 80, cfg.tgt.R0 + 80]);
% ylim([-60, 2]);
% grid on;
% xlabel('距离 (m)');
% ylabel('归一化幅值 (dB)');
% title('加窗前后旁瓣对比');
% legend('未加窗', 'Hamming 窗', '真实距离', 'Location', 'best');

% result 汇总第 1-2 步所有关键中间量，
% 既保留原始回波与真值，也保留加窗/不加窗两套脉压结果，便于后续对比复查。
result = struct();
result.cfg = cfg;
result.sTx = sTx;
result.echoMat = echoMat;
result.truth = truth;
result.pcMat = pcMat;
result.pcInfo = pcInfo;
result.pcMatNoWin = pcMatNoWin;
result.pcInfoNoWin = pcInfoNoWin;

assignin('base', 'step_02_result', result);
