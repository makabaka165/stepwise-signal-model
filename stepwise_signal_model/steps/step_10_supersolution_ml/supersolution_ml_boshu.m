% ML 算法验证：波束级处理
clc
close all
clear

%% 数据准备
arrayNum = 256;
numSnapshots = 130;
len_data_re0 = 1962;

% 生成阵元级回波仿真数据，用于验证波束级 ML 处理流程。
datayuanzhu = create_demo_cube(arrayNum, len_data_re0, numSnapshots);

t1 = 5e-6;
Bs = 30e6;
Ts = 0.025e-6;
mu = -1 * Bs / t1;

j = sqrt(-1);
t = (-t1 / Ts / 2 + 1 / 2 : t1 / Ts / 2 - 1 / 2) * Ts;
s1 = exp(j * mu * pi * (t .* t));
Wnd = hamming(length(s1));
po_coe = fliplr(conj(s1)) .* Wnd.';

pc_pre_temp = zeros(len_data_re0, 1);
datazhenyuan_PrePC = zeros(len_data_re0, arrayNum, numSnapshots);
pc_out1 = zeros(len_data_re0 + length(po_coe) - 1, arrayNum, numSnapshots);

% 对每个阵元通道先限带，再进行脉压处理。
for i = 1 : numSnapshots
    for jj = 1 : arrayNum
        pc_pre = fftshift(fft(datayuanzhu(:, jj, i)));
        pc_pre_temp(:) = 0;
        pc_pre_temp(len_data_re0 / 2 - 300 + 1 : len_data_re0 / 2 + 300) = ...
            pc_pre(len_data_re0 / 2 - 300 + 1 : len_data_re0 / 2 + 300) .* hamming(600);
        datazhenyuan_PrePC(:, jj, i) = ifft(ifftshift(pc_pre_temp));
        pc_out1(:, jj, i) = conv(datazhenyuan_PrePC(:, jj, i), po_coe);
    end
end

pc_out = pc_out1(101 : 2161 - 99, :, :);

freq = 2.7;
lamda = 0.3 / freq;
d = 0.047;
Rang_cell = 707;
theta = [12.7, 14.3];
% ML 阶段只使用选定距离单元上的脉压数据。

