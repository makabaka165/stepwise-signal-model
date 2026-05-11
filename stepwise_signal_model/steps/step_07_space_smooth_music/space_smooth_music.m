% 第 7 步：64 阵元条件下的波束域空间平滑 MUSIC 仿真。
% 目的：
% 1. 构造双目标相干场景；
% 2. 比较不同角间隔下的测角均方根误差（RMSE）；
% 3. 对比“局部波束未完全覆盖目标”和“局部波束完整覆盖目标”两种设置。
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

% 双目标角间隔，从 1 倍参考波束宽度递减到 1/10 倍参考波束宽度。
% 这里的 bw/1、bw/2 ... bw/10 是后续横坐标上的十个测试档位。
theta_bw = [bw_64/1, bw_64/2, bw_64/3, bw_64/4, bw_64/5, ...
            bw_64/6, bw_64/7, bw_64/8, bw_64/9, bw_64/10];

theta_c = 13;
T = 130;
t = linspace(0, 1, T);
j = sqrt(-1);
snr = [12];

% 蒙特卡洛重复次数。
Metkl = 100;

for snr_num = 1 : length(snr)
    for angle_grid_num = 1 : length(theta_bw)
        fprintf('角间隔档位 %d / %d\n', angle_grid_num, length(theta_bw));
        for metkl_num = 1 : Metkl
            theta_a = theta_c - theta_bw(angle_grid_num) / 2;
            theta_b = theta_c + theta_bw(angle_grid_num) / 2;
            target_theta = [theta_a, theta_b];

            % 生成两个完全相干的目标信号，并叠加到阵列接收数据中。
            s1 = sqrt(10^(snr(snr_num) / 10)) * exp(j * 2 * pi * fc * t);
            s2 = sqrt(10^(snr(snr_num) / 10)) * exp(j * 2 * pi * fc * t);
            A_a = exp(-j * 2 * pi * d * (0:array_num-1) * sind(theta_a) / lamda);
            A_b = exp(-j * 2 * pi * d * (0:array_num-1) * sind(theta_b) / lamda);

            s11 = A_a.' * s1;
            s21 = A_b.' * s2;
            y = s11 + s21 + (1 / sqrt(2)) * (randn(array_num, T) + ...
                j * randn(array_num, T));

            subarray_num = 64;
            win = taylorwin(subarray_num, 25, -40)';
            win = win / sqrt(win * win');
            position = [d * (0:subarray_num-1)]';

            % 以双目标中心角为局部波束扇区中心。
            RecvbeamC = (theta_b + theta_a) / 2;
            RecvbeamS = RecvbeamC - bw_64 / 2;
            RecvbeamE = RecvbeamC + bw_64 / 2;
            M = 50;  % 生成 51 个局部波束，配合 Q = 10 时平滑后维数为 41

            % 第二组局部波束范围做轻微扩展，尽量完整覆盖两个目标。
            RecvbeamS1 = RecvbeamC + theta_bw(angle_grid_num) / 2 - bw_64 / 2 - 0.1;
            RecvbeamE1 = RecvbeamC - theta_bw(angle_grid_num) / 2 + bw_64 / 2 + 0.1;

            % 构造两组局部波束中心角：
            % angle_recv  为标准范围；
            % angle_recv1 为扩展范围，用于尽量完整覆盖双目标。
            angle_recv = linspace(RecvbeamS, RecvbeamE, M + 1);
            angle_recv1 = linspace(RecvbeamS1, RecvbeamE1, M + 1);

            A = diag(win) * exp(j * 2 * pi * position / lamda * sin(angle_recv * pi / 180));
            A1 = diag(win) * exp(j * 2 * pi * position / lamda * sin(angle_recv1 * pi / 180));
            sr_DBF_boshu = A.' * y;
            sr_DBF_boshu1 = A1.' * y;

            % 分别对两组局部波束结果执行波束域空间平滑 MUSIC。
            temp = DOA_three_music_hecheng_fangzhen( ...
                sr_DBF_boshu, subarray_num, A, RecvbeamC, theta_bw(angle_grid_num));
            temp1 = DOA_three_music_hecheng_fangzhen( ...
                sr_DBF_boshu1, subarray_num, A1, RecvbeamC, theta_bw(angle_grid_num));

            est_64boshu(metkl_num, (angle_grid_num-1) * 2 + 1 : angle_grid_num * 2) = temp;
            est_64boshu1(metkl_num, (angle_grid_num-1) * 2 + 1 : angle_grid_num * 2) = temp1;
            chazhi(angle_grid_num, metkl_num) = sum((temp - target_theta).^2, 2);
            chazhi1(angle_grid_num, metkl_num) = sum((temp1 - target_theta).^2, 2);
        end

        % 统计当前角间隔档位下的均方根误差。
        RMSE(angle_grid_num) = sqrt(sum(chazhi(angle_grid_num, :), 2) / Metkl / length(target_theta));
        RMSE1(angle_grid_num) = sqrt(sum(chazhi1(angle_grid_num, :), 2) / Metkl / length(target_theta));
    end
end

figure();
plot(1:length(theta_bw), RMSE, 'r-*', 1:length(theta_bw), RMSE1, 'b-x');
legend('局部波束未完全覆盖目标', '局部波束完整覆盖目标')
title('不同角间隔下的波束域空间平滑 MUSIC 测角均方根误差')
xticks(1:length(theta_bw))
xticklabels({'bw/1', 'bw/2', 'bw/3', 'bw/4', 'bw/5', 'bw/6', 'bw/7', 'bw/8', 'bw/9', 'bw/10'})
xlabel('目标角间隔')
ylabel('均方根误差（度）')
