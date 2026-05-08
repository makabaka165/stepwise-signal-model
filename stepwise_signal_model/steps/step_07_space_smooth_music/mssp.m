function ers = mssp(cr, k)
    % modified spatial smoothing
    [M, MM] = size(cr);
    N = M - k + 1;
    J = fliplr(eye(M));
    crfb = (cr + J * cr.' * J) / 2;
    crs = zeros(k, k);
    
    for in = 1:N
        crs = crs + crfb(in:in+k-1, in:in+k-1);
    end
    
    ers = crs / N;
end