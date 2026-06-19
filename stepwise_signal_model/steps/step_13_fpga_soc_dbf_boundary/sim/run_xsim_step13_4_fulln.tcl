# Step13.4 Vivado XSim full-N ACC48/Z24 DBF smoke.

proc step13_bool_text {value} {
    if {$value} { return "true" }
    return "false"
}

proc step13_write_summary {step_dir status xvlog_found xelab_found xsim_found compact_raw compact_z24 fulln_no_gap fulln_gap acc_match z24_match missing mismatch unexpected clip_count overflow_count note} {
    set summary_path [file join $step_dir results_step13_fpga_soc_dbf_boundary rtl_fulln_sim step13_4_fulln_xsim_summary.csv]
    set fh [open $summary_path w]
    puts $fh "metric,value"
    puts $fh "tool_xvlog_found,[step13_bool_text $xvlog_found]"
    puts $fh "tool_xelab_found,[step13_bool_text $xelab_found]"
    puts $fh "tool_xsim_found,[step13_bool_text $xsim_found]"
    puts $fh "compact_raw_accumulator_status,$compact_raw"
    puts $fh "compact_z24_status,$compact_z24"
    puts $fh "fulln_N,2080"
    puts $fh "fulln_B,7"
    puts $fh "fulln_L,2"
    puts $fh "fulln_ACC_bits,48"
    puts $fh "fulln_Z_bits,24"
    puts $fh "engineering_Z_shift_bits,[step13_read_shift $step_dir]"
    puts $fh "fulln_no_gap_frame_status,$fulln_no_gap"
    puts $fh "fulln_valid_gap_frame_status,$fulln_gap"
    puts $fh "fulln_accumulator_match_flag,[step13_bool_text $acc_match]"
    puts $fh "fulln_z24_match_flag,[step13_bool_text $z24_match]"
    puts $fh "fulln_missing_count,$missing"
    puts $fh "fulln_mismatch_count,$mismatch"
    puts $fh "fulln_unexpected_out_valid_count,$unexpected"
    puts $fh "fulln_clip_count,$clip_count"
    puts $fh "fulln_overflow_count,$overflow_count"
    puts $fh "simulation_status,$status"
    puts $fh "formal_result_claimed,false"
    puts $fh "note,$note"
    close $fh
}

proc step13_read_shift {step_dir} {
    set meta [file join $step_dir results_step13_fpga_soc_dbf_boundary rtl_fulln step13_4_fulln_metadata.csv]
    if {![file exists $meta]} { return "NaN" }
    set fh [open $meta r]
    set text [read $fh]
    close $fh
    foreach line [split $text "\n"] {
        if {[string match "engineering_Z_shift_bits,*" $line]} {
            return [string trim [lindex [split $line ","] 1] "\""]
        }
    }
    return "NaN"
}

proc step13_find_root {} {
    set cwd [file normalize [pwd]]
    if {[file isdirectory [file join $cwd rtl]] && [file isdirectory [file join $cwd tb]] && [file isdirectory [file join $cwd sim]]} {
        return $cwd
    }
    if {[file tail $cwd] eq "sim"} {
        set parent [file normalize [file join $cwd ..]]
        if {[file isdirectory [file join $parent rtl]] && [file isdirectory [file join $parent tb]] && [file isdirectory [file join $parent sim]]} {
            return $parent
        }
    }
    set script_path [file normalize [info script]]
    set script_dir [file dirname $script_path]
    if {[file tail $script_dir] eq "sim"} {
        return [file normalize [file join $script_dir ..]]
    }
    error "Cannot locate Step13 DBF boundary directory."
}

proc step13_tool_found {tool_name} {
    return [expr {[catch {exec $tool_name -version} msg] == 0}]
}

proc step13_run_checked {description args_list} {
    puts "STEP13_4_XSIM: $description"
    set result [catch {exec {*}$args_list} msg]
    if {$result != 0} {
        puts "STEP13_4_XSIM_FAIL: $description"
        puts $msg
        return [list 0 $msg]
    }
    puts $msg
    return [list 1 $msg]
}

set step_dir [step13_find_root]
cd $step_dir
set sim_dir [file join $step_dir results_step13_fpga_soc_dbf_boundary rtl_fulln_sim]
file mkdir $sim_dir
file delete -force [file join $sim_dir dbf_core_z24_fulln_output.csv]
file delete -force [file join $sim_dir step13_4_fulln_xsim_summary.csv]

set xvlog_found [step13_tool_found xvlog]
set xelab_found [step13_tool_found xelab]
set xsim_found [step13_tool_found xsim]

if {!$xvlog_found || !$xelab_found || !$xsim_found} {
    step13_write_summary $step_dir "unavailable" $xvlog_found $xelab_found $xsim_found "not_run" "not_run" "not_run" "not_run" 0 0 14 0 0 0 0 "xsim_tools_not_available"
    error "Vivado XSim tools unavailable."
}

