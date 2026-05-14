% 新路线：阵元域先空间平滑，再投影到中心截取T波束域进行 MUSIC。
clc
clear all
close all

c = 3e8;
array_num = 64;
fc = 2.7e9;
lamda = c / fc;
d = 0.047;
bw_64 = 50.8 * 1.45 * lamda / (array_num - 1) / d;
bw_64 = roundn(bw_64, -1);
theta_bw = [bw_64/1, bw_64/2, bw_64/3, bw_64/4, bw_64/5, ...
            bw_64/6, bw_64/7, bw_64/8, bw_64/9, bw_64/10];

theta_c = 13;
Tn = 130;
t = linspace(0, 1, Tn);
j = sqrt(-1);
snr = 12;
Metkl = 50;
subarray_num = 59;
M = 32;   % 生成 33 个局部波束
B = 25;   % 中心截取后的波束数量
search_scale = 4;

win = taylorwin(subarray_num, 25, -40)';
win = win / sqrt(win * win');
position = [d * (0:subarray_num-1)]';

% success 统计双峰检测成功次数；
% rmse    统计成功检测样本对应的均方根误差。
center_success = zeros(1, length(theta_bw));
center_rmse = nan(1, length(theta_bw));

for angle_grid_num = 1 : length(theta_bw)
    fprintf('角间隔档位 %d / %d\n', angle_grid_num, length(theta_bw));
    center_sqerr = nan(1, Metkl);

    for metkl_num = 1 : Metkl
        theta_a = theta_c - theta_bw(angle_grid_num) / 2;
        theta_b = theta_c + theta_bw(angle_grid_num) / 2;
        target_theta = [theta_a, theta_b];

        s1 = sqrt(10^(snr / 10)) * exp(j * 2 * pi * fc * t);
        s2 = sqrt(10^(snr / 10)) * exp(j * 2 * pi * fc * t);
        A_a = exp(-j * 2 * pi * d * (0:array_num-1) * sind(theta_a) / lamda);
        A_b = exp(-j * 2 * pi * d * (0:array_num-1) * sind(theta_b) / lamda);

        s11 = A_a.' * s1;
        s21 = A_b.' * s2;
        y = s11 + s21 + (1 / sqrt(2)) * (randn(array_num, Tn) + ...
            j * randn(array_num, Tn));

        % 先截取用于阵元域空间平滑的子阵数据，再构造局部波束投影矩阵。
        y_sub = y(1:subarray_num, :);
        RecvbeamC = (theta_a + theta_b) / 2;
        angle_recv = linspace(theta_c - bw_64 / 2, theta_c + bw_64 / 2, M + 1);
        T_full = diag(win) * exp(j * 2 * pi * position / lamda * sin(angle_recv * pi / 180));

        % 中心截取 T：只保留中间连续的 B 个波束。
        beam_start = floor((size(T_full, 2) - B) / 2) + 1;
        T_center = T_full(:, beam_start:beam_start + B - 1);
        temp_center = DOA_three_music_new_route_centerT( ...
            y_sub, subarray_num, T_center, RecvbeamC, search_scale * theta_bw(angle_grid_num));
        if all(isfinite(temp_center))
            center_success(angle_grid_num) = center_success(angle_grid_num) + 1;
            center_sqerr(metkl_num) = sum((temp_center - target_theta).^2, 2);
        end
    end

    if any(isfinite(center_sqerr))
        center_rmse(angle_grid_num) = sqrt(nansum(center_sqerr) / (2 * sum(isfinite(center_sqerr))));
    end
end

fprintf('\n结果汇总（成功次数 / %d）\n', Metkl);
for angle_grid_num = 1 : length(theta_bw)
    fprintf('bw/%d：中心截取T=%2d，中心截取T均方根误差=%.4f\n', ...
        angle_grid_num, center_success(angle_grid_num), center_rmse(angle_grid_num));
end

figure();
plot(1:length(theta_bw), center_success / Metkl, 'm-s', 'LineWidth', 1.2);
grid on;
xticks(1:length(theta_bw));
xticklabels({'bw/1', 'bw/2', 'bw/3', 'bw/4', 'bw/5', 'bw/6', 'bw/7', 'bw/8', 'bw/9', 'bw/10'});
xlabel('目标角间隔');
ylabel('双峰检测成功率');
legend('中心截取T投影', 'Location', 'best');
title('新路线中心截取T投影的双峰检测成功率');

figure();
plot(1:length(theta_bw), center_rmse, 'm-s', 'LineWidth', 1.2);
grid on;
xticks(1:length(theta_bw));
xticklabels({'bw/1', 'bw/2', 'bw/3', 'bw/4', 'bw/5', 'bw/6', 'bw/7', 'bw/8', 'bw/9', 'bw/10'});
xlabel('目标角间隔');
ylabel('均方根误差（度）');
legend('中心截取T投影', 'Location', 'best');
title('新路线中心截取T投影的均方根误差');
