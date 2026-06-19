function step13_4_common(action)
%STEP13_4_COMMON Shared Step13.4 MATLAB workflow.
%
% Actions:
%   sweep         - run full-data fixed Z24 shift engineering sweep
%   fulln_golden  - generate full-N ACC48/Z24 RTL golden files
%   compare_fulln - compare full-N XSim output against MATLAB golden
%   closure       - refresh closure keypoints/docs from existing results
%   run_all       - sweep, fulln_golden, closure

if nargin < 1 || isempty(action)
    action = 'run_all';
end

paths = local_paths();
local_add_required_paths(paths.repo_root);

switch lower(strtrim(action))
    case 'sweep'
        local_run_shift_sweep(paths);
    case 'fulln_golden'
        local_generate_fulln_golden(paths);
    case 'compare_fulln'
        local_compare_fulln_outputs(paths);
    case 'closure'
        local_refresh_closure(paths);
    case 'run_all'
        local_run_shift_sweep(paths);
        local_generate_fulln_golden(paths);
        local_refresh_closure(paths);
    otherwise
        error('Step13_4:UnknownAction', 'Unknown Step13.4 action: %s', action);
end
end

function paths = local_paths()
scriptDir = fileparts(mfilename('fullpath'));
paths.matlab_dir = scriptDir;
paths.step_dir = fileparts(scriptDir);
paths.repo_root = fileparts(fileparts(paths.step_dir));
paths.results_root = fullfile(paths.step_dir, 'results_step13_fpga_soc_dbf_boundary');
paths.shift_dir = fullfile(paths.results_root, 'step13_4_shift_policy');
paths.fulln_dir = fullfile(paths.results_root, 'rtl_fulln');
paths.fulln_sim_dir = fullfile(paths.results_root, 'rtl_fulln_sim');
paths.closure_dir = fullfile(paths.results_root, 'step13_4_closure');
paths.synth_results_dir = fullfile(paths.results_root, 'synth');
local_mkdir(paths.results_root);
local_mkdir(paths.shift_dir);
local_mkdir(paths.fulln_dir);
local_mkdir(paths.fulln_sim_dir);
local_mkdir(paths.closure_dir);
local_mkdir(paths.synth_results_dir);
end

function local_add_required_paths(repoRoot)
addpath(repoRoot);
addpath(genpath(fullfile(repoRoot, 'core')));
addpath(fullfile(repoRoot, 'steps', 'step_11_1_beamspace_ml_validation', 'common'));
addpath(fullfile(repoRoot, 'steps', 'step_11_2_beamspace_w_design', 'common'));
addpath(fullfile(repoRoot, 'steps', 'step_11_3_beamspace_ml_search_acceleration', 'common'));
addpath(fullfile(repoRoot, 'steps', 'step_11_6_shared_center_rotatable_beamspace_manifold_cache', 'common'));
addpath(fullfile(repoRoot, 'steps', 'step_11_7_final_cached_c05_beamspace_ml_route', 'common'));
end

function local_run_shift_sweep(paths)
cfg = local_cfg();
scenarios = local_scenarios();
required = {'sim_cfg', 'build_step11_6_canonical_geometry', ...
    'build_recommended_w_from_step11_2', 'build_step11_7_frontend_like_input'};
missing = local_missing_functions(required);
if ~isempty(missing)
    error('Step13_4:MissingStep11Adapter', 'Missing Step11 adapter function(s): %s', strjoin(missing, ', '));
end

fprintf('Step13.4 shift sweep: centers=%s scenarios=%d trials=%d shifts=%d:%d\n', ...
    local_num_list_text(cfg.center_az_list), numel(scenarios), cfg.trials_per_scenario, ...
    cfg.shift_min, cfg.shift_max);

trialRows = {};
obsRows = {};
obsIndex = 0;
for ic = 1:numel(cfg.center_az_list)
    centerAz = cfg.center_az_list(ic);
    source = local_build_step11_source(paths.repo_root, paths.shift_dir, cfg, centerAz);
    [Wq, scaleW, clipW] = local_quant_complex_int(source.W, cfg.W_bits);
    for is = 1:numel(scenarios)
        scenario = scenarios(is);
        for trialId = 1:cfg.trials_per_scenario
            obsIndex = obsIndex + 1;
            seed = cfg.base_seed + round(centerAz * 100) + is * 1000 + trialId;
            inputInfo = local_build_step11_observation(source, scenario, centerAz, trialId, seed, cfg.L_snapshots);
            Y = inputInfo.Y;
            [Yq, scaleY, clipY] = local_quant_complex_int(Y, cfg.Y_bits);
            Zref = source.W' * Y;
            [accRe, accIm] = local_accumulate_conj_w_y(Wq, Yq);
            beamPowerRef = sum(abs(Zref).^2, 2);
            maxAbsAcc = max(abs([accRe(:); accIm(:)]));

            obsRows(end + 1, :) = {obsIndex, centerAz, scenario.scenario_name, trialId, seed, ...
                maxAbsAcc, source.N, source.B, cfg.L_snapshots, source.W_method}; %#ok<AGROW>

            for shiftBits = cfg.shift_min:cfg.shift_max
                [zRe, clipRe, overflowRe, roundedRe] = local_quantize_z_from_acc(accRe, cfg.Z_bits, shiftBits);
                [zIm, clipIm, overflowIm, roundedIm] = local_quantize_z_from_acc(accIm, cfg.Z_bits, shiftBits);
                Zdeq = complex(double(zRe), double(zIm)) * 2^shiftBits / (scaleW * scaleY);
                RzRef = Zref * Zref';
                RzDeq = Zdeq * Zdeq';
                beamPowerQ = sum(abs(Zdeq).^2, 2);
                [~, rankRef] = sort(beamPowerRef, 'descend');
                [~, rankQ] = sort(beamPowerQ, 'descend');
                topK = min(cfg.topK, source.B);
                maxAbsZInteger = max(abs([roundedRe(:); roundedIm(:)]));
                headroomBits = local_headroom_bits(cfg.Z_bits, maxAbsZInteger);
                clipCount = nnz(clipRe) + nnz(clipIm);
                overflowCount = nnz(overflowRe) + nnz(overflowIm);
                totalZParts = 2 * numel(zRe);

                relZ = norm(Zdeq(:) - Zref(:), 2) / max(norm(Zref(:), 2), eps);
                maxAbsErr = max(abs(Zdeq(:) - Zref(:)));
                powerRel = norm(beamPowerQ(:) - beamPowerRef(:), 2) / max(norm(beamPowerRef(:), 2), eps);
                topBeamSame = double(rankRef(1) == rankQ(1));
                topKSet = numel(intersect(rankRef(1:topK), rankQ(1:topK))) / topK;
                rankPreserve = local_pairwise_rank_preservation(beamPowerRef, beamPowerQ);
                rzRel = norm(RzDeq(:) - RzRef(:), 2) / max(norm(RzRef(:), 2), eps);

                trialRows(end + 1, :) = {centerAz, scenario.scenario_name, trialId, seed, ...
                    source.N, source.B, cfg.L_snapshots, source.W_method, cfg.primary_mode, ...
                    shiftBits, scaleW, scaleY, maxAbsAcc, maxAbsZInteger, headroomBits, ...
                    clipCount, overflowCount, clipCount / totalZParts, overflowCount / totalZParts, ...
                    relZ, maxAbsErr, powerRel, topBeamSame, topKSet, rankPreserve, rzRel, ...
                    true, true, true, obsIndex, clipW, clipY}; %#ok<AGROW>
            end
        end
    end
end

trialTbl = cell2table(trialRows, 'VariableNames', { ...
    'center_az', 'scenario_name', 'trial_id', 'seed', 'N_input_channels', ...
    'B_output_beams', 'L_snapshots', 'W_method', 'quant_mode', 'shift_bits', ...
    'scale_w', 'scale_y', 'max_abs_acc', 'max_abs_z_integer', ...
    'headroom_bits_observed', 'clip_count', 'overflow_count', 'clip_rate', ...
    'overflow_rate', 'Z_rel_l2_error', 'Z_max_abs_error', ...
    'beam_power_rel_error', 'top_beam_same_rate', 'topK_beam_set_preservation', ...
    'beam_power_rank_preservation', 'Z_cov_Rz_rel_error', ...
    'same_backend_input_shape', 'Rz_shape_same', 'cpu_soc_ml_ready_flag', ...
    'observation_id', 'W_clip_rate', 'Y_clip_rate'});
obsTbl = cell2table(obsRows, 'VariableNames', {'observation_id', 'center_az', ...
    'scenario_name', 'trial_id', 'seed', 'max_abs_acc', 'N_input_channels', ...
    'B_output_beams', 'L_snapshots', 'W_method'});

summaryTbl = local_summarize_shifts(trialTbl, cfg);
[keyTbl, recTbl, worstTbl] = local_shift_keypoints(trialTbl, summaryTbl, obsTbl, cfg);

writetable(trialTbl, fullfile(paths.shift_dir, 'step13_4_shift_sweep_trial.csv'));
writetable(summaryTbl, fullfile(paths.shift_dir, 'step13_4_shift_sweep_summary.csv'));
writetable(keyTbl, fullfile(paths.shift_dir, 'step13_4_shift_keypoints.csv'));
writetable(worstTbl, fullfile(paths.shift_dir, 'step13_4_shift_worst_cases.csv'));
writetable(recTbl, fullfile(paths.shift_dir, 'step13_4_shift_recommendation.csv'));
local_plot_shift_sweep(summaryTbl, paths.shift_dir);

rec = local_table_to_map(recTbl);
fprintf('Step13.4 shift sweep completed: observations=%d engineering_Z_shift_bits=%s pass=%s\n', ...
    height(obsTbl), rec.engineering_Z_shift_bits, rec.fixed_shift_policy_pass_flag);
end

function summaryTbl = local_summarize_shifts(trialTbl, cfg)
shifts = unique(trialTbl.shift_bits);
rows = cell(numel(shifts), 18);
for i = 1:numel(shifts)
    s = shifts(i);
    sub = trialTbl(trialTbl.shift_bits == s, :);
    globalClip = sum(sub.clip_count);
    globalOverflow = sum(sub.overflow_count);
    minHeadroom = min(sub.headroom_bits_observed);
    passFlag = globalClip == 0 && globalOverflow == 0 && ...
        max(sub.Z_rel_l2_error) <= cfg.pass_z_rel_l2_error && ...
        max(sub.beam_power_rel_error) <= cfg.pass_power_rel_error && ...
        min(sub.top_beam_same_rate) == 1 && ...
        min(sub.topK_beam_set_preservation) >= cfg.pass_topk_set_preservation && ...
        min(sub.beam_power_rank_preservation) >= cfg.pass_rank_preservation && ...
        max(sub.Z_cov_Rz_rel_error) <= cfg.pass_rz_rel_error && ...
        mean(sub.same_backend_input_shape) == 1 && mean(sub.Rz_shape_same) == 1 && ...
        mean(sub.cpu_soc_ml_ready_flag) == 1 && minHeadroom >= cfg.headroom_bits;
    rows(i, :) = {s, height(sub), globalClip, globalOverflow, minHeadroom, ...
        max(sub.Z_rel_l2_error), max(sub.Z_max_abs_error), max(sub.beam_power_rel_error), ...
        min(sub.top_beam_same_rate), min(sub.topK_beam_set_preservation), ...
        min(sub.beam_power_rank_preservation), max(sub.Z_cov_Rz_rel_error), ...
        mean(sub.same_backend_input_shape), mean(sub.Rz_shape_same), ...
        mean(sub.cpu_soc_ml_ready_flag), passFlag, max(sub.max_abs_acc), ...
        max(sub.max_abs_z_integer)};
end
summaryTbl = cell2table(rows, 'VariableNames', {'shift_bits', 'completed_observations', ...
    'global_clip_count', 'global_overflow_count', 'minimum_observed_headroom_bits', ...
    'worst_Z_rel_l2_error', 'worst_Z_max_abs_error', 'worst_beam_power_rel_error', ...
    'minimum_top_beam_same_rate', 'minimum_topK_beam_set_preservation', ...
    'minimum_beam_power_rank_preservation', 'worst_Z_cov_Rz_rel_error', ...
    'same_backend_input_shape_rate', 'Rz_shape_same_rate', 'cpu_soc_ml_ready_rate', ...
    'shift_pass_flag', 'max_abs_acc', 'max_abs_z_integer'});
end

function [keyTbl, recTbl, worstTbl] = local_shift_keypoints(trialTbl, summaryTbl, obsTbl, cfg)
passing = summaryTbl.shift_bits(summaryTbl.shift_pass_flag);
fixedPass = ~isempty(passing);
if fixedPass
    engineeringShift = min(passing);
    blocker = '';
else
    engineeringShift = NaN;
    blocker = 'no_fixed_z24_shift_met_engineering_gates';
end

if fixedPass
    chosen = summaryTbl(summaryTbl.shift_bits == engineeringShift, :);
    chosenTrials = trialTbl(trialTbl.shift_bits == engineeringShift, :);
else
    [~, idxFallback] = min(summaryTbl.worst_Z_rel_l2_error + 1e9 * (summaryTbl.global_clip_count > 0));
    chosen = summaryTbl(idxFallback, :);
    chosenTrials = trialTbl(trialTbl.shift_bits == chosen.shift_bits, :);
end

[~, idxWorst] = max(chosenTrials.max_abs_acc);
worstTrial = chosenTrials(idxWorst, :);
sameAcc = chosenTrials.max_abs_acc == worstTrial.max_abs_acc;
if nnz(sameAcc) > 1
    tie = chosenTrials(sameAcc, :);
    [~, tieIdx] = max(tie.Z_rel_l2_error);
    worstTrial = tie(tieIdx, :);
end

plannedObs = numel(cfg.center_az_list) * numel(local_scenarios()) * cfg.trials_per_scenario;
metric = {'formal_result_claimed'; 'engineering_validation_flag'; 'planned_observations'; ...
    'completed_observations'; 'W_method'; 'N_input_channels'; 'B_output_beams'; ...
    'L_snapshots'; 'primary_quant_mode'; 'fallback_quant_mode'; ...
    'fixed_shift_policy_pass_flag'; 'engineering_Z_shift_bits'; ...
    'minimum_observed_headroom_bits'; 'global_clip_count'; 'global_overflow_count'; ...
    'worst_Z_rel_l2_error'; 'worst_beam_power_rel_error'; 'worst_Z_cov_Rz_rel_error'; ...
    'minimum_top_beam_same_rate'; 'minimum_topK_beam_set_preservation'; ...
    'minimum_beam_power_rank_preservation'; 'worst_case_center_az'; ...
    'worst_case_scenario'; 'worst_case_trial'; 'blocker_if_any'; ...
    'step11_7_full_backend_called'; 'step11_7_backend_default_changed'};
value = {'false'; 'true'; sprintf('%d', plannedObs); sprintf('%d', height(obsTbl)); ...
    'greedy_combined_B7'; '2080'; '7'; sprintf('%d', cfg.L_snapshots); ...
    cfg.primary_mode; cfg.fallback_mode; local_bool_text(fixedPass); ...
    local_num_or_nan_text(engineeringShift); sprintf('%.17g', chosen.minimum_observed_headroom_bits); ...
    sprintf('%.0f', chosen.global_clip_count); sprintf('%.0f', chosen.global_overflow_count); ...
    sprintf('%.17g', chosen.worst_Z_rel_l2_error); ...
    sprintf('%.17g', chosen.worst_beam_power_rel_error); ...
    sprintf('%.17g', chosen.worst_Z_cov_Rz_rel_error); ...
    sprintf('%.17g', chosen.minimum_top_beam_same_rate); ...
    sprintf('%.17g', chosen.minimum_topK_beam_set_preservation); ...
    sprintf('%.17g', chosen.minimum_beam_power_rank_preservation); ...
    sprintf('%.17g', worstTrial.center_az); char(worstTrial.scenario_name); ...
    sprintf('%d', worstTrial.trial_id); blocker; 'false'; 'false'};
keyTbl = table(metric, value);

recMetric = {'fixed_shift_policy_pass_flag'; 'engineering_Z_shift_bits'; ...
    'selection_rule'; 'blocker_if_any'; 'worst_case_observation_id'; ...
    'worst_case_center_az'; 'worst_case_scenario'; 'worst_case_trial'; ...
    'worst_case_seed'};
recValue = {local_bool_text(fixedPass); local_num_or_nan_text(engineeringShift); ...
    'smallest passing shift with zero clip/overflow, numeric gates, and headroom'; ...
    blocker; sprintf('%d', worstTrial.observation_id); sprintf('%.17g', worstTrial.center_az); ...
    char(worstTrial.scenario_name); sprintf('%d', worstTrial.trial_id); ...
    sprintf('%d', worstTrial.seed)};
recTbl = table(recMetric, recValue, 'VariableNames', {'metric', 'value'});

worstTbl = sortrows(chosenTrials, {'max_abs_acc', 'Z_rel_l2_error'}, {'descend', 'descend'});
worstTbl = worstTbl(1:min(20, height(worstTbl)), :);
end

function local_generate_fulln_golden(paths)
cfg = local_cfg();
recPath = fullfile(paths.shift_dir, 'step13_4_shift_recommendation.csv');
if ~exist(recPath, 'file')
    local_run_shift_sweep(paths);
end
rec = local_read_keyvalue_file(recPath);
if ~isfield(rec, 'fixed_shift_policy_pass_flag') || ~strcmp(rec.fixed_shift_policy_pass_flag, 'true')
    local_write_fulln_unavailable(paths, rec, 'fixed_shift_policy_not_passed');
    local_refresh_closure(paths);
    return;
end
engineeringShift = str2double(rec.engineering_Z_shift_bits);
if ~isfinite(engineeringShift)
    local_write_fulln_unavailable(paths, rec, 'engineering_shift_not_available');
    local_refresh_closure(paths);
    return;
end

scenarioName = rec.worst_case_scenario;
scenario = local_find_scenario(scenarioName);
centerAz = str2double(rec.worst_case_center_az);
trialId = str2double(rec.worst_case_trial);
seed = str2double(rec.worst_case_seed);

source = local_build_step11_source(paths.repo_root, paths.fulln_dir, cfg, centerAz);
inputInfo = local_build_step11_observation(source, scenario, centerAz, trialId, seed, cfg.L_snapshots);
Yall = inputInfo.Y;
[Wq, scaleW, clipW] = local_quant_complex_int(source.W, cfg.W_bits);
[YqAll, scaleY, clipY] = local_quant_complex_int(Yall, cfg.Y_bits);
[accReAll, accImAll] = local_accumulate_conj_w_y(Wq, YqAll);

absAccBySnapshot = squeeze(max(abs(cat(3, accReAll, accImAll)), [], [1 3]));
if isempty(absAccBySnapshot)
    [~, snapA] = max(max(abs(accReAll) + abs(accImAll), [], 1));