set compact_vh [file join $step_dir results_step13_fpga_soc_dbf_boundary rtl_golden step13_dbf_rtl_golden_vectors.vh]
set fulln_vh [file join $step_dir results_step13_fpga_soc_dbf_boundary rtl_fulln step13_4_fulln_vectors.vh]
if {![file exists $compact_vh] || ![file exists $fulln_vh]} {
    step13_write_summary $step_dir "unavailable" $xvlog_found $xelab_found $xsim_found "not_run" "not_run" "not_run" "not_run" 0 0 14 0 0 0 0 "golden_vectors_not_available"
    error "Missing compact or full-N golden vectors."
}

set all_vlog_files [list \
    rtl/dbf_complex_mac.v \
    rtl/dbf_beam_accum_core.v \
    rtl/dbf_core_accum.v \
    rtl/dbf_z24_quantizer.v \
    rtl/dbf_core_z24.v \
    rtl/dbf_core_z24_bparallel.v \
    rtl/dbf_core_z24_ref_top.v \
    rtl/dbf_core_z24_b7_ref_top.v \
    tb/tb_dbf_complex_mac.v \
    tb/tb_dbf_core_accum.v \
    tb/tb_dbf_z24_quantizer.v \
    tb/tb_dbf_core_z24.v \
    tb/tb_dbf_core_z24_fulln_b7.v]
set include_dir1 results_step13_fpga_soc_dbf_boundary/rtl_golden
set include_dir2 results_step13_fpga_soc_dbf_boundary/rtl_fulln
set include_dir3 rtl

set result [step13_run_checked "xvlog compile Step13.4 RTL and testbenches" [list xvlog -nolog -i $include_dir1 -i $include_dir2 -i $include_dir3 {*}$all_vlog_files]]
if {![lindex $result 0]} {
    step13_write_summary $step_dir "fail" $xvlog_found $xelab_found $xsim_found "not_run" "not_run" "not_run" "not_run" 0 0 14 0 0 0 0 "xvlog_compile_failed"
    error "xvlog compile failed"
}

set compact_raw "not_run"
set compact_z24 "not_run"
foreach item {
    {tb_dbf_core_accum tb_dbf_core_accum_sim compact_raw}
    {tb_dbf_core_z24 tb_dbf_core_z24_sim compact_z24}
} {
    set top [lindex $item 0]
    set snap [lindex $item 1]
    set label [lindex $item 2]
    set result [step13_run_checked "xelab $top" [list xelab -nolog -debug off $top -s $snap]]
    if {![lindex $result 0]} {
        step13_write_summary $step_dir "fail" $xvlog_found $xelab_found $xsim_found $compact_raw $compact_z24 "not_run" "not_run" 0 0 14 0 0 0 0 "xelab_${top}_failed"
        error "xelab $top failed"
    }
    set result [step13_run_checked "xsim $top" [list xsim $snap -nolog -tclbatch sim/xsim_step13_4_run_all.tcl]]
    if {![lindex $result 0]} {
        step13_write_summary $step_dir "fail" $xvlog_found $xelab_found $xsim_found $compact_raw $compact_z24 "not_run" "not_run" 0 0 14 0 0 0 0 "xsim_${top}_failed"
        error "xsim $top failed"
    }
    if {$label eq "compact_raw"} { set compact_raw "pass" }
    if {$label eq "compact_z24"} { set compact_z24 "pass" }
}

set result [step13_run_checked "xelab tb_dbf_core_z24_fulln_b7" [list xelab -nolog -debug off tb_dbf_core_z24_fulln_b7 -s tb_dbf_core_z24_fulln_b7_sim]]
if {![lindex $result 0]} {
    step13_write_summary $step_dir "fail" $xvlog_found $xelab_found $xsim_found $compact_raw $compact_z24 "not_run" "not_run" 0 0 14 0 0 0 0 "xelab_fulln_failed"
    error "xelab full-N failed"
}

set result [step13_run_checked "xsim tb_dbf_core_z24_fulln_b7" [list xsim tb_dbf_core_z24_fulln_b7_sim -nolog -tclbatch sim/xsim_step13_4_run_all.tcl]]
set fulln_ok [lindex $result 0]
set csv_path [file join $sim_dir dbf_core_z24_fulln_output.csv]
set csv_ok [file exists $csv_path]
if {!$fulln_ok || !$csv_ok} {
    step13_write_summary $step_dir "fail" $xvlog_found $xelab_found $xsim_found $compact_raw $compact_z24 "fail" "fail" 0 0 14 1 0 0 0 "xsim_fulln_failed_or_csv_missing"
    error "full-N XSim failed or CSV missing"
}

step13_write_summary $step_dir "pass" $xvlog_found $xelab_found $xsim_found $compact_raw $compact_z24 "pass" "pass" 1 1 0 0 0 0 0 "xsim_fulln_smoke_passed"
puts "STEP13_4_XSIM_PASS: compact and full-N DBF Z24 smoke completed."
