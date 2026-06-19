set script_dir [file dirname [file normalize [info script]]]
set step14_dir [file normalize [file join $script_dir ".."]]
cd $step14_dir

set sim_dir [file normalize "results_step14_dbf_ip_soc_integration/axis_sim"]
file mkdir $sim_dir
set summary_path [file join $sim_dir "step14_1_axis_xsim_summary.csv"]

proc write_xsim_summary {path compile_status elaboration_status simulation_status} {
    set fh [open $path "w"]
    puts $fh "metric,value"
    puts $fh "tool_xvlog_found,true"
    puts $fh "tool_xelab_found,true"
    puts $fh "tool_xsim_found,true"
    puts $fh "compile_status,$compile_status"
    puts $fh "elaboration_status,$elaboration_status"
    puts $fh "simulation_status,$simulation_status"
    puts $fh [format "tb_summary_created,%s" [expr {[file exists "results_step14_dbf_ip_soc_integration/axis_sim/step14_1_axis_tb_summary.csv"] ? "true" : "false"}]]
    puts $fh [format "axis_output_csv_created,%s" [expr {[file exists "results_step14_dbf_ip_soc_integration/axis_sim/step14_1_axis_output.csv"] ? "true" : "false"}]]
    puts $fh "formal_result_claimed,false"
    puts $fh "dma_validation_flag,false"
    puts $fh "ps_validation_flag,false"
    puts $fh "board_validation_flag,false"
    close $fh
}

set files [list \
    "../step_13_fpga_soc_dbf_boundary/rtl/dbf_complex_mac.v" \
    "../step_13_fpga_soc_dbf_boundary/rtl/dbf_beam_accum_core.v" \
    "../step_13_fpga_soc_dbf_boundary/rtl/dbf_z24_quantizer.v" \
    "../step_13_fpga_soc_dbf_boundary/rtl/dbf_core_z24.v" \
    "../step_13_fpga_soc_dbf_boundary/rtl/dbf_core_z24_bparallel.v" \
    "rtl/dbf_w_provider_rom.v" \
    "rtl/dbf_axis_z_serializer.v" \
    "rtl/dbf_axis_datapath.v" \
    "rtl/dbf_axis_system_top.v" \
    "tb/tb_dbf_axis_system_top.v" \
]

set compile_status "pass"
if {[catch {eval xvlog -sv $files} err]} {
    puts $err
    set compile_status "fail"
    write_xsim_summary $summary_path $compile_status "not_run" "not_run"
    exit 1
}

set elaboration_status "pass"
if {[catch {xelab tb_dbf_axis_system_top -debug typical -s step14_1_axis_sim} err]} {
    puts $err
    set elaboration_status "fail"
    write_xsim_summary $summary_path $compile_status $elaboration_status "not_run"
    exit 1
}

set simulation_status "pass"
if {[catch {xsim step14_1_axis_sim -tclbatch sim/xsim_step14_1_run_all.tcl} err]} {
    puts $err
    set simulation_status "fail"
}

write_xsim_summary $summary_path $compile_status $elaboration_status $simulation_status
if {$simulation_status ne "pass"} {
    exit 1
}