else
    [~, snapA] = max(absAccBySnapshot);
end
if snapA ~= 1
    snapB = 1;
else
    snapB = min(2, size(Yall, 2));
end
selected = unique([snapA, snapB], 'stable');
if numel(selected) < cfg.fulln_L_limit
    candidates = 1:size(Yall, 2);
    candidates = candidates(~ismember(candidates, selected));
    selected = [selected, candidates(1:(cfg.fulln_L_limit - numel(selected)))]; %#ok<AGROW>
end
selected = selected(1:cfg.fulln_L_limit);

Yq = YqAll(:, selected);
scaleYSelected = scaleY;
[accRe, accIm] = local_accumulate_conj_w_y(Wq, Yq);
[zRe, clipRe, overflowRe] = local_quantize_z_from_acc(accRe, cfg.Z_bits, engineeringShift);
[zIm, clipIm, overflowIm] = local_quantize_z_from_acc(accIm, cfg.Z_bits, engineeringShift);
clipCount = nnz(clipRe) + nnz(clipIm);
overflowCount = nnz(overflowRe) + nnz(overflowIm);

local_write_fulln_manifest(paths.fulln_dir);
local_write_fulln_metadata(paths.fulln_dir, source, inputInfo, cfg, engineeringShift, ...
    centerAz, scenario.scenario_name, trialId, seed, selected, scaleW, scaleYSelected, ...
    clipW, clipY, clipCount, overflowCount);
local_write_fulln_w_csv(fullfile(paths.fulln_dir, 'step13_4_fulln_w_int.csv'), Wq);
local_write_fulln_y_csv(fullfile(paths.fulln_dir, 'step13_4_fulln_y_int.csv'), Yq);
local_write_fulln_accum_csv(fullfile(paths.fulln_dir, 'step13_4_fulln_accum.csv'), accRe, accIm);
local_write_fulln_z24_csv(fullfile(paths.fulln_dir, 'step13_4_fulln_z24.csv'), accRe, accIm, ...
    zRe, zIm, clipRe, clipIm, overflowRe, overflowIm, engineeringShift);
local_write_fulln_mem(paths.fulln_dir, Wq, Yq, accRe, accIm, zRe, zIm, clipRe, clipIm, overflowRe, overflowIm);
local_write_fulln_vectors_vh(paths.fulln_dir, source.N, source.B, cfg.fulln_L_limit, ...
    cfg.W_bits, cfg.Y_bits, cfg.ACC_bits, cfg.Z_bits, engineeringShift);
local_write_shift_params_vh(paths.step_dir, engineeringShift);

fprintf('Step13.4 full-N RTL golden generated: N=%d B=%d L=%d shift=%d\n', ...
    source.N, source.B, cfg.fulln_L_limit, engineeringShift);
end

function local_write_fulln_unavailable(paths, rec, blocker)
metadataPath = fullfile(paths.fulln_dir, 'step13_4_fulln_metadata.csv');
metric = {'fulln_golden_status'; 'blocker_if_any'; 'formal_result_claimed'};
value = {'unavailable'; blocker; 'false'};
if isstruct(rec) && isfield(rec, 'engineering_Z_shift_bits')
    metric{end + 1, 1} = 'engineering_Z_shift_bits'; %#ok<AGROW>
    value{end + 1, 1} = rec.engineering_Z_shift_bits; %#ok<AGROW>
end
writetable(table(metric, value), metadataPath);
end

function local_compare_fulln_outputs(paths)
goldenPath = fullfile(paths.fulln_dir, 'step13_4_fulln_z24.csv');
simPath = fullfile(paths.fulln_sim_dir, 'dbf_core_z24_fulln_output.csv');
summaryPath = fullfile(paths.fulln_sim_dir, 'step13_4_fulln_compare_summary.csv');
if ~exist(goldenPath, 'file')
    local_write_fulln_compare_summary(summaryPath, 'unavailable', 0, 0, 0, 0, 0, 0, false, false, false, false, ...
        'missing_fulln_golden');
    error('Step13_4:MissingFullNGolden', 'Missing full-N golden: %s', goldenPath);
end
golden = readtable(goldenPath);
expected = local_expand_expected_frames(golden);
if ~exist(simPath, 'file')
    local_write_fulln_compare_summary(summaryPath, 'unavailable', height(expected), 0, 0, height(expected), 0, 0, ...
        false, false, false, false, 'missing_xsim_fulln_output');
    fprintf('Step13.4 full-N compare unavailable: missing %s\n', simPath);
    return;
end
sim = readtable(simPath);

missingCount = 0;
accMismatch = 0;
zMismatch = 0;
flagMismatch = 0;
matchedRows = 0;
for i = 1:height(expected)
    idx = find(sim.frame_index == expected.frame_index(i) & sim.b_index == expected.b_index(i), 1);
    if isempty(idx)
        missingCount = missingCount + 1;
        continue;
    end
    matchedRows = matchedRows + 1;
    if sim.acc_re(idx) ~= expected.acc_re(i) || sim.acc_im(idx) ~= expected.acc_im(i)
        accMismatch = accMismatch + 1;
    end
    if sim.z_re(idx) ~= expected.z_re(i) || sim.z_im(idx) ~= expected.z_im(i)
        zMismatch = zMismatch + 1;
    end
    if sim.clip_re(idx) ~= expected.clip_re(i) || sim.clip_im(idx) ~= expected.clip_im(i) || ...
            sim.overflow_re(idx) ~= expected.overflow_re(i) || sim.overflow_im(idx) ~= expected.overflow_im(i)
        flagMismatch = flagMismatch + 1;
    end
end
accPass = accMismatch == 0 && missingCount == 0 && matchedRows == height(expected);
zPass = zMismatch == 0 && missingCount == 0 && matchedRows == height(expected);
flagPass = flagMismatch == 0 && missingCount == 0 && matchedRows == height(expected);
passFlag = accPass && zPass && flagPass;
if passFlag
    status = 'pass';
    note = 'full-N ACC48 and Z24 RTL output matches MATLAB golden exactly';
else
    status = 'fail';
    note = 'full-N RTL mismatch or missing rows';
end
local_write_fulln_compare_summary(summaryPath, status, height(expected), height(sim), matchedRows, ...
    missingCount, accMismatch, zMismatch + flagMismatch, accPass, zPass, flagPass, passFlag, note, ...
    zMismatch, flagMismatch);
fprintf('Step13.4 full-N compare status=%s acc=%s z24=%s flags=%s missing=%d\n', ...
    status, local_bool_text(accPass), local_bool_text(zPass), local_bool_text(flagPass), missingCount);
if ~passFlag
    error('Step13_4:FullNCompareFailed', 'Step13.4 full-N compare failed.');
end
end

function expected = local_expand_expected_frames(golden)
% Golden L=2 maps to frame_index 0/1 in the XSim test.
frame_index = golden.l_index;
b_index = golden.b_index;
acc_re = golden.acc_re;
acc_im = golden.acc_im;
z_re = golden.z_re;
z_im = golden.z_im;
clip_re = golden.clip_re;
clip_im = golden.clip_im;
overflow_re = golden.overflow_re;
overflow_im = golden.overflow_im;
expected = table(frame_index, b_index, acc_re, acc_im, z_re, z_im, ...
    clip_re, clip_im, overflow_re, overflow_im);
end

function local_refresh_closure(paths)
cfg = local_cfg();
shiftKeyPath = fullfile(paths.shift_dir, 'step13_4_shift_keypoints.csv');
fullnComparePath = fullfile(paths.fulln_sim_dir, 'step13_4_fulln_compare_summary.csv');
synthPath = fullfile(paths.synth_results_dir, 'step13_4_ooc_synthesis_summary.csv');
closurePath = fullfile(paths.closure_dir, 'step13_4_closure_keypoints.csv');
recoPath = fullfile(paths.closure_dir, 'step13_4_closure_recommendations.csv');

shift = local_read_keyvalue_file(shiftKeyPath);
fulln = local_read_keyvalue_file(fullnComparePath);
synth = local_read_keyvalue_file(synthPath);

fixedPass = local_get_bool(shift, 'fixed_shift_policy_pass_flag', false);
fullnPass = local_get_bool(fulln, 'fulln_functional_pass_flag', false);
oocPass = strcmp(local_get_value(synth, 'single_lane_synthesis_status', 'unavailable'), 'pass') && ...
    strcmp(local_get_value(synth, 'b7_synthesis_status', 'unavailable'), 'pass');
timingMet = local_get_bool(synth, 'timing_200MHz_met_flag', false);
closureFlag = fixedPass && fullnPass && oocPass;
proceedIp = closureFlag && timingMet;
blockerCandidates = {};
if ~fixedPass
    blockerCandidates{end + 1} = local_get_value(shift, 'blocker_if_any', 'fixed_shift_policy_not_passed'); %#ok<AGROW>
end
if ~fullnPass
    blockerCandidates{end + 1} = local_get_value(fulln, 'note', 'fulln_compare_not_passed'); %#ok<AGROW>
end
if ~oocPass
    blockerCandidates{end + 1} = local_get_value(synth, 'blocker_if_any', 'ooc_synthesis_not_passed'); %#ok<AGROW>
end
blocker = local_first_nonempty(blockerCandidates);
if closureFlag
    blocker = '';
end

