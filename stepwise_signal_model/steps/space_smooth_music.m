% 64阵元看超分辨测试
% 波束级处理
% 不同目标角度间隔测角误差
% 以两目标中心为中心点，波束宽度划分16波束分别合成结果
% 以最小覆盖两目标角度和最大覆盖两目标角度为范围
% 划分16波束进行合并进行超分辨处理

clc
clear all
close all

c = 3e8;
array_num = 64;
fc = 2.7e9;
fc1 = 3e9;
lamda = c/fc;
d = 0.047;
bw_64 = 50.8 * 1.45 * lamda / (array_num - 1) / d;
bw_64 = roundn(bw_64, -1);
theta_bw = [bw_64/1, bw_64/2, bw_64/3, bw_64/4, bw_64/5, ...
            bw_64/6, bw_64/7, bw_64/8, bw_64/9, bw_64/10];

theta_c = 13;
T = 130;
t = linspace(0, 1, 130);
j = sqrt(-1);
snr = [12];

Metkl = 100;

for snr_num = 1 : length(snr)
    for angle_grid_num = 1 : length(theta_bw)
        fprintf('第%d个角度间隔 \n', angle_grid_num);
        for metkl_num = 1 : Metkl
            theta_a = theta_c - theta_bw(angle_grid_num)/2;
            theta_b = theta_c + theta_bw(angle_grid_num)/2;
            target_theta = [theta_a, theta_b];
            
            s1 = sqrt(10^(snr(snr_num)/10)) * exp(j*2*pi*fc*t);
            s2 = sqrt(10^(snr(snr_num)/10)) * exp(j*2*pi*fc*t);
            A_a = exp(-j*2*pi*d*(0:array_num-1)*sind(theta_a)/lamda);
            A_b = exp(-j*2*pi*d*(0:array_num-1)*sind(theta_b)/lamda);
            
            s11 = A_a.' * s1;
            s21 = A_b.' * s2;
            
            % 上下文修复：生成复噪声的系数应为 1/sqrt(2)
            y = s11 + s21 + (1/sqrt(2)) * (randn(array_num, T) + ...
                j * (randn(array_num, T)));  % 构建两相关信号
                
            % 波束级
            subarray_num = 64;
            win = taylorwin(subarray_num, 25, -40)';
            win = win / sqrt(win*win');
            j = sqrt(-1);
            position = [d*(0:subarray_num-1)]';
            
            RecvbeamC = (theta_b + theta_a)/2;
            RecvbeamS = RecvbeamC - bw_64/2;
            RecvbeamE = RecvbeamC + bw_64/2;
            M = 16;  % 64阵元波束宽度约为3°
            RecvbeamS1 = RecvbeamC + theta_bw(angle_grid_num)/2 - bw_64/2 - 0.1;
            RecvbeamE1 = RecvbeamC - theta_bw(angle_grid_num)/2 + bw_64/2 + 0.1;
            
            % 上下文修复：angel 统一改为 angle
            angle_recv = linspace(RecvbeamS, RecvbeamE, M+1);
            angle_recv1 = linspace(RecvbeamS1, RecvbeamE1, M+1);
            
            A = diag(win) * (exp(j*2*pi*position/lamda*sin(angle_recv*pi/180)));
            A1 = diag(win) * (exp(j*2*pi*position/lamda*sin(angle_recv1*pi/180)));
            sr_DBF_boshu = A.' * y;
            sr_DBF_boshu1 = A1.' * y;
            
            temp = DOA_three_music_hecheng_fangzhen(sr_DBF_boshu, subarray_num, A, RecvbeamC, theta_bw(angle_grid_num));
            
            temp1 = DOA_three_music_hecheng_fangzhen(sr_DBF_boshu1, subarray_num, A1, RecvbeamC, theta_bw(angle_grid_num));
            est_64boshu(metkl_num, (angle_grid_num-1)*2+1:angle_grid_num*2) = temp;
            est_64boshu1(metkl_num, (angle_grid_num-1)*2+1:angle_grid_num*2) = temp1;
            chazhi(angle_grid_num, metkl_num) = sum((temp - target_theta).^2, 2);
            chazhi1(angle_grid_num, metkl_num) = sum((temp1 - target_theta).^2, 2);
        end
        
        RMSE(angle_grid_num) = sqrt(sum(chazhi(angle_grid_num, :), 2)/Metkl/length(target_theta));
        RMSE1(angle_grid_num) = sqrt(sum(chazhi1(angle_grid_num, :), 2)/Metkl/length(target_theta));
    end
end

figure();
plot(1:length(theta_bw), RMSE, 'r-*', 1:length(theta_bw), RMSE1, 'b-x');
legend('未覆盖', '完全覆盖')
title('波束级不同角度间隔测角误差')
xticks([1 2 3 4 5 6 7 8 9 10])
% 上下文修复：xtickslabels 改为 xticklabels，ta 改为 bw 以符合逻辑
xticklabels({'bw/1', 'bw/2', 'bw/3', 'bw/4', 'bw/5', 'bw/6', 'bw/7', 'bw/8', 'bw/9', 'bw/10'})
xlabel('角度间隔')
ylabel('RMSE(°)')