function [doa_value, debug] = DOA_three_music_new_route_centerT( ...
    y, K, beam_grid_full_deg, center_beam_count, angle_recv, search_width_deg, varargin)

    % Route B: true array-domain FBSS -> centerT beamspace -> 1D MUSIC.
    %
    % y                  : N x T_snap array-domain snapshots
    % K                  : FBSS subarray length, K < N
    % beam_grid_full_deg : full candidate beam grid in degrees
    % center_beam_count  : number of center beams kept for beamspace projection
    % angle_recv         : local search center in degrees
    % search_width_deg   : MUSIC search width in degrees

    p = inputParser;
    addParameter(p, 'Lc', 2);
    addParameter(p, 'GridStepDeg', 0.01);
    addParameter(p, 'UseQR', true);
    parse(p, varargin{:});

    Lc = p.Results.Lc;
    grid_step_deg = p.Results.GridStepDeg;
    use_qr = p.Results.UseQR;

    j = sqrt(-1);
    c = 3e8;
    fc = 2.7e9;
    lambda = c / fc;
    d = 0.047;

    [N, T_snap] = size(y);

    if K >= N
        error('K must be smaller than N for true FBSS.');
    end

    if K <= Lc
        error('K must be larger than Lc.');
    end

    Psub = N - K + 1;
    if Psub < Lc
        error('N-K+1 must be at least Lc.');
    end

    beam_grid_full_deg = reshape(beam_grid_full_deg, 1, []);
    full_beam_count = numel(beam_grid_full_deg);

    if center_beam_count <= Lc
        error('center_beam_count must be larger than Lc.');
    end

    if center_beam_count > full_beam_count
        error('center_beam_count must not exceed full_beam_count.');
    end

    if search_width_deg <= 0
        error('search_width_deg must be positive.');
    end

    % 1. Array-domain covariance
    Rxx = y * y' / T_snap;
    Rxx = 0.5 * (Rxx + Rxx');

    % 2. True array-domain FBSS
    Rss = mssp_array_fb(Rxx, K);
    Rss = 0.5 * (Rss + Rss');

    % 3. Center beam selection from full beam grid
    center_idx = floor((full_beam_count + 1) / 2);
    half_left = floor((center_beam_count - 1) / 2);
    half_right = center_beam_count - half_left - 1;

    start_idx = center_idx - half_left;
    end_idx = center_idx + half_right;

    if start_idx < 1 || end_idx > full_beam_count
        error('Center beam selection exceeds beam grid boundary.');
    end

    center_indices = start_idx:end_idx;
    beam_grid_center_deg = beam_grid_full_deg(center_indices);

    % 4. Build K-dimensional centerT
    posK = d * (0:K-1).';

    % Positive exponent convention, consistent with Route A using A.' * y.
    Wcenter = exp(j * 2*pi/lambda * posK * sind(beam_grid_center_deg));

    if use_qr
        [Tk, ~] = qr(Wcenter, 0);
    else
        Tk = Wcenter;
    end

    if size(Tk, 2) <= Lc
        error('Beamspace dimension must be larger than Lc.');
    end

    % 5. Beamspace covariance
    % Since Tk uses positive exponent and array steering uses negative exponent,
    % use non-conjugate transpose for projection consistency:
    %   B = Tk.' * Y
    %   Rb = Tk.' * Rss * conj(Tk)
    Rb = Tk.' * Rss * conj(Tk);
    Rb = 0.5 * (Rb + Rb');

    % 6. EVD
    [E, D] = eig(Rb);
    eigvals = real(diag(D));
    [eigvals, idx] = sort(eigvals, 'descend');
    E = E(:, idx);

    if size(E, 2) <= Lc
        doa_value = nan(1, Lc);
        debug = struct();
        debug.reason = 'empty_noise_subspace';
        debug.eigvals = eigvals;
        return;
    end

    En = E(:, Lc+1:end);

    % 7. MUSIC search
    angle_search = angle_recv - search_width_deg/2 : ...
                   grid_step_deg : ...
                   angle_recv + search_width_deg/2;

    Pmu = zeros(1, numel(angle_search));

    for ii = 1:numel(angle_search)
        theta = angle_search(ii);

        aK = exp(-j * 2*pi/lambda * posK * sind(theta));
        bK = Tk.' * aK;

        den = real(bK' * En * En' * bK);
        num = real(bK' * bK);

        Pmu(ii) = num / max(den, eps);
    end

    [~, peak_ind] = FindLocalPeak_NoEdge_Fun(abs(Pmu));

    if numel(peak_ind) < Lc
        doa_value = nan(1, Lc);
    else
        doa_value = sort(angle_search(peak_ind(1:Lc)));
    end

    debug.angle_search = angle_search;
    debug.spectrum = Pmu;
    debug.eigvals = eigvals;
    debug.K = K;
    debug.N = N;
    debug.Psub = Psub;
    debug.center_indices = center_indices;
    debug.beam_grid_center_deg = beam_grid_center_deg;
    debug.center_beam_count = center_beam_count;
    debug.use_qr = use_qr;
    debug.search_width_deg = search_width_deg;
    debug.grid_step_deg = grid_step_deg;
end
