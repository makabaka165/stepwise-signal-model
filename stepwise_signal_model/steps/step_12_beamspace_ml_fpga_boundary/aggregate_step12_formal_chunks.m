setenv('STEP12_QUICK_MODE', '0');
setenv('STEP12_AGGREGATE_ONLY', '1');
if isempty(getenv('STEP12_RUN_TAG'))
    setenv('STEP12_RUN_TAG', 'formal_tps30');
end
if isempty(getenv('STEP12_FORMAL_TRIALS_PER_SCENARIO'))
    setenv('STEP12_FORMAL_TRIALS_PER_SCENARIO', '30');
end
if isempty(getenv('STEP12_FORMAL_CENTER_AZ_LIST'))
    setenv('STEP12_FORMAL_CENTER_AZ_LIST', '0,4,8,15');
end
if isempty(getenv('STEP12_MIN_FORMAL_OBS'))
    setenv('STEP12_MIN_FORMAL_OBS', '300');
end
if isempty(getenv('STEP12_MODE_SET'))
    setenv('STEP12_MODE_SET', 'formal_core');
end

run_step12_beamspace_ml_fpga_boundary