metric = {'step13_scope'; 'formal_result_claimed'; 'engineering_validation_flag'; ...
    'W_method'; 'engineering_recommended_dbf_format'; 'fallback_dbf_format'; ...
    'N_input_channels'; 'B_output_beams'; 'L_snapshots_sweep'; 'fulln_rtl_L_snapshots'; ...
    'ACC_bits'; 'Z_bits'; 'fixed_shift_policy_pass_flag'; 'engineering_Z_shift_bits'; ...
    'minimum_observed_headroom_bits'; 'global_clip_count'; 'global_overflow_count'; ...
    'fulln_functional_pass_flag'; 'fulln_accumulator_match_flag'; 'fulln_z24_match_flag'; ...
    'fulln_missing_count'; 'fulln_mismatch_count'; 'ooc_synthesis_pass_flag'; ...
    'fpga_part'; 'fpga_part_source'; 'reference_device_only'; ...
    'single_lane_LUT'; 'single_lane_FF'; 'single_lane_DSP_actual'; 'single_lane_BRAM36'; ...
    'single_lane_URAM'; 'single_lane_WNS_ns'; 'b7_LUT'; 'b7_FF'; 'b7_DSP_actual'; ...
    'b7_BRAM36'; 'b7_URAM'; 'b7_WNS_ns'; 'timing_200MHz_met_flag'; ...
    'step13_engineering_closure_flag'; 'proceed_to_dbf_ip_integration_flag'; ...
    'proceed_to_board_validation_flag'; 'proceed_to_full_fpga_backend_flag'; ...
    'step11_7_backend_default_changed'; 'rz_gcache_ml_topk_c05_cpu_soc_responsibility'; ...
    'blocker_if_any'};
value = {'FPGA_DBF_CPU_SOC_ML_partition'; 'false'; 'true'; 'greedy_combined_B7'; ...
    cfg.primary_mode; cfg.fallback_mode; '2080'; '7'; sprintf('%d', cfg.L_snapshots); ...
    sprintf('%d', cfg.fulln_L_limit); sprintf('%d', cfg.ACC_bits); sprintf('%d', cfg.Z_bits); ...
    local_bool_text(fixedPass); local_get_value(shift, 'engineering_Z_shift_bits', 'NaN'); ...
    local_get_value(shift, 'minimum_observed_headroom_bits', 'NaN'); ...
    local_get_value(shift, 'global_clip_count', 'NaN'); ...
    local_get_value(shift, 'global_overflow_count', 'NaN'); ...
    local_bool_text(fullnPass); local_get_value(fulln, 'accumulator_match_flag', 'false'); ...
    local_get_value(fulln, 'z24_match_flag', 'false'); local_get_value(fulln, 'missing_count', 'NaN'); ...
    local_get_value(fulln, 'mismatch_count', 'NaN'); local_bool_text(oocPass); ...
    local_get_value(synth, 'fpga_part', 'unavailable'); local_get_value(synth, 'fpga_part_source', 'unavailable'); ...
    local_get_value(synth, 'reference_device_only', 'false'); ...
    local_get_value(synth, 'single_lane_LUT', 'NaN'); local_get_value(synth, 'single_lane_FF', 'NaN'); ...
    local_get_value(synth, 'single_lane_DSP', 'NaN'); local_get_value(synth, 'single_lane_BRAM36', 'NaN'); ...
    local_get_value(synth, 'single_lane_URAM', 'NaN'); local_get_value(synth, 'single_lane_WNS_ns', 'NaN'); ...
    local_get_value(synth, 'b7_LUT', 'NaN'); local_get_value(synth, 'b7_FF', 'NaN'); ...
    local_get_value(synth, 'b7_DSP', 'NaN'); local_get_value(synth, 'b7_BRAM36', 'NaN'); ...
    local_get_value(synth, 'b7_URAM', 'NaN'); local_get_value(synth, 'b7_WNS_ns', 'NaN'); ...
    local_bool_text(timingMet); local_bool_text(closureFlag); local_bool_text(proceedIp); ...
    '0'; '0'; 'false'; 'true'; blocker};
writetable(table(metric, value), closurePath);

recMetric = {'recommended_next_action'; 'proceed_to_dbf_ip_integration_flag'; ...
    'proceed_to_full_fpga_backend_flag'; 'proceed_to_board_validation_flag'; ...
    'note'};
if closureFlag && timingMet
    nextAction = 'prepare_dbf_ip_integration_plan_with_board_specific_constraints';
elseif closureFlag
    nextAction = 'add_pipeline_stages_before_ip_integration';
else
    nextAction = 'resolve_step13_4_blockers_before_expanding_scope';
end
recValue = {nextAction; local_bool_text(proceedIp); '0'; '0'; ...
    'Step13 closure only covers FPGA DBF engineering feasibility, not full backend, board validation, or CPU/SoC ML integration.'};
writetable(table(recMetric, recValue, 'VariableNames', {'metric', 'value'}), recoPath);
local_write_closure_report_utf8(paths, closurePath, recoPath);
fprintf('Step13.4 closure refreshed: closure=%s timing_200MHz=%s\n', ...
    local_bool_text(closureFlag), local_bool_text(timingMet));
end

function cfg = local_cfg()
cfg = struct();
cfg.center_az_list = local_getenv_num_list('STEP13_4_CENTER_AZ_LIST', [0, 4, 8, 15]);
cfg.trials_per_scenario = local_getenv_int('STEP13_4_TRIALS_PER_SCENARIO', 3);
cfg.L_snapshots = local_getenv_int('STEP13_4_L_SNAPSHOTS', 16);
cfg.shift_min = local_getenv_int('STEP13_4_SHIFT_MIN', 0);
cfg.shift_max = local_getenv_int('STEP13_4_SHIFT_MAX', 31);
cfg.headroom_bits = local_getenv_int('STEP13_4_HEADROOM_BITS', 1);
cfg.fulln_L_limit = local_getenv_int('STEP13_4_FULLN_L_LIMIT', 2);
cfg.clock_MHz = local_getenv_num('STEP13_4_CLOCK_MHZ', 200);
cfg.primary_mode = local_getenv_text('STEP13_4_PRIMARY_MODE', 'mixed_W18_Y16_Z24');
cfg.fallback_mode = local_getenv_text('STEP13_4_FALLBACK_MODE', 'mixed_W24_Y16_Z24');
cfg.base_seed = 20260619;
[cfg.W_bits, cfg.Y_bits, cfg.Z_bits] = local_parse_quant_mode(cfg.primary_mode);
cfg.ACC_bits = 48;
cfg.topK = 3;
cfg.pass_z_rel_l2_error = 1.0e-3;
cfg.pass_power_rel_error = 3.0e-3;
cfg.pass_topk_set_preservation = 0.999;
cfg.pass_rank_preservation = 0.999;
cfg.pass_rz_rel_error = 3.0e-3;
end

function scenarios = local_scenarios()
defs = {
    'easy_noncoherent',      0.00,   0, 1.00, 1.27, 0.67, 30;
    'strong_coherent',      0.99,   5, 1.00, 1.27, 0.37, 30;
    'hard_phase',           0.99, 150, 1.00, 0.83, 0.37, 30;
    'weak_secondary',       0.99, 150, 0.30, 0.83, 0.37, 30;
    'low_snr_hard',         1.00, 150, 0.30, 0.83, 0.37, 20;
    'near_tie_close_sep',   0.98,  90, 0.95, 0.41, 0.19, 28;
    'large_el_pair',        0.70,  20, 1.00, 1.27, 1.09, 30
};
scenarios = struct('scenario_name', {}, 'rho', {}, 'phase_deg', {}, 'beta', {}, ...
    'az_sep_deg', {}, 'el_sep_deg', {}, 'snr_db', {});
for i = 1:size(defs, 1)
    scenarios(i).scenario_name = defs{i, 1}; %#ok<AGROW>
    scenarios(i).rho = defs{i, 2};
    scenarios(i).phase_deg = defs{i, 3};
    scenarios(i).beta = defs{i, 4};
    scenarios(i).az_sep_deg = defs{i, 5};
    scenarios(i).el_sep_deg = defs{i, 6};
    scenarios(i).snr_db = defs{i, 7};
end
end

function source = local_build_step11_source(repoRoot, resultsDir, cfg13, centerAz)
cfg = sim_cfg();
cfg.beam.azSectorCenter = centerAz;
cfg.beam.azSteer = centerAz;
phaseFactor = cfg.beam.spatialPhaseFactor;
phaseSign = 1;
reg = 1e-10;
geom = build_step11_6_canonical_geometry(cfg, centerAz);
step11_2_dir = fullfile(repoRoot, 'steps', 'step_11_2_beamspace_w_design');
[W, wInfo] = build_recommended_w_from_step11_2(step11_2_dir, cfg, geom.canonical_arr, ...
    'B', 7, 'Criterion', 'combined', 'PhaseFactor', phaseFactor, ...
    'PhaseSign', phaseSign, 'Reg', reg);
WMethod = sprintf('greedy_%s_B%d', wInfo.criterion, wInfo.B);
context = struct();
context.cfg = cfg;
context.W = W;
context.W_method = WMethod;
context.w_info = wInfo;
context.lambda = cfg.arr.lambda;
context.phase_factor = phaseFactor;
context.phase_sign = phaseSign;
context.el_center_nominal = cfg.beam.elSectorCenter;
context.el_center_offset = 0.31;
context.L_default = cfg13.L_snapshots;
context.base_seed = cfg13.base_seed;
context.result_dir = resultsDir;
source = struct();
source.cfg = cfg;
source.W = W;
source.W_method = WMethod;
source.context = context;
source.N = size(W, 1);
source.B = size(W, 2);
source.center_az = centerAz;
end