%% 256 阵元波束级 ML
M_lin = 16:32;
subarray_num = 256;
win = taylorwin(subarray_num, 25, -40)';
win = win / sqrt(win * win');
N2P = subarray_num / 2 - 1;
position = [d * (-N2P : 0) - d / 2, d * (0 : N2P) + d / 2]';
Rebeamwidth = 2.8;
RecvbeamC = 13.5;
temp256 = zeros(length(M_lin), 2);
rmse256 = zeros(1, length(M_lin));

for ii = 1 : length(M_lin)
    M = M_lin(ii);
    RecvbeamS = RecvbeamC - Rebeamwidth;
    RecvbeamE = RecvbeamC + Rebeamwidth;
    angle_recv = linspace(RecvbeamS, RecvbeamE, M);

    sr_DBF = zeros(len_data_re0, M, numSnapshots);
    A = diag(win) * exp(j * 2 * pi * position / lamda * sin(angle_recv * pi / 180));

    % 将选定孔径内的阵元数据映射为 M 个波束域通道。
    for s = 1 : size(pc_out, 3)
        temp = reshape(pc_out(:, :, s), len_data_re0, arrayNum);
        temp1 = temp(:, 1 : subarray_num);
        sr_DBF(:, :, s) = temp1 * A;
    end

    estm_data_in_temp = sr_DBF(Rang_cell, :, :);
    estm_data_in = reshape(estm_data_in_temp, M, numSnapshots);
    % estm_data_in 对应波束域快拍矩阵 Y_B。

    % 双目标波束级 ML 估计，并与参考角度对计算 RMSE。
    R_value_256_boshu = ML_AP_boshu(estm_data_in, RecvbeamC, d, lamda, 256, A);
    temp256(ii, :) = R_value_256_boshu;
    rmse256(ii) = sqrt(sum((R_value_256_boshu - theta) .^ 2, 2) / 2);
end

figure()
plot(M_lin, rmse256, 'r*-')
xlabel('波束通道数')
ylabel('RMSE')
title('256 阵元波束级 ML 结果')
grid on

%% 64 阵元波束级 ML：不同波束覆盖范围对比
figure()
hold on
M_lin = 4:16;
temp64 = zeros(length(M_lin), 2);
for gridIdx = 1 : 5
    RecvbeamS = RecvbeamC - Rebeamwidth * 0.2 * gridIdx;
    RecvbeamE = RecvbeamC + Rebeamwidth * 0.2 * gridIdx;
    % gridIdx 用于改变波束域基底覆盖的接收角范围。

    subarray_num = 64;
    win = taylorwin(subarray_num, 25, -40)';
    win = win / sqrt(win * win');
    N2P = subarray_num / 2 - 1;
    position = [d * (-N2P : 0) - d / 2, d * (0 : N2P) + d / 2]';

    rmse64 = zeros(1, length(M_lin));

    for ii = 1 : length(M_lin)
        M = M_lin(ii);
        angle_recv = linspace(RecvbeamS, RecvbeamE, M);
        sr_DBF = zeros(len_data_re0, M, numSnapshots);
        A = diag(win) * exp(j * 2 * pi * position / lamda * sin(angle_recv * pi / 180));

        for s = 1 : size(pc_out, 3)
            temp = reshape(pc_out(:, :, s), len_data_re0, arrayNum);
            temp1 = temp(:, 1 : subarray_num);
            sr_DBF(:, :, s) = temp1 * A;
        end

        estm_data_in_temp = sr_DBF(Rang_cell, :, :);
        estm_data_in = reshape(estm_data_in_temp, M, numSnapshots);

        R_value_ML_boshu = ML_AP_boshu(estm_data_in, RecvbeamC, d, lamda, subarray_num, A);
        temp64(ii, :) = R_value_ML_boshu;
        rmse64(ii) = sqrt(sum((R_value_ML_boshu - theta) .^ 2, 2) / 2);
    end

    plot(M_lin, rmse64, 'DisplayName', sprintf('第%d组', gridIdx));
end
xlabel('波束通道数')
ylabel('RMSE')
title('64 阵元波束级 ML 结果')
legend('show')
grid on

function datayuanzhu = create_demo_cube(arrayNum, lenData, numSnapshots)
rng(1);
targetAngles = [12.7, 14.3];
centerCell = 707;
freq = 2.7;
lamda = 0.3 / freq;
d = 0.047;
snapshotAmp = [1.0, 0.8];
fastTime = (0:lenData-1).';
rangeEnvelope1 = exp(-((fastTime - centerCell) / 18) .^ 2);
rangeEnvelope2 = exp(-((fastTime - (centerCell + 2)) / 21) .^ 2);

elemAmpError = 1 + 0.08 * randn(1, arrayNum);
elemPhaseError = exp(1j * deg2rad(6) * randn(1, arrayNum));
elemMismatch = elemAmpError .* elemPhaseError;
% 加入阵元幅相误差，使仿真数据不再与理想模型完全匹配。

datayuanzhu = complex(zeros(lenData, arrayNum, numSnapshots));
for s = 1 : numSnapshots
    signalVec = complex(zeros(lenData, arrayNum));
    phaseDrift1 = exp(1j * 2 * pi * 0.01 * s);
    phaseDrift2 = exp(1j * 2 * pi * (0.017 * s + 0.0004 * s ^ 2));

    steering1 = exp(-1j * 2 * pi * d / lamda * (0 : arrayNum - 1) * sind(targetAngles(1)));
    steering2 = exp(-1j * 2 * pi * d / lamda * (0 : arrayNum - 1) * sind(targetAngles(2) + 0.05 * sin(2 * pi * s / numSnapshots)));
    steering1 = steering1 .* elemMismatch;
    steering2 = steering2 .* conj(elemMismatch);
    % 令第二个目标在快拍间存在轻微角度起伏。

    ampJitter1 = snapshotAmp(1) * (1 + 0.12 * randn());
    ampJitter2 = snapshotAmp(2) * (1 + 0.18 * randn());
    waveform1 = ampJitter1 * phaseDrift1 * rangeEnvelope1 * exp(1j * 2 * pi * rand());
    waveform2 = ampJitter2 * phaseDrift2 * rangeEnvelope2 * exp(1j * 2 * pi * rand());
    signalVec = signalVec + waveform1 * steering1 + waveform2 * steering2;

    clutter = 0.04 * rangeEnvelope1 * exp(1j * 2 * pi * 0.003 * s) * ones(1, arrayNum);
    noise = 0.10 * (randn(lenData, arrayNum) + 1j * randn(lenData, arrayNum));
    % 加入弱相干背景和热噪声。
    datayuanzhu(:, :, s) = signalVec + clutter + noise;
end
end
