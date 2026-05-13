% ML algorithm validation: subarray processing
clc
close all
clear

%% Data preparation
arrayNum = 256;
numSnapshots = 130;
len_data_re0 = 1962;

% Create synthetic element-space echo data for validating the subarray ML flow.
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

% Band-limit each channel and then perform pulse compression.
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

%% Subarray ML
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

    % Synthesize one output channel for each non-overlapping 4-element subarray.
    for s = 1 : size(pc_out, 3)
        temp = reshape(pc_out(:, :, s), len_data_re0, arrayNum);
        for idx = 1 : num_subarray
            temp1 = temp(:, (idx - 1) * arrayNum_sub + 1 : arrayNum_sub * idx);
            sr_DBF(:, idx, s) = temp1 * A;
        end
    end

    estm_data_in_temp = sr_DBF(Rang_cell, :, :);
    estm_data_in = reshape(estm_data_in_temp, num_subarray, numSnapshots);

    % Two-target subarray-space ML estimate over the full 256-element aperture.
    R_value_256_4 = ML_AP_zizhen(estm_data_in, beamc, d, lamda, 256, A);
    temp256(ii, :) = R_value_256_4;
    rmse256_4(ii) = sqrt(sum((R_value_256_4 - theta) .^ 2, 2) / 2);

    % Repeat the same estimate using only the first 64-element aperture.
    R_ML_64_4 = ML_AP_zizhen(estm_data_in(1 : array_num / arrayNum_sub, :), beamc, d, lamda, array_num, A);
    temp64(ii, :) = R_ML_64_4;
    rmse64_4(ii) = sqrt(sum((R_ML_64_4 - theta) .^ 2, 2) / 2);
end

figure()
plot(beam_Lin, rmse256_4, 'r*-', beam_Lin, rmse64_4, 'b*-')
xlabel('Subarray synthesis angle')
ylabel('RMSE')
legend('256-element subarray processing', '64-element subarray processing')
title('Subarray ML result under different synthesis angles')
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
rangeEnvelope = exp(-((fastTime - centerCell) / 18) .^ 2);

datayuanzhu = complex(zeros(lenData, arrayNum, numSnapshots));
for s = 1 : numSnapshots
    signalVec = complex(zeros(lenData, arrayNum));
    phaseDrift = exp(1j * 2 * pi * 0.01 * s);
    for k = 1 : numel(targetAngles)
        steering = exp(-1j * 2 * pi * d / lamda * (0 : arrayNum - 1) * sind(targetAngles(k)));
        waveform = snapshotAmp(k) * phaseDrift * rangeEnvelope * exp(1j * 2 * pi * rand());
        signalVec = signalVec + waveform * steering;
    end
    noise = 0.05 * (randn(lenData, arrayNum) + 1j * randn(lenData, arrayNum));
    datayuanzhu(:, :, s) = signalVec + noise;
end
end
