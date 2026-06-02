set step_dir [file normalize [file join [file dirname [info script]] ".."]]

proc run_step12_tb {tb_name rtl_name step_dir} {
    puts "Running $tb_name"
    exec xvlog -sv [file join $step_dir rtl "${rtl_name}.v"] [file join $step_dir tb "${tb_name}.v"]
    exec xelab $tb_name -s "${tb_name}_sim"
    exec xsim "${tb_name}_sim" -runall
}

run_step12_tb tb_shared_center_column_selector shared_center_column_selector $step_dir
run_step12_tb tb_y_work_packer y_work_packer $step_dir
run_step12_tb tb_projection_score_core projection_score_core $step_dir

puts "All Step12 xsim simulations completed."
