set script_dir [file dirname [file normalize [info script]]]
set step14_dir [file normalize [file join $script_dir ".."]]
cd $step14_dir

set sim_dir [file normalize "results_step14_dbf_ip_soc_integration/axis_opt_sim"]
file mkdir $sim_dir
set summary_path [file join $sim_dir "step14_2a_opt_axis_xsim_summary.csv"]

proc write_xsim_summary {path compile_status elaboration_status simulation_status} {
    set fh [open $path "w"]
    puts $fh "metric,value"
    puts $fh "tool_xvlog_found,true"
    puts $fh "tool_xelab_found,true"
    puts $fh "tool_xsim_found,true"
    puts $fh "compile_status,$compile_status"
    puts $fh "elaboration_status,$elaboration_status"
    puts $fh "simulation_status,$simulation_status"
    puts $fh [format "tb_summary_created,%s" [expr {[file exists "results_step14_dbf_ip_soc_integration/axis_opt_sim/step14_2a_opt_axis_tb_summary.csv"] ? "true" : "false"}]]
    puts $fh [format "axis_output_csv_created,%s" [expr {[file exists "results_step14_dbf_ip_soc_integration/axis_opt_sim/step14_2a_opt_axis_output.csv"] ? "true" : "false"}]]
    puts $fh "formal_result_claimed,false"
    close $fh
}

proc tb_pass_flag {} {
    set tb_summary_path "results_step14_dbf_ip_soc_integration/axis_opt_sim/step14_2a_opt_axis_tb_summary.csv"
    if {![file exists $tb_summary_path]} {
        return 0
    }
    set fh [open $tb_summary_path "r"]
    set pass 0
    while {[gets $fh line] >= 0} {
        if {$line eq "optimized_raw_top_xsim_pass_flag,true"} {
            set pass 1
        }
    }
    close $fh
    return $pass
}

set files [list \
    "rtl/dbf_complex_mac_pipe.v" \
    "rtl/dbf_beam_accum_core_pipe.v" \
    "rtl/dbf_z24_quantizer_pipe.v" \
    "rtl/dbf_core_z24_pipe.v" \
    "rtl/dbf_core_z24_bparallel_pipe.v" \
    "rtl/dbf_w_rom18_split.v" \
    "rtl/dbf_w_provider_rom_opt.v" \
    "rtl/dbf_axis_z_serializer.v" \
    "rtl/dbf_axis_datapath_pipe.v" \
    "rtl/dbf_axis_system_top_opt.v" \
    "tb/tb_dbf_axis_system_top_opt.v" \
]

set compile_status "pass"
if {[catch {exec xvlog -sv {*}$files} err]} {
    puts $err
    set compile_status "fail"
    write_xsim_summary $summary_path $compile_status "not_run" "not_run"
    exit 1
}

set elaboration_status "pass"
if {[catch {exec xelab tb_dbf_axis_system_top_opt -debug typical -L xpm -s step14_2a_opt_axis_sim} err]} {
    puts $err
    set elaboration_status "fail"
    write_xsim_summary $summary_path $compile_status $elaboration_status "not_run"
    exit 1
}

set run_tcl [file join $sim_dir "xsim_step14_2a_run_all.tcl"]
set fh [open $run_tcl "w"]
puts $fh "run all"
puts $fh "quit"
close $fh

set simulation_status "pass"
if {[catch {exec xsim step14_2a_opt_axis_sim -tclbatch $run_tcl} err]} {
    puts $err
    set simulation_status "fail"
}

write_xsim_summary $summary_path $compile_status $elaboration_status $simulation_status
if {$simulation_status ne "pass"} {
    exit 1
}
if {![tb_pass_flag]} {
    write_xsim_summary $summary_path $compile_status $elaboration_status "fail"
    exit 1
}
