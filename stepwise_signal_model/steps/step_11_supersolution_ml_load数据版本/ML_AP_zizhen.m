function [tar_theta] = ML_AP_zizhen(ml_input, beam_c, d, lamda, array_num, A1)
beam_width = 2.8;
theta1 = beam_c - beam_width / 2 : 0.01 : beam_c;
theta2 = beam_c + 0.01 : 0.01 : beam_c + beam_width / 2;

Len_thetas1 = length(theta1);
Len_thetas2 = length(theta2);
Pw = zeros(Len_thetas1, Len_thetas2);

% 在局部角度对网格上执行子阵级二维 ML 搜索。
for ths1 = 1 : Len_thetas1
    for ths2 = 1 : Len_thetas2
        Th1 = theta1(ths1);
        Th2 = theta2(ths2);
        Pw(ths1, ths2) = RSTMLTr_zizhen(ml_input, Th1, Th2, array_num, d, lamda, A1);
    end
end

Pw_abs = abs(Pw) ./ max(max(abs(Pw)));
[Loc_T1, Loc_T2] = find(Pw_abs == max(max(Pw_abs)));

% 输出使子阵级 ML 评分函数取最大值的角度对。
tar_theta = [theta1(Loc_T1), theta2(Loc_T2)];
end
