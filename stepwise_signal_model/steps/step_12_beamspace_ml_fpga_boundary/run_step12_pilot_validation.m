setenv('STEP12_QUICK_MODE', '0');
setenv('STEP12_FORMAL_TRIALS_PER_SCENARIO', '10');
setenv('STEP12_FORMAL_CENTER_AZ_LIST', '0,4,8,15');
setenv('STEP12_MIN_FORMAL_OBS', '100');
setenv('STEP12_RUN_TAG', 'pilot_tps10');

run_step12_beamspace_ml_fpga_boundary