function inputInfo = local_build_step11_observation(source, scenario, centerAz, trialId, seed, L)
[input, ~, ~] = build_step11_7_frontend_like_input(source.context, scenario, centerAz, trialId, ...
    'L', L, 'Seed', seed, 'ReshapeMode', 'matrix_N_by_L', ...
    'FrontendState', 'controlled_pair2d_candidate', 'MethodTag', 'step13_4_dbf_shift_sweep');
Y = input.Y_work;
if ~(ismatrix(Y) && size(Y, 1) == size(source.W, 1))
    sz = size(Y);
    if ndims(Y) == 3 && sz(1) == source.cfg.beam.subNaz && sz(2) == source.cfg.arr.Nel
        Y = reshape(Y, [], sz(3));
    else
        error('Step13_4:InvalidYWork', 'Y_work shape %s does not match W rows %d.', ...
            local_shape_text(size(Y)), size(source.W, 1));
    end
end
Y = Y / max(abs(Y(:)));
inputInfo = struct();
inputInfo.Y = Y;
inputInfo.Y_work_shape = local_shape_text(size(input.Y_work));
inputInfo.Y_matrix_shape = local_shape_text(size(Y));
inputInfo.seed = seed;
end

function [W_BITS, Y_BITS, Z_BITS] = local_parse_quant_mode(modeName)
tokens = regexp(modeName, 'W(\d+)_Y(\d+)_Z(\d+)', 'tokens', 'once');
if isempty(tokens)
    error('Step13_4:InvalidQuantMode', 'Quant mode must contain W<num>_Y<num>_Z<num>, got %s.', modeName);
end
W_BITS = str2double(tokens{1});
Y_BITS = str2double(tokens{2});
Z_BITS = str2double(tokens{3});
end

function [xq, scale, clipRate] = local_quant_complex_int(x, bits)
maxInt = 2^(bits - 1) - 1;
minInt = -2^(bits - 1);
peak = max([max(abs(real(x(:)))), max(abs(imag(x(:)))), eps]);
scale = maxInt / peak;
ri = round(real(x) * scale);
ii = round(imag(x) * scale);
clipMask = ri > maxInt | ri < minInt | ii > maxInt | ii < minInt;
ri = min(max(ri, minInt), maxInt);
ii = min(max(ii, minInt), maxInt);
xq = complex(ri, ii);
clipRate = nnz(clipMask) / numel(x);
end

function [accRe, accIm] = local_accumulate_conj_w_y(Wq, Yq)
N = size(Wq, 1);
B = size(Wq, 2);
L = size(Yq, 2);
accRe = zeros(B, L);
accIm = zeros(B, L);
for b = 1:B
    wr = real(Wq(:, b));
    wi = imag(Wq(:, b));
    for l = 1:L
        yr = real(Yq(:, l));
        yi = imag(Yq(:, l));
        accRe(b, l) = sum(wr .* yr + wi .* yi);
        accIm(b, l) = sum(wr .* yi - wi .* yr);
    end
end
end

function [z, clipFlag, overflowFlag, rounded] = local_quantize_z_from_acc(acc, zBits, shiftBits)
maxZ = 2^(zBits - 1) - 1;
minZ = -2^(zBits - 1);
roundedAbs = local_round_abs_shift(abs(acc), shiftBits);
rounded = sign(acc) .* roundedAbs;
overflowFlag = rounded > maxZ | rounded < minZ;
z = min(max(rounded, minZ), maxZ);
clipFlag = overflowFlag;
end

function y = local_round_abs_shift(x, shiftBits)
if shiftBits == 0
    y = x;
else
    y = floor((x + 2^(shiftBits - 1)) / 2^shiftBits);
end
end

function headroomBits = local_headroom_bits(zBits, maxAbsZInteger)
maxInt = 2^(zBits - 1) - 1;
if maxAbsZInteger <= 0
    headroomBits = 99;
else
    headroomBits = floor(log2(maxInt / max(1, maxAbsZInteger)));
end
end

function rate = local_pairwise_rank_preservation(powerRef, powerQ)
n = numel(powerRef);
total = 0;
same = 0;
for i = 1:n
    for j = i+1:n
        total = total + 1;
        if sign(powerRef(i) - powerRef(j)) == sign(powerQ(i) - powerQ(j))
            same = same + 1;
        end
    end
end
rate = same / max(total, 1);
end

function local_plot_shift_sweep(summaryTbl, outDir)
fig = figure('Visible', 'off');
plot(summaryTbl.shift_bits, summaryTbl.worst_Z_rel_l2_error, '-o');
grid on;
xlabel('SHIFT_BITS');
ylabel('Worst Z relative L2 error');
title('Step13.4 Z24 error vs fixed shift');
saveas(fig, fullfile(outDir, 'step13_4_shift_error_vs_bits.png'));
close(fig);

fig = figure('Visible', 'off');
plot(summaryTbl.shift_bits, summaryTbl.global_clip_count + summaryTbl.global_overflow_count, '-o');
grid on;
xlabel('SHIFT_BITS');
ylabel('Global clip + overflow count');
title('Step13.4 clip/overflow vs fixed shift');
saveas(fig, fullfile(outDir, 'step13_4_shift_clip_vs_bits.png'));
close(fig);

fig = figure('Visible', 'off');
plot(summaryTbl.shift_bits, summaryTbl.minimum_observed_headroom_bits, '-o');
grid on;
xlabel('SHIFT_BITS');
ylabel('Minimum observed headroom bits');
title('Step13.4 headroom vs fixed shift');
saveas(fig, fullfile(outDir, 'step13_4_shift_headroom_vs_bits.png'));
close(fig);
end

function local_write_fulln_manifest(outDir)
file_name = {'step13_4_fulln_metadata.csv'; 'step13_4_fulln_w_int.csv'; ...
    'step13_4_fulln_y_int.csv'; 'step13_4_fulln_accum.csv'; ...
    'step13_4_fulln_z24.csv'; 'step13_4_fulln_vectors.vh'; ...
    'step13_4_fulln_w_re.mem'; 'step13_4_fulln_w_im.mem'; ...
    'step13_4_fulln_y_re.mem'; 'step13_4_fulln_y_im.mem'; ...
    'step13_4_fulln_acc_re.mem'; 'step13_4_fulln_acc_im.mem'; ...
    'step13_4_fulln_z_re.mem'; 'step13_4_fulln_z_im.mem'; ...
    'step13_4_fulln_clip_re.mem'; 'step13_4_fulln_clip_im.mem'; ...
    'step13_4_fulln_overflow_re.mem'; 'step13_4_fulln_overflow_im.mem'};
role = {'key value metadata'; 'full-N quantized W integer'; ...
    'full-N selected Y integer'; 'full-N raw ACC48 golden'; ...
    'full-N Z24 golden'; 'Verilog include with dimensions and mem paths'; ...
    'W real readmemh'; 'W imag readmemh'; 'Y real readmemh'; 'Y imag readmemh'; ...
    'ACC real expected readmemh'; 'ACC imag expected readmemh'; ...
    'Z real expected readmemh'; 'Z imag expected readmemh'; ...
    'clip real expected readmemh'; 'clip imag expected readmemh'; ...
    'overflow real expected readmemh'; 'overflow imag expected readmemh'};
directory = repmat({outDir}, numel(file_name), 1);
writetable(table(file_name, role, directory), fullfile(outDir, 'step13_4_fulln_manifest.csv'));
end

function local_write_fulln_metadata(outDir, source, inputInfo, cfg, shiftBits, centerAz, ...
    scenarioName, trialId, seed, selectedSnapshots, scaleW, scaleY, clipW, clipY, clipCount, overflowCount)
metric = {'input_source_used'; 'W_method'; 'N'; 'B'; 'L'; 'W_bits'; 'Y_bits'; ...
    'ACC_bits'; 'Z_bits'; 'engineering_Z_shift_bits'; 'Z_shift_auto_selected'; ...
    'fixed_shift_source'; 'scale_w'; 'scale_y_per_snapshot'; 'clip_count'; ...
    'overflow_count'; 'source_center_az'; 'source_scenario_name'; 'source_trial_id'; ...
    'source_seed'; 'selected_snapshot_indices'; 'selection_reason'; ...
    'step11_7_full_backend_called'; 'step11_7_backend_default_changed'; ...
    'formal_result_claimed'; 'W_clip_rate'; 'Y_clip_rate'};
value = {'step11_light'; source.W_method; sprintf('%d', source.N); sprintf('%d', source.B); ...
    sprintf('%d', numel(selectedSnapshots)); sprintf('%d', cfg.W_bits); sprintf('%d', cfg.Y_bits); ...
    sprintf('%d', cfg.ACC_bits); sprintf('%d', cfg.Z_bits); sprintf('%d', shiftBits); ...
    'false'; 'step13_4_full_data_engineering_sweep'; sprintf('%.17g', scaleW); ...
    sprintf('%.17g', scaleY); sprintf('%d', clipCount); sprintf('%d', overflowCount); ...
    sprintf('%.17g', centerAz); char(scenarioName); sprintf('%d', trialId); sprintf('%d', seed); ...
    local_num_list_text(selectedSnapshots - 1); ...
    'snapshot A has global max abs accumulator; snapshot B is first different snapshot'; ...
    'false'; 'false'; 'false'; sprintf('%.17g', clipW); sprintf('%.17g', clipY)};
writetable(table(metric, value), fullfile(outDir, 'step13_4_fulln_metadata.csv'));
end

