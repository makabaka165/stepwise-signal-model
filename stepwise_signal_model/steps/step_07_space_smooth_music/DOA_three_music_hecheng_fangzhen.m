function doa_value = DOA_three_music_hecheng_fangzhen(estm_data_in, subarray_num, A, angle_recv, theta_bw)
    j = sqrt(-1);
    c = 3e8;
    fc = 2.7e9;
    lamda = c / fc;
    derad = pi / 180; % deg -> rad
    d = 0.047;
    N2P = subarray_num;
    position = [d * (0:N2P-1)]';
    Xc = estm_data_in;
    n = size(estm_data_in, 2);
    Q = 5;   % Q + 1 = 6 overlapping subarrays
    celln = size(Xc, 1) - Q;
    
    % Use one local beamspace snapshot to form the smoothed covariance input.
    Xc = Xc(:, ceil(size(Xc, 2)/2));
    Rxxmc = Xc * Xc' / n;
    RxxC_mssp = mssp(Rxxmc, celln);
    Rx = RxxC_mssp;
    
    Lc = 2; % Two coherent targets are expected in the current validation script.
    angle_search = angle_recv - theta_bw/2 : 0.01 : angle_recv + theta_bw/2;
    QQ = Lc + 1;
    
    [EVc, Dc] = eig(Rx);
    EVAc = diag(Dc)';
    [~, Ic] = sort(EVAc);
    EVc = fliplr(EVc(:, Ic));
    
    % The first Lc eigenvectors are treated as the signal subspace,
    % and the remaining vectors form the MUSIC noise subspace.
    Enc = EVc(:, QQ:celln);
    SPc = zeros(1, length(angle_search));
    for iang = 1 : length(angle_search)
        phim = derad * angle_search(iang);
        ac = A(:, 1:celln).' * exp(-j*2*pi*position/lamda*sin(phim));
        SPc(iang) = (ac' * ac) / (ac' * Enc * Enc' * ac);
    end
    
    p_SPc = abs(SPc);
    [~, peak_ind] = FindLocalPeak_Fun(p_SPc);
    
    % Return the two strongest MUSIC peaks and sort them from left to right
    % so they align with [theta_a, theta_b] in the main script.
    doa_value = sort(angle_search(peak_ind(1:2)));
end
