% 对比旧路线与新路线：
% 旧路线：先进入波束域，再在波束域近似做空间平滑。
% 新路线：先在阵元域做空间平滑，再投影到波束域做 MUSIC。
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
T = 130;
t = linspace(0, 1, T);
j = sqrt(-1);
snr = 12;
Metkl = 50;
subarray_num = 59;
search_scale = 4;

win = taylorwin(subarray_num, 25, -40)';
win = win / sqrt(win * win');
position = [d * (0:subarray_num-1)]';
M = 32;  % 生成 33 个局部波束，保持较紧凑的波束域维度

% success 统计在每个角间隔档位下，成功找到双峰的次数；
% rmse    统计成功检测样本对应的均方根误差。
old_success = zeros(1, length(theta_bw));
new_success = zeros(1, length(theta_bw));
old_rmse = nan(1, length(theta_bw));
new_rmse = nan(1, length(theta_bw));

for angle_grid_num = 1 : length(theta_bw)
    fprintf('角间隔档位 %d / %d\n', angle_grid_num, length(theta_bw));
    old_sqerr = nan(1, Metkl);
    new_sqerr = nan(1, Metkl);

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
        y = s11 + s21 + (1 / sqrt(2)) * (randn(array_num, T) + ...
            j * randn(array_num, T));

        % 当前档位下，根据双目标中心角设置局部波束扫描范围。
        RecvbeamC = (theta_b + theta_a) / 2;
        RecvbeamS = RecvbeamC - bw_64 / 2;
        RecvbeamE = RecvbeamC + bw_64 / 2;
        angle_recv = linspace(RecvbeamS, RecvbeamE, M + 1);

        % 旧路线：先形成局部波束，再在波束域近似做空间平滑。
        position_full = [d * (0:array_num-1)]';
        win_full = taylorwin(array_num, 25, -40)';
        win_full = win_full / sqrt(win_full * win_full');
        A = diag(win_full) * exp(j * 2 * pi * position_full / lamda * sin(angle_recv * pi / 180));
        sr_DBF_boshu = A.' * y;
        temp_old = DOA_three_music_hecheng_fangzhen(sr_DBF_boshu, array_num, A, RecvbeamC, theta_bw(angle_grid_num));

        if all(isfinite(temp_old))
            old_success(angle_grid_num) = old_success(angle_grid_num) + 1;
            old_sqerr(metkl_num) = sum((temp_old - target_theta).^2, 2);
        end

        % 新路线：先在阵元域做空间平滑，再投影到完整局部波束域。
        y_sub = y(1:subarray_num, :);
        T_full = diag(win) * exp(j * 2 * pi * position / lamda * sin(angle_recv * pi / 180));
        temp_new = DOA_three_music_array_ss_beamspace( ...
            y_sub, subarray_num, T_full, RecvbeamC, search_scale * theta_bw(angle_grid_num));

        if all(isfinite(temp_new))
            new_success(angle_grid_num) = new_success(angle_grid_num) + 1;
            new_sqerr(metkl_num) = sum((temp_new - target_theta).^2, 2);
        end
    end

    if any(isfinite(old_sqerr))
        old_rmse(angle_grid_num) = sqrt(nansum(old_sqerr) / (2 * sum(isfinite(old_sqerr))));
    end
    if any(isfinite(new_sqerr))
        new_rmse(angle_grid_num) = sqrt(nansum(new_sqerr) / (2 * sum(isfinite(new_sqerr))));
    end
end


figure();
plot(1:length(theta_bw), old_rmse, 'r-o', ...
     1:length(theta_bw), new_rmse, 'b-s', 'LineWidth', 1.2);
grid on;
xticks(1:length(theta_bw));
xticklabels({'bw/1', 'bw/2', 'bw/3', 'bw/4', 'bw/5', 'bw/6', 'bw/7', 'bw/8', 'bw/9', 'bw/10'});
xlabel('目标角间隔');
ylabel('均方根误差（度）');
legend('旧路线：波束域近似平滑', '新路线：阵元域先平滑后投影', 'Location', 'best');
title('旧路线与新路线的均方根误差对比');
