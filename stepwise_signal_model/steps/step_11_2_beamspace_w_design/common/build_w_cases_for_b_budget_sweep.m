function [W_cases, diagnostics] = build_w_cases_for_b_budget_sweep(W_pool, pool_info, A_patch, pair_set, x, y, z, lambda, B_list, opts)
%BUILD_W_CASES_FOR_B_BUDGET_SWEEP Build W cases for Stage3 B sweep.

if nargin < 10
    error('build_w_cases_for_b_budget_sweep:NotEnoughInputs', ...
        'W_pool, pool_info, A_patch, pair_set, x, y, z, lambda, B_list, and opts are required.');
end
opts = fill_opts_local(opts);
B_list = B_list(:).';

W_cases = struct([]);
diag_rows = repmat(make_diag_template_local(), 0, 1);
case_count = 0;

for iB = 1:numel(B_list)
    B = B_list(iB);
    [idx_regular, W_regular, regular_info] = select_regular_center_beams_from_pool(W_pool, pool_info, B);
    [W_cases, diag_rows, case_count] = add_case_local(W_cases, diag_rows, case_count, ...
        'regular_3dB_grid', 'regular', B, W_regular, idx_regular, regular_info, [], ...
        A_patch, pair_set, x, y, z, lambda, opts);

    [idx_gproj, W_gproj, hist_gproj] = select_w_greedy_from_pool(W_pool, A_patch, pair_set, x, y, z, lambda, B, ...
        'Criterion', 'projection', 'PhaseFactor', opts.phase_factor, 'PhaseSign', opts.phase_sign, 'Reg', opts.reg);
    info_gproj = struct('note', 'greedy projection-loss selection');
    [W_cases, diag_rows, case_count] = add_case_local(W_cases, diag_rows, case_count, ...
        'greedy_projection', 'greedy_projection', B, W_gproj, idx_gproj, info_gproj, hist_gproj, ...
        A_patch, pair_set, x, y, z, lambda, opts);

    [idx_glow, W_glow, hist_glow] = select_w_greedy_from_pool(W_pool, A_patch, pair_set, x, y, z, lambda, B, ...
        'Criterion', 'lowcorr', 'PhaseFactor', opts.phase_factor, 'PhaseSign', opts.phase_sign, 'Reg', opts.reg);
    info_glow = struct('note', 'greedy low-correlation selection');
    [W_cases, diag_rows, case_count] = add_case_local(W_cases, diag_rows, case_count, ...
        'greedy_lowcorr', 'greedy_lowcorr', B, W_glow, idx_glow, info_glow, hist_glow, ...
        A_patch, pair_set, x, y, z, lambda, opts);

    [idx_gcomb, W_gcomb, hist_gcomb] = select_w_greedy_from_pool(W_pool, A_patch, pair_set, x, y, z, lambda, B, ...
        'Criterion', 'combined', 'Alpha', opts.greedy_alpha, 'Beta', opts.greedy_beta, 'Gamma', opts.greedy_gamma, ...
        'PhaseFactor', opts.phase_factor, 'PhaseSign', opts.phase_sign, 'Reg', opts.reg);
    info_gcomb = struct('note', 'greedy combined projection/correlation/condition selection');
    [W_cases, diag_rows, case_count] = add_case_local(W_cases, diag_rows, case_count, ...
        'greedy_combined', 'greedy_combined', B, W_gcomb, idx_gcomb, info_gcomb, hist_gcomb, ...
        A_patch, pair_set, x, y, z, lambda, opts);

    [W_svd, svd_info] = build_svd_beamspace_basis(A_patch, B);
    info_svd = struct('note', 'non-engineering SVD information-retention upper bound', ...
        'energy_retained_B', svd_info.energy_retained_B);
    [W_cases, diag_rows, case_count] = add_case_local(W_cases, diag_rows, case_count, ...
        'svd_upper_bound', 'svd_upper_bound', B, W_svd, 1:B, info_svd, [], ...
        A_patch, pair_set, x, y, z, lambda, opts);

    if opts.include_random
        [W_rand, idx_rand, random_note] = select_random_representative_local(W_pool, B, opts);
        info_rand = struct('note', random_note);
        [W_cases, diag_rows, case_count] = add_case_local(W_cases, diag_rows, case_count, ...
            'random_pool_baseline', 'random_pool_baseline', B, W_rand, idx_rand, info_rand, [], ...
            A_patch, pair_set, x, y, z, lambda, opts);
    end
end

