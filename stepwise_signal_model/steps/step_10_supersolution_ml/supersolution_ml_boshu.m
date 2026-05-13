% ML algorithm validation: beamspace processing
clc
close all
clear

%% Data preparation
arrayNum = 256;
numSnapshots = 130;
len_data_re0 = 1962;

% Create synthetic element-space echo data for validating the beamspace ML flow.
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

%% 256-array beamspace ML
M_lin = 16:32;
subarray_num = 256;
win = taylorwin(subarray_num, 25, -40)';
win = win / sqrt(win * win');
N2P = subarray_num / 2 - 1;
position = [d * (-N2P : 0) - d / 2, d * (0 : N2P) + d / 2]';
Rebeamwidth = 2 / 8;
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

    % Map the selected element-space aperture into B beamspace channels.
    for s = 1 : size(pc_out, 3)
        temp = reshape(pc_out(:, :, s), len_data_re0, arrayNum);
        temp1 = temp(:, 1 : subarray_num);
        sr_DBF(:, :, s) = temp1 * A;
    end

    estm_data_in_temp = sr_DBF(Rang_cell, :, :);
    estm_data_in = reshape(estm_data_in_temp, M, numSnapshots);

    % Two-target beamspace ML estimate and RMSE against the reference pair.
    R_value_256_boshu = ML_AP_boshu(estm_data_in, RecvbeamC, d, lamda, 256, A);
    temp256(ii, :) = R_value_256_boshu;
    rmse256(ii) = sqrt(sum((R_value_256_boshu - theta) .^ 2, 2) / 2);
end

figure()
plot(M_lin, rmse256, 'r*-')
xlabel('Beamspace channels')
ylabel('RMSE')
title('Beamspace ML result for 256 elements')
grid on

%% 64-array beamspace ML with different beam spans
figure()
hold on
M_lin = 4:16;
temp64 = zeros(5, length(M_lin), 2);
for gridIdx = 1 : 5
    RecvbeamS = RecvbeamC - Rebeamwidth * 0.2 * gridIdx;
    RecvbeamE = RecvbeamC + Rebeamwidth * 0.2 * gridIdx;

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
        temp64(gridIdx, ii, :) = R_value_ML_boshu;
        rmse64(ii) = sqrt(sum((R_value_ML_boshu - theta) .^ 2, 2) / 2);
    end

    plot(M_lin, rmse64, 'DisplayName', sprintf('grid=%d', gridIdx));
end
xlabel('Beamspace channels')
ylabel('RMSE')
title('Beamspace ML result for 64 elements')
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
