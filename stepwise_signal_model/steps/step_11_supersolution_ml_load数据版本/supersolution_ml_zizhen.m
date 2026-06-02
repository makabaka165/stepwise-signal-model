% ML 算法验证：子阵级处理
clc
close all
clear

%% 数据准备
arrayNum = 256;
numSnapshots = 130;
len_data_re0 = 1962;

% 从 MAT 文件中读取阵元级数据。
load datazhenyuan
load startNum %#ok<NASGU>
% 该版本保留已验证的 ML 实现，仅恢复 MAT 数据输入方式。

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

% 对每个通道先限带，再进行脉压处理。
for i = 1 : numSnapshots
    for jj = 1 : arrayNum
        pc_pre = fftshift(fft(datazhenyuan(:, jj, i)));
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
% ML 阶段只使用某一个距离单元上的压缩数据。

%% 子阵级 ML
beamc = 13.5;
beam_width = 2.8;
beam_Lin = beamc - beam_width / 2 : 0.1 : beamc + beam_width / 2;
arrayNum_sub = 4;
array_num = 64;
temp256 = zeros(length(beam_Lin), 2);
temp64 = zeros(length(beam_Lin), 2);
rmse256_4 = zeros(1, length(beam_Lin));
rmse64_4 = zeros(1, length(beam_Lin));

for ii = 1 : length(beam_Lin)
    win = taylorwin(arrayNum_sub, 25, -40)';
    win = win / sqrt(win * win');
    position = d * (0 : arrayNum_sub - 1)';
    angle_recv = beam_Lin(ii);
    A = diag(win) * exp(j * 2 * pi * position / lamda * sin(angle_recv * pi / 180));
    num_subarray = 256 / arrayNum_sub;
    sr_DBF = zeros(len_data_re0, num_subarray, numSnapshots);

    % 对每个不重叠的 4 阵元子阵合成为 1 个输出通道。
    for s = 1 : size(pc_out, 3)
        temp = reshape(pc_out(:, :, s), len_data_re0, arrayNum);
        for idx = 1 : num_subarray
            temp1 = temp(:, (idx - 1) * arrayNum_sub + 1 : arrayNum_sub * idx);
            sr_DBF(:, idx, s) = temp1 * A;
        end
    end

    estm_data_in_temp = sr_DBF(Rang_cell, :, :);
    estm_data_in = reshape(estm_data_in_temp, num_subarray, numSnapshots);
    % estm_data_in 对应子阵域快拍矩阵 Y_S。

    % 双目标子阵级 ML 估计，使用完整 256 阵元孔径。
    R_value_256_4 = ML_AP_zizhen(estm_data_in, beamc, d, lamda, 256, A);
    temp256(ii, :) = R_value_256_4;
    rmse256_4(ii) = sqrt(sum((R_value_256_4 - theta) .^ 2, 2) / 2);

    % 再用前 64 阵元孔径重复同样的估计。
    R_ML_64_4 = ML_AP_zizhen(estm_data_in(1 : array_num / arrayNum_sub, :), beamc, d, lamda, array_num, A);
    temp64(ii, :) = R_ML_64_4;
    rmse64_4(ii) = sqrt(sum((R_ML_64_4 - theta) .^ 2, 2) / 2);
end

figure()
plot(beam_Lin, rmse256_4, 'r*-', beam_Lin, rmse64_4, 'b*-')
xlabel('子阵合成角')
ylabel('均方根误差')
legend('256 阵元子阵处理', '64 阵元子阵处理')
title('不同子阵合成角下的子阵级 ML 结果')
grid on