diagnostics = struct();
diagnostics.B_list = B_list;
diagnostics.number_of_cases = numel(W_cases);
diagnostics.methods = unique({W_cases.name}, 'stable');
diagnostics.pool_info = pool_info;
diagnostics.options = opts;
diagnostics.table = struct2table(diag_rows);
end

function opts = fill_opts_local(opts)
defaults = struct();
defaults.phase_factor = 1;
defaults.phase_sign = 1;
defaults.random_seed = 20260617;
defaults.include_random = true;
defaults.random_repeats = 3;
defaults.greedy_alpha = 1;
defaults.greedy_beta = 1;
defaults.greedy_gamma = 0.05;
defaults.reg = 1e-10;
fields = fieldnames(defaults);
for idx = 1:numel(fields)
    if ~isfield(opts, fields{idx})
        opts.(fields{idx}) = defaults.(fields{idx});
    end
end
end

function [W_cases, diag_rows, case_count] = add_case_local(W_cases, diag_rows, case_count, method_name, method_type, B, W, ...
    selected_idx, info, history, A_patch, pair_set, x, y, z, lambda, opts)
metrics = collect_w_design_metrics(method_name, B, W, A_patch, pair_set, x, y, z, lambda, ...
    'PhaseFactor', opts.phase_factor, 'PhaseSign', opts.phase_sign, 'Reg', opts.reg);
case_count = case_count + 1;

case_entry = struct();
case_entry.name = method_name;
case_entry.method_type = method_type;
case_entry.B = B;
case_entry.W = W;
case_entry.selected_idx = selected_idx;
case_entry.projection_loss = metrics.projection_loss;
case_entry.projected_energy_ratio = metrics.projected_energy_ratio;
case_entry.mean_corr = metrics.mean_corr;
case_entry.p90_corr = metrics.p90_corr;
case_entry.max_corr = metrics.max_corr;
case_entry.cond_WHW = metrics.cond_WHW;
case_entry.rank_W = metrics.rank_W;
case_entry.effective_rank = metrics.effective_rank;
case_entry.selection_history = history;
case_entry.note = get_note_local(info);
W_cases = [W_cases; case_entry]; %#ok<AGROW>

diag_row = make_diag_template_local();
diag_row.method_name = method_name;
diag_row.method_type = method_type;
diag_row.B = B;
diag_row.beam_count = size(W, 2);
diag_row.projection_loss = metrics.projection_loss;
diag_row.projected_energy_ratio = metrics.projected_energy_ratio;
diag_row.mean_corr = metrics.mean_corr;
diag_row.p90_corr = metrics.p90_corr;
diag_row.max_corr = metrics.max_corr;
diag_row.cond_WHW = metrics.cond_WHW;
diag_row.rank_W = metrics.rank_W;
diag_row.effective_rank = metrics.effective_rank;
diag_row.selected_idx_text = mat2str(selected_idx);
diag_row.note = case_entry.note;
diag_rows(end + 1, 1) = diag_row; %#ok<AGROW>
end

function row = make_diag_template_local()
row = struct();
row.method_name = '';
row.method_type = '';
row.B = NaN;
row.beam_count = NaN;
row.projection_loss = NaN;
row.projected_energy_ratio = NaN;
row.mean_corr = NaN;
row.p90_corr = NaN;
row.max_corr = NaN;
row.cond_WHW = NaN;
row.rank_W = NaN;
row.effective_rank = NaN;
row.selected_idx_text = '';
row.note = '';
end

function note = get_note_local(info)
if isstruct(info) && isfield(info, 'note')
    note = info.note;
else
    note = '';
end
end

function [W_rand, idx_rand, note] = select_random_representative_local(W_pool, B, opts)
repeats = max(1, opts.random_repeats);
idx_list = cell(repeats, 1);
score = zeros(repeats, 1);
for iRep = 1:repeats
    [~, idx_now] = build_random_w_from_pool(W_pool, B, opts.random_seed + 1000 * B + iRep);
    idx_list{iRep} = idx_now;
    W_now = W_pool(:, idx_now);
    metrics = compute_w_condition_metrics(W_now);
    score(iRep) = log10(max(metrics.cond_WHW, 1));
end
[~, order] = sort(score, 'ascend');
median_rep = order(ceil(numel(order) / 2));
idx_rand = idx_list{median_rep};
W_rand = W_pool(:, idx_rand);
note = sprintf('random sanity baseline, representative repeat %d of %d by median cond_WHW', median_rep, repeats);
end

