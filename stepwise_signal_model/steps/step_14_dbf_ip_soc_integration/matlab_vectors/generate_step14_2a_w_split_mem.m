function generate_step14_2a_w_split_mem()
%GENERATE_STEP14_2A_W_SPLIT_MEM Split Step14.1 2080x18 W ROM files.

scriptDir = fileparts(mfilename('fullpath'));
step14Dir = fileparts(scriptDir);
vecDir = fullfile(step14Dir, 'results_step14_dbf_ip_soc_integration', 'axis_vectors');
splitDir = fullfile(vecDir, 'w_split');
if ~exist(splitDir, 'dir')
    mkdir(splitDir);
end

manifestRows = {};
validationRows = {};
allPass = true;
for beam = 0:6
    for partIdx = 1:2
        if partIdx == 1
            part = 're';
        else
            part = 'im';
        end
        base = sprintf('step14_1_w_%s_b%d', part, beam);
        srcPath = fullfile(vecDir, [base '.mem']);
        lines = readMemLines(srcPath);
        sourcePass = numel(lines) == 2080 && all(cellfun(@(s) ~isempty(regexp(s, '^[0-9a-fA-F]{5}$', 'once')), lines));
        if ~sourcePass
            error('Step14.2a:BadWMem', 'Invalid W mem format: %s', srcPath);
        end

        mainLines = lines(1:2048);
        tailLines = lines(2049:2080);
        mainName = [base '_main.mem'];
        tailName = [base '_tail.mem'];
        writeMemLines(fullfile(splitDir, mainName), mainLines);
        writeMemLines(fullfile(splitDir, tailName), tailLines);

        recon = [readMemLines(fullfile(splitDir, mainName)); readMemLines(fullfile(splitDir, tailName))];
        reconPass = isequal(lower(lines(:)), lower(recon(:)));
        mainPass = numel(mainLines) == 2048;
        tailPass = numel(tailLines) == 32;
        filePass = sourcePass && mainPass && tailPass && reconPass;
        allPass = allPass && filePass;

        manifestRows(end+1, :) = {relPath(step14Dir, srcPath), relPath(step14Dir, fullfile(splitDir, mainName)), 'main', '2048'}; %#ok<AGROW>
        manifestRows(end+1, :) = {relPath(step14Dir, srcPath), relPath(step14Dir, fullfile(splitDir, tailName)), 'tail', '32'}; %#ok<AGROW>
        validationRows(end+1, :) = {base, '2080', '2048', '32', boolStr(reconPass), boolStr(filePass)}; %#ok<AGROW>
    end
end

writeCellCsv(fullfile(splitDir, 'step14_2a_w_split_manifest.csv'), ...
    {'source_mem','split_mem','segment','line_count'}, manifestRows);
writeCellCsv(fullfile(splitDir, 'step14_2a_w_split_validation.csv'), ...
    {'source_base','source_rows','main_rows','tail_rows','reconstruction_match','file_pass'}, validationRows);

summaryPairs = {
    'source_mem_file_count', '14';
    'split_mem_file_count', '28';
    'main_rows_per_file', '2048';
    'tail_rows_per_file', '32';
    'w_split_reconstruction_match_flag', boolStr(allPass);
    'w_split_vector_pass_flag', boolStr(allPass);
    'formal_result_claimed', 'false';
};
writeKeyValueCsv(fullfile(splitDir, 'step14_2a_w_split_summary.csv'), summaryPairs);

fprintf('Step14.2a W split vector status: %s\n', ternary(allPass, 'pass', 'fail'));

end

function lines = readMemLines(path)
if ~exist(path, 'file')
    error('Step14.2a:MissingWMem', 'Missing W mem file: %s', path);
end
fid = fopen(path, 'r');
if fid < 0
    error('Step14.2a:FileOpen', 'Cannot open %s.', path);
end
cleanup = onCleanup(@() fclose(fid));
lines = {};
line = fgetl(fid);
while ischar(line)
    line = strtrim(line);
    if ~isempty(line)
        lines{end+1, 1} = lower(line); %#ok<AGROW>
    end
    line = fgetl(fid);
end
end

function writeMemLines(path, lines)
fid = fopen(path, 'w');
if fid < 0
    error('Step14.2a:FileOpen', 'Cannot open %s for writing.', path);
end
cleanup = onCleanup(@() fclose(fid));
for k = 1:numel(lines)
    fprintf(fid, '%s\n', lower(lines{k}));
end
end

function writeCellCsv(path, header, rows)
fid = fopen(path, 'w');
if fid < 0
    error('Step14.2a:FileOpen', 'Cannot open %s for writing.', path);
end
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, '%s\n', strjoin(header, ','));
for r = 1:size(rows, 1)
    fprintf(fid, '%s', rows{r, 1});
    for c = 2:size(rows, 2)
        fprintf(fid, ',%s', rows{r, c});
    end
    fprintf(fid, '\n');
end
end

function writeKeyValueCsv(path, pairs)
fid = fopen(path, 'w');
if fid < 0
    error('Step14.2a:FileOpen', 'Cannot open %s for writing.', path);
end
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, 'metric,value\n');
for k = 1:size(pairs, 1)
    fprintf(fid, '%s,%s\n', pairs{k, 1}, pairs{k, 2});
end
end

function rel = relPath(base, path)
base = char(java.io.File(base).getCanonicalPath());
path = char(java.io.File(path).getCanonicalPath());
if strncmpi(path, base, numel(base))
    rel = path(numel(base)+2:end);
else
    rel = path;
end
rel = strrep(rel, '\', '/');
end

function s = boolStr(flag)
if flag
    s = 'true';
else
    s = 'false';
end
end

function out = ternary(cond, a, b)
if cond
    out = a;
else
    out = b;
end
end