function local_write_fulln_w_csv(pathName, Wq)
N = size(Wq, 1);
B = size(Wq, 2);
n_index = zeros(N * B, 1);
b_index = zeros(N * B, 1);
w_re = zeros(N * B, 1);
w_im = zeros(N * B, 1);
row = 0;
for b = 1:B
    for n = 1:N
        row = row + 1;
        n_index(row) = n - 1;
        b_index(row) = b - 1;
        w_re(row) = real(Wq(n, b));
        w_im(row) = imag(Wq(n, b));
    end
end
writetable(table(n_index, b_index, w_re, w_im), pathName);
end

function local_write_fulln_y_csv(pathName, Yq)
N = size(Yq, 1);
L = size(Yq, 2);
n_index = zeros(N * L, 1);
l_index = zeros(N * L, 1);
y_re = zeros(N * L, 1);
y_im = zeros(N * L, 1);
row = 0;
for l = 1:L
    for n = 1:N
        row = row + 1;
        n_index(row) = n - 1;
        l_index(row) = l - 1;
        y_re(row) = real(Yq(n, l));
        y_im(row) = imag(Yq(n, l));
    end
end
writetable(table(n_index, l_index, y_re, y_im), pathName);
end

function local_write_fulln_accum_csv(pathName, accRe, accIm)
B = size(accRe, 1);
L = size(accRe, 2);
b_index = zeros(B * L, 1);
l_index = zeros(B * L, 1);
acc_re = zeros(B * L, 1);
acc_im = zeros(B * L, 1);
row = 0;
for l = 1:L
    for b = 1:B
        row = row + 1;
        b_index(row) = b - 1;
        l_index(row) = l - 1;
        acc_re(row) = accRe(b, l);
        acc_im(row) = accIm(b, l);
    end
end
writetable(table(b_index, l_index, acc_re, acc_im), pathName);
end

function local_write_fulln_z24_csv(pathName, accRe, accIm, zRe, zIm, clipRe, clipIm, overflowRe, overflowIm, shiftBits)
B = size(accRe, 1);
L = size(accRe, 2);
b_index = zeros(B * L, 1);
l_index = zeros(B * L, 1);
acc_re = zeros(B * L, 1);
acc_im = zeros(B * L, 1);
z_re = zeros(B * L, 1);
z_im = zeros(B * L, 1);
clip_re = zeros(B * L, 1);
clip_im = zeros(B * L, 1);
overflow_re = zeros(B * L, 1);
overflow_im = zeros(B * L, 1);
shift_bits = repmat(shiftBits, B * L, 1);
row = 0;
for l = 1:L
    for b = 1:B
        row = row + 1;
        b_index(row) = b - 1;
        l_index(row) = l - 1;
        acc_re(row) = accRe(b, l);
        acc_im(row) = accIm(b, l);
        z_re(row) = zRe(b, l);
        z_im(row) = zIm(b, l);
        clip_re(row) = double(clipRe(b, l));
        clip_im(row) = double(clipIm(b, l));
        overflow_re(row) = double(overflowRe(b, l));
        overflow_im(row) = double(overflowIm(b, l));
    end
end
writetable(table(b_index, l_index, acc_re, acc_im, z_re, z_im, clip_re, clip_im, ...
    overflow_re, overflow_im, shift_bits), pathName);
end

function local_write_fulln_mem(outDir, Wq, Yq, accRe, accIm, zRe, zIm, clipRe, clipIm, overflowRe, overflowIm)
local_write_mem(fullfile(outDir, 'step13_4_fulln_w_re.mem'), real(Wq(:)), 18);
local_write_mem(fullfile(outDir, 'step13_4_fulln_w_im.mem'), imag(Wq(:)), 18);
local_write_mem(fullfile(outDir, 'step13_4_fulln_y_re.mem'), real(Yq(:)), 16);
local_write_mem(fullfile(outDir, 'step13_4_fulln_y_im.mem'), imag(Yq(:)), 16);
local_write_mem(fullfile(outDir, 'step13_4_fulln_acc_re.mem'), accRe(:), 48);
local_write_mem(fullfile(outDir, 'step13_4_fulln_acc_im.mem'), accIm(:), 48);
local_write_mem(fullfile(outDir, 'step13_4_fulln_z_re.mem'), zRe(:), 24);
local_write_mem(fullfile(outDir, 'step13_4_fulln_z_im.mem'), zIm(:), 24);
local_write_mem(fullfile(outDir, 'step13_4_fulln_clip_re.mem'), double(clipRe(:)), 1);
local_write_mem(fullfile(outDir, 'step13_4_fulln_clip_im.mem'), double(clipIm(:)), 1);
local_write_mem(fullfile(outDir, 'step13_4_fulln_overflow_re.mem'), double(overflowRe(:)), 1);
local_write_mem(fullfile(outDir, 'step13_4_fulln_overflow_im.mem'), double(overflowIm(:)), 1);
end

function local_write_mem(pathName, values, bits)
fid = fopen(pathName, 'w');
if fid < 0
    error('Step13_4:CannotWriteMem', 'Cannot write %s', pathName);
end
cleanupObj = onCleanup(@() fclose(fid));
hexDigits = ceil(bits / 4);
for i = 1:numel(values)
    uintValue = mod(round(values(i)), 2^bits);
    fprintf(fid, '%s\n', dec2hex(uintValue, hexDigits));
end
end

function local_write_fulln_vectors_vh(outDir, N, B, L, W_BITS, Y_BITS, ACC_BITS, Z_BITS, shiftBits)
pathName = fullfile(outDir, 'step13_4_fulln_vectors.vh');
fid = fopen(pathName, 'w');
if fid < 0
    error('Step13_4:CannotWriteVectors', 'Cannot write %s', pathName);
end
cleanupObj = onCleanup(@() fclose(fid));
fprintf(fid, 'localparam integer STEP13_4_FULLN_N = %d;\n', N);
fprintf(fid, 'localparam integer STEP13_4_FULLN_B = %d;\n', B);
fprintf(fid, 'localparam integer STEP13_4_FULLN_L = %d;\n', L);
fprintf(fid, 'localparam integer STEP13_4_FULLN_W_BITS = %d;\n', W_BITS);
fprintf(fid, 'localparam integer STEP13_4_FULLN_Y_BITS = %d;\n', Y_BITS);
fprintf(fid, 'localparam integer STEP13_4_FULLN_ACC_BITS = %d;\n', ACC_BITS);
fprintf(fid, 'localparam integer STEP13_4_FULLN_Z_BITS = %d;\n', Z_BITS);
fprintf(fid, 'localparam integer STEP13_4_FULLN_Z_SHIFT_BITS = %d;\n', shiftBits);
fprintf(fid, '`define STEP13_4_FULLN_W_RE_MEM "results_step13_fpga_soc_dbf_boundary/rtl_fulln/step13_4_fulln_w_re.mem"\n');
fprintf(fid, '`define STEP13_4_FULLN_W_IM_MEM "results_step13_fpga_soc_dbf_boundary/rtl_fulln/step13_4_fulln_w_im.mem"\n');
fprintf(fid, '`define STEP13_4_FULLN_Y_RE_MEM "results_step13_fpga_soc_dbf_boundary/rtl_fulln/step13_4_fulln_y_re.mem"\n');
fprintf(fid, '`define STEP13_4_FULLN_Y_IM_MEM "results_step13_fpga_soc_dbf_boundary/rtl_fulln/step13_4_fulln_y_im.mem"\n');
fprintf(fid, '`define STEP13_4_FULLN_ACC_RE_MEM "results_step13_fpga_soc_dbf_boundary/rtl_fulln/step13_4_fulln_acc_re.mem"\n');
fprintf(fid, '`define STEP13_4_FULLN_ACC_IM_MEM "results_step13_fpga_soc_dbf_boundary/rtl_fulln/step13_4_fulln_acc_im.mem"\n');
fprintf(fid, '`define STEP13_4_FULLN_Z_RE_MEM "results_step13_fpga_soc_dbf_boundary/rtl_fulln/step13_4_fulln_z_re.mem"\n');
fprintf(fid, '`define STEP13_4_FULLN_Z_IM_MEM "results_step13_fpga_soc_dbf_boundary/rtl_fulln/step13_4_fulln_z_im.mem"\n');
fprintf(fid, '`define STEP13_4_FULLN_CLIP_RE_MEM "results_step13_fpga_soc_dbf_boundary/rtl_fulln/step13_4_fulln_clip_re.mem"\n');
fprintf(fid, '`define STEP13_4_FULLN_CLIP_IM_MEM "results_step13_fpga_soc_dbf_boundary/rtl_fulln/step13_4_fulln_clip_im.mem"\n');
fprintf(fid, '`define STEP13_4_FULLN_OVERFLOW_RE_MEM "results_step13_fpga_soc_dbf_boundary/rtl_fulln/step13_4_fulln_overflow_re.mem"\n');
fprintf(fid, '`define STEP13_4_FULLN_OVERFLOW_IM_MEM "results_step13_fpga_soc_dbf_boundary/rtl_fulln/step13_4_fulln_overflow_im.mem"\n');
end

function local_write_shift_params_vh(stepDir, shiftBits)
pathName = fullfile(stepDir, 'rtl', 'step13_4_shift_params.vh');
fid = fopen(pathName, 'w');
if fid < 0
    error('Step13_4:CannotWriteShiftParams', 'Cannot write %s', pathName);
end
cleanupObj = onCleanup(@() fclose(fid));
fprintf(fid, '`ifndef STEP13_4_SHIFT_PARAMS_VH\n');
fprintf(fid, '`define STEP13_4_SHIFT_PARAMS_VH\n');
fprintf(fid, '`define STEP13_4_ENGINEERING_Z_SHIFT_BITS %d\n', shiftBits);
fprintf(fid, '`endif\n');
end

function local_write_fulln_compare_summary(pathName, status, expectedRows, simRows, matchedRows, ...
    missingCount, accMismatch, mismatchCount, accPass, zPass, flagPass, fullPass, note, varargin)
if numel(varargin) >= 2
    zMismatch = varargin{1};
    flagMismatch = varargin{2};
elseif numel(varargin) == 1
    zMismatch = varargin{1};
    flagMismatch = 0;
else
    zMismatch = mismatchCount;
    flagMismatch = 0;
end
metric = {'comparison_status'; 'expected_rows'; 'sim_rows'; 'matched_rows'; ...
    'missing_count'; 'accumulator_mismatch_count'; 'z24_mismatch_count'; ...
    'flag_mismatch_count'; 'mismatch_count'; 'accumulator_match_flag'; ...
    'z24_match_flag'; 'clip_overflow_match_flag'; 'fulln_functional_pass_flag'; ...
    'formal_result_claimed'; 'note'};
value = {status; sprintf('%d', expectedRows); sprintf('%d', simRows); sprintf('%d', matchedRows); ...
    sprintf('%d', missingCount); sprintf('%d', accMismatch); sprintf('%d', zMismatch); ...
    sprintf('%d', flagMismatch); sprintf('%d', mismatchCount); local_bool_text(accPass); ...
    local_bool_text(zPass); local_bool_text(flagPass); local_bool_text(fullPass); 'false'; note};
writetable(table(metric, value), pathName);
end

function local_write_closure_report_utf8(paths, closurePath, recoPath)
closure = local_read_keyvalue_file(closurePath);
reco = local_read_keyvalue_file(recoPath);
reportName = char([31532, 49, 51, 27493, 95, 68, 66, 70, 24037, 31243, ...
    36793, 30028, 25910, 26463, 25253, 21578, 46, 109, 100]);
reportPath = fullfile(paths.step_dir, reportName);
fid = fopen(reportPath, 'w', 'n', 'UTF-8');
if fid < 0
    error('Step13_4:CannotWriteReport', 'Cannot write %s', reportPath);
end
cleanupObj = onCleanup(@() fclose(fid));

fprintf(fid, '# Step13.4 DBF Engineering Boundary Closure Report\n\n');
fprintf(fid, '## Scope\n\n');
fprintf(fid, 'FPGA scope is DBF only: `Z = W^H Y`.\n\n');
fprintf(fid, 'The closed datapath is:\n\n');
fprintf(fid, '```text\n');
fprintf(fid, 'Y stream -> W input/read -> conj(W)*Y -> full-N accumulation -> fixed shift -> symmetric rounding -> signed int24 saturation -> Z output + clip/overflow flags\n');
fprintf(fid, '```\n\n');
fprintf(fid, 'CPU/SoC remains responsible for `Rz/G_cache/2D ML/topK/C05/confidence/boundary/fallback/logging/final output` by design. These are not missing FPGA RTL modules.\n\n');

fprintf(fid, '## Functional Evidence\n\n');
fprintf(fid, '- W method: `%s`\n', local_get_value(closure, 'W_method', 'greedy_combined_B7'));
fprintf(fid, '- N/B/L sweep: `%s / %s / %s`\n', ...
    local_get_value(closure, 'N_input_channels', '2080'), ...
    local_get_value(closure, 'B_output_beams', '7'), ...
    local_get_value(closure, 'L_snapshots_sweep', '16'));
fprintf(fid, '- full-N RTL L snapshots: `%s`\n', local_get_value(closure, 'fulln_rtl_L_snapshots', '2'));
fprintf(fid, '- recommended DBF format: `%s`\n', local_get_value(closure, 'engineering_recommended_dbf_format', 'mixed_W18_Y16_Z24'));
fprintf(fid, '- fallback DBF format: `%s`\n', local_get_value(closure, 'fallback_dbf_format', 'mixed_W24_Y16_Z24'));
fprintf(fid, '- ACC/Z bits: `%s / %s`\n', ...
    local_get_value(closure, 'ACC_bits', '48'), ...
    local_get_value(closure, 'Z_bits', '24'));
fprintf(fid, '- engineering Z shift bits: `%s`\n', local_get_value(closure, 'engineering_Z_shift_bits', 'NaN'));
fprintf(fid, '- fixed shift policy pass: `%s`\n', local_get_value(closure, 'fixed_shift_policy_pass_flag', 'false'));
fprintf(fid, '- minimum observed headroom bits: `%s`\n', local_get_value(closure, 'minimum_observed_headroom_bits', 'NaN'));
fprintf(fid, '- global clip / overflow count: `%s / %s`\n', ...
    local_get_value(closure, 'global_clip_count', 'NaN'), ...
    local_get_value(closure, 'global_overflow_count', 'NaN'));
fprintf(fid, '- full-N functional pass: `%s`\n', local_get_value(closure, 'fulln_functional_pass_flag', 'false'));
fprintf(fid, '- full-N accumulator / Z24 match: `%s / %s`\n', ...
    local_get_value(closure, 'fulln_accumulator_match_flag', 'false'), ...
    local_get_value(closure, 'fulln_z24_match_flag', 'false'));
fprintf(fid, '- full-N missing / mismatch count: `%s / %s`\n\n', ...
    local_get_value(closure, 'fulln_missing_count', 'NaN'), ...
    local_get_value(closure, 'fulln_mismatch_count', 'NaN'));

fprintf(fid, '## Vivado OOC Synthesis\n\n');
fprintf(fid, '- Vivado part: `%s`\n', local_get_value(closure, 'fpga_part', 'unavailable'));
fprintf(fid, '- part source: `%s`\n', local_get_value(closure, 'fpga_part_source', 'unavailable'));
fprintf(fid, '- reference device only: `%s`\n', local_get_value(closure, 'reference_device_only', 'false'));
fprintf(fid, '- single lane LUT/FF/DSP/BRAM36/URAM/WNS: `%s / %s / %s / %s / %s / %s`\n', ...
    local_get_value(closure, 'single_lane_LUT', 'NaN'), ...
    local_get_value(closure, 'single_lane_FF', 'NaN'), ...
    local_get_value(closure, 'single_lane_DSP_actual', 'NaN'), ...
    local_get_value(closure, 'single_lane_BRAM36', 'NaN'), ...
    local_get_value(closure, 'single_lane_URAM', 'NaN'), ...
    local_get_value(closure, 'single_lane_WNS_ns', 'NaN'));
fprintf(fid, '- B=7 LUT/FF/DSP/BRAM36/URAM/WNS: `%s / %s / %s / %s / %s / %s`\n', ...
    local_get_value(closure, 'b7_LUT', 'NaN'), ...
    local_get_value(closure, 'b7_FF', 'NaN'), ...
    local_get_value(closure, 'b7_DSP_actual', 'NaN'), ...
    local_get_value(closure, 'b7_BRAM36', 'NaN'), ...
    local_get_value(closure, 'b7_URAM', 'NaN'), ...
    local_get_value(closure, 'b7_WNS_ns', 'NaN'));
fprintf(fid, '- OOC synthesis pass: `%s`\n', local_get_value(closure, 'ooc_synthesis_pass_flag', 'false'));
fprintf(fid, '- 200 MHz post-synthesis timing met: `%s`\n\n', local_get_value(closure, 'timing_200MHz_met_flag', 'false'));
fprintf(fid, 'This is reference-device out-of-context synthesis evidence only. It is not implementation closure, board timing closure, bitstream generation, or final board resource characterization.\n\n');
fprintf(fid, 'The earlier rough B=7 DSP estimate was 21. Vivado OOC reports 28 DSP for the current RTL, i.e. 4 DSP per complex lane.\n\n');

fprintf(fid, '## Closure Flags\n\n');
fprintf(fid, '- step13_engineering_closure_flag: `%s`\n', local_get_value(closure, 'step13_engineering_closure_flag', 'false'));
fprintf(fid, '- proceed_to_dbf_ip_integration_flag: `%s`\n', local_get_value(closure, 'proceed_to_dbf_ip_integration_flag', 'false'));
fprintf(fid, '- proceed_to_full_fpga_backend_flag: `%s`\n', local_get_value(closure, 'proceed_to_full_fpga_backend_flag', '0'));
fprintf(fid, '- proceed_to_board_validation_flag: `%s`\n', local_get_value(closure, 'proceed_to_board_validation_flag', '0'));
fprintf(fid, '- formal_result_claimed: `%s`\n', local_get_value(closure, 'formal_result_claimed', 'false'));
fprintf(fid, '- recommended_next_action: `%s`\n\n', local_get_value(reco, 'recommended_next_action', 'resolve_step13_4_blockers_before_expanding_scope'));
fprintf(fid, 'Step13 closure only covers FPGA DBF engineering feasibility. It does not cover a complete FPGA backend, board validation, or CPU/SoC ML software integration.\n');
end

function local_write_closure_report(paths, closurePath, recoPath)
closure = local_read_keyvalue_file(closurePath);
reco = local_read_keyvalue_file(recoPath);
reportPath = fullfile(paths.step_dir, '第13步_DBF工程边界收束报告.md');
fid = fopen(reportPath, 'w');
if fid < 0
    error('Step13_4:CannotWriteReport', 'Cannot write %s', reportPath);
end
cleanupObj = onCleanup(@() fclose(fid));
fprintf(fid, '# 第13步 DBF工程边界收束报告\n\n');
fprintf(fid, '## 最终定位\n\n');
fprintf(fid, 'FPGA 侧只覆盖 DBF：`Z = W^H Y`，包括 W18/Y16 输入、ACC48 累加、固定 shift、对称 rounding、signed int24 saturation、Z 输出和 clip/overflow flags。\n\n');
fprintf(fid, 'CPU/SoC 侧继续负责 `Rz/G_cache/2D ML/topK/C05/confidence/boundary/fallback/logging/final output`。这些模块不是 Step13 FPGA RTL 待补功能。\n\n');
fprintf(fid, '## Step13.4 证据\n\n');
fprintf(fid, '- fixed shift policy pass: `%s`\n', local_get_value(closure, 'fixed_shift_policy_pass_flag', 'false'));
fprintf(fid, '- engineering Z shift bits: `%s`\n', local_get_value(closure, 'engineering_Z_shift_bits', 'NaN'));
fprintf(fid, '- full-N functional pass: `%s`\n', local_get_value(closure, 'fulln_functional_pass_flag', 'false'));
fprintf(fid, '- OOC synthesis pass: `%s`\n', local_get_value(closure, 'ooc_synthesis_pass_flag', 'false'));
fprintf(fid, '- 200 MHz post-synthesis timing met: `%s`\n', local_get_value(closure, 'timing_200MHz_met_flag', 'false'));
fprintf(fid, '- engineering closure flag: `%s`\n\n', local_get_value(closure, 'step13_engineering_closure_flag', 'false'));
fprintf(fid, '## Recommended DBF Format\n\n');
fprintf(fid, '- recommended: `%s`\n', local_get_value(closure, 'engineering_recommended_dbf_format', 'mixed_W18_Y16_Z24'));
fprintf(fid, '- fallback: `%s`\n', local_get_value(closure, 'fallback_dbf_format', 'mixed_W24_Y16_Z24'));
fprintf(fid, '- accumulator width: `%s`\n', local_get_value(closure, 'ACC_bits', '48'));
fprintf(fid, '- Z bits: `%s`\n\n', local_get_value(closure, 'Z_bits', '24'));
fprintf(fid, '## Vivado OOC Synthesis\n\n');
fprintf(fid, '- part: `%s`\n', local_get_value(closure, 'fpga_part', 'unavailable'));
fprintf(fid, '- part source: `%s`\n', local_get_value(closure, 'fpga_part_source', 'unavailable'));
fprintf(fid, '- reference device only: `%s`\n', local_get_value(closure, 'reference_device_only', 'false'));
fprintf(fid, '- single lane LUT/FF/DSP/BRAM36/URAM/WNS: `%s / %s / %s / %s / %s / %s`\n', ...
    local_get_value(closure, 'single_lane_LUT', 'NaN'), local_get_value(closure, 'single_lane_FF', 'NaN'), ...
    local_get_value(closure, 'single_lane_DSP_actual', 'NaN'), local_get_value(closure, 'single_lane_BRAM36', 'NaN'), ...
    local_get_value(closure, 'single_lane_URAM', 'NaN'), local_get_value(closure, 'single_lane_WNS_ns', 'NaN'));
fprintf(fid, '- B=7 LUT/FF/DSP/BRAM36/URAM/WNS: `%s / %s / %s / %s / %s / %s`\n\n', ...
    local_get_value(closure, 'b7_LUT', 'NaN'), local_get_value(closure, 'b7_FF', 'NaN'), ...
    local_get_value(closure, 'b7_DSP_actual', 'NaN'), local_get_value(closure, 'b7_BRAM36', 'NaN'), ...
    local_get_value(closure, 'b7_URAM', 'NaN'), local_get_value(closure, 'b7_WNS_ns', 'NaN'));
fprintf(fid, '如果 200 MHz 未满足，这只表示需要后续增加 complex multiplier 或 accumulator pipeline；不能写成 timing closure，也不能写成 board timing closure。\n\n');
fprintf(fid, '## 未覆盖范围\n\n');
fprintf(fid, 'Step13 closure only covers FPGA DBF engineering feasibility. It does not cover a complete FPGA backend, board validation, or CPU/SoC ML software integration.\n\n');
fprintf(fid, 'formal_result_claimed=false\n\n');
fprintf(fid, 'recommended_next_action=`%s`\n', local_get_value(reco, 'recommended_next_action', 'resolve_step13_4_blockers_before_expanding_scope'));
end

function scenarios = local_find_scenario(name)
allScenarios = local_scenarios();
idx = find(strcmp({allScenarios.scenario_name}, char(name)), 1);
if isempty(idx)
    error('Step13_4:ScenarioNotFound', 'Unknown scenario: %s', char(name));
end
scenarios = allScenarios(idx);
end

function m = local_read_keyvalue_file(pathName)
m = struct();
if ~exist(pathName, 'file')
    return;
end
data = readcell(pathName, 'Delimiter', ',');
if size(data, 2) < 2 || size(data, 1) < 2
    return;
end
for i = 2:size(data, 1)
    keyText = local_value_to_text(data{i, 1});
    if isempty(keyText)
        continue;
    end
    key = matlab.lang.makeValidName(keyText);
    m.(key) = local_value_to_text(data{i, 2});
end
end

function m = local_table_to_map(tbl)
m = struct();
keys = tbl{:, 1};
vals = tbl{:, 2};
for i = 1:numel(keys)
    key = matlab.lang.makeValidName(local_cell_value_to_text(keys, i));
    m.(key) = local_cell_value_to_text(vals, i);
end
end

function text = local_value_to_text(v)
if ismissing(v)
    text = '';
elseif ischar(v)
    text = strtrim(v);
elseif isstring(v)
    text = strtrim(char(v));
elseif isnumeric(v) || islogical(v)
    if isempty(v) || ~isfinite(double(v))
        text = 'NaN';
    else
        text = sprintf('%.17g', double(v));
    end
else
    text = strtrim(char(string(v)));
end
end

function text = local_cell_value_to_text(values, idx)
if iscell(values)
    v = values{idx};
elseif ischar(values)
    if ismatrix(values) && size(values, 1) >= idx
        v = strtrim(values(idx, :));
    else
        v = values;
    end
else
    v = values(idx);
end
if ischar(v)
    text = v;
elseif isstring(v)
    text = char(v);
elseif isnumeric(v) || islogical(v)
    if isscalar(v)
        if isfinite(double(v))
            text = sprintf('%.17g', double(v));
        else
            text = 'NaN';
        end
    else
        text = local_num_list_text(double(v(:).'));
    end
else
    text = char(string(v));
end
end

function value = local_get_value(s, key, defaultValue)
field = matlab.lang.makeValidName(key);
if isstruct(s) && isfield(s, field)
    value = s.(field);
else
    value = defaultValue;
end
end

function value = local_get_bool(s, key, defaultValue)
raw = lower(strtrim(local_get_value(s, key, local_bool_text(defaultValue))));
value = strcmp(raw, 'true') || strcmp(raw, '1') || strcmp(raw, 'pass');
end

function value = local_first_nonempty(values)
value = '';
for i = 1:numel(values)
    candidate = char(values{i});
    if ~isempty(candidate) && ~strcmp(candidate, 'missing_xsim_fulln_output')
        value = candidate;
        return;
    end
end
end

function missing = local_missing_functions(required)
missing = {};
for idx = 1:numel(required)
    if exist(required{idx}, 'file') ~= 2
        missing{end + 1} = required{idx}; %#ok<AGROW>
    end
end
end

function value = local_getenv_text(name, defaultValue)
raw = strtrim(getenv(name));
if isempty(raw)
    value = defaultValue;
else
    value = raw;
end
end

function value = local_getenv_int(name, defaultValue)
value = local_getenv_num(name, defaultValue);
if floor(value) ~= value
    error('Step13_4:InvalidEnvInteger', '%s must be an integer.', name);
end
end

function value = local_getenv_num(name, defaultValue)
raw = strtrim(getenv(name));
if isempty(raw)
    value = defaultValue;
    return;
end
value = str2double(raw);
if ~isfinite(value)
    error('Step13_4:InvalidEnvNumber', '%s must be numeric.', name);
end
end

function values = local_getenv_num_list(name, defaultValue)
raw = strtrim(getenv(name));
if isempty(raw)
    values = defaultValue;
    return;
end
parts = strsplit(raw, ',');
values = zeros(1, numel(parts));
for i = 1:numel(parts)
    values(i) = str2double(strtrim(parts{i}));
    if ~isfinite(values(i))
        error('Step13_4:InvalidEnvList', '%s must be a comma-separated numeric list.', name);
    end
end
end

function text = local_shape_text(sz)
parts = cell(1, numel(sz));
for idx = 1:numel(sz)
    parts{idx} = sprintf('%d', sz(idx));
end
text = strjoin(parts, 'x');
end

function text = local_num_list_text(values)
parts = cell(1, numel(values));
for i = 1:numel(values)
    parts{i} = sprintf('%.17g', values(i));
end
text = strjoin(parts, ',');
end

function text = local_num_or_nan_text(value)
if isfinite(value)
    text = sprintf('%d', value);
else
    text = 'NaN';
end
end

function text = local_bool_text(value)
if value
    text = 'true';
else
    text = 'false';
end
end

function local_mkdir(pathName)
if ~exist(pathName, 'dir')
    mkdir(pathName);
end
end
