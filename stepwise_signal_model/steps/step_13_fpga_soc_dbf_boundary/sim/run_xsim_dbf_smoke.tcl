# Step13.3 Vivado XSim smoke for DBF accumulator and Z24 output datapath.
#
# Run with Vivado Tcl from the Step13 directory or from sim/:
#   vivado -mode batch -source sim/run_xsim_dbf_smoke.tcl
#   vivado -mode batch -source run_xsim_dbf_smoke.tcl
#
# This script does not claim formal closure and does not implement Rz,
# G_cache, 2D ML, topK, C05, confidence, boundary, or fallback logic.

proc step13_bool_text {value} {
    if {$value} {
        return "true"
    }
    return "false"
}

proc step13_write_summary {step_dir status xvlog_found xelab_found xsim_found mac_status core_status z24_quant_status z24_core_status acc_csv_created z24_csv_created note} {
    set summary_path [file join $step_dir results_step13_fpga_soc_dbf_boundary rtl_sim step13_dbf_rtl_sim_summary.csv]
    set fh [open $summary_path w]
    puts $fh "metric,value"
    puts $fh "simulation_status,$status"
    puts $fh "overall_simulation_status,$status"
    puts $fh "tool_xvlog_found,[step13_bool_text $xvlog_found]"
    puts $fh "tool_xelab_found,[step13_bool_text $xelab_found]"
    puts $fh "tool_xsim_found,[step13_bool_text $xsim_found]"
    puts $fh "dbf_complex_mac_smoke,$mac_status"
    puts $fh "dbf_core_accum_smoke,$core_status"
    puts $fh "dbf_z24_quantizer_smoke,$z24_quant_status"
    puts $fh "dbf_core_z24_smoke,$z24_core_status"
    puts $fh "raw_accumulator_status,$core_status"
    puts $fh "z24_quantizer_status,$z24_quant_status"
    puts $fh "dbf_core_accum_output_csv_created,[step13_bool_text $acc_csv_created]"
    puts $fh "dbf_core_z24_output_csv_created,[step13_bool_text $z24_csv_created]"
    puts $fh "formal_result_claimed,false"
    puts $fh "scope,DBF accumulator plus Z24 shift-round-saturate output datapath"
    puts $fh "z24_shift_round_saturate_implemented,true"
    puts $fh "rz_gcache_ml_topk_c05_implemented,false"
    puts $fh "rz_gcache_ml_topk_c05_cpu_soc_responsibility,true"
    puts $fh "note,$note"
    close $fh
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
        set parent [file normalize [file join $script_dir ..]]
        if {[file isdirectory [file join $parent rtl]] && [file isdirectory [file join $parent tb]] && [file isdirectory [file join $parent sim]]} {
            return $parent
        }
    }
    error "Cannot locate Step13 DBF boundary directory."
}

proc step13_tool_found {tool_name} {
    set result [catch {exec $tool_name -version} msg]
    return [expr {$result == 0}]
}

proc step13_run_checked {description args_list} {
    puts "STEP13_XSIM: $description"
    set result [catch {exec {*}$args_list} msg]
    if {$result != 0} {
        puts "STEP13_XSIM_FAIL: $description"
        puts $msg
        return [list 0 $msg]
    }
    puts $msg
    return [list 1 $msg]
}

set step_dir [step13_find_root]
cd $step_dir

set sim_dir [file join $step_dir results_step13_fpga_soc_dbf_boundary rtl_sim]
file mkdir $sim_dir
file delete -force [file join $sim_dir dbf_core_accum_output.csv]
file delete -force [file join $sim_dir dbf_core_z24_output.csv]
file delete -force [file join $sim_dir step13_dbf_rtl_sim_summary.csv]
file delete -force [file join $sim_dir xsim.dir]

set xvlog_found [step13_tool_found xvlog]
set xelab_found [step13_tool_found xelab]
set xsim_found [step13_tool_found xsim]

if {!$xvlog_found || !$xelab_found || !$xsim_found} {
    step13_write_summary $step_dir "unavailable" $xvlog_found $xelab_found $xsim_found "not_run" "not_run" "not_run" "not_run" 0 0 "xsim_tools_not_available"
    error "Vivado XSim tools unavailable. Run from Vivado Tcl Shell or a terminal with Vivado settings64.bat loaded."
}

set golden_vh [file join $step_dir results_step13_fpga_soc_dbf_boundary rtl_golden step13_dbf_rtl_golden_vectors.vh]
if {![file exists $golden_vh]} {
    step13_write_summary $step_dir "unavailable" $xvlog_found $xelab_found $xsim_found "not_run" "not_run" "not_run" "not_run" 0 0 "golden_vectors_not_available"
    error "Missing results_step13_fpga_soc_dbf_boundary/rtl_golden/step13_dbf_rtl_golden_vectors.vh"
}

set all_vlog_files [list \
    rtl/dbf_complex_mac.v \
    rtl/dbf_beam_accum_core.v \
    rtl/dbf_core_accum.v \
    rtl/dbf_z24_quantizer.v \
    tb/tb_dbf_complex_mac.v \
    tb/tb_dbf_core_accum.v \
    tb/tb_dbf_z24_quantizer.v \
    tb/tb_dbf_core_z24.v]
set include_dir results_step13_fpga_soc_dbf_boundary/rtl_golden

set result [step13_run_checked "xvlog compile RTL and testbenches" [list xvlog -nolog -i $include_dir {*}$all_vlog_files]]
if {![lindex $result 0]} {
    step13_write_summary $step_dir "fail" $xvlog_found $xelab_found $xsim_found "not_run" "not_run" "not_run" "not_run" 0 0 "xvlog_compile_failed"
    error "xvlog compile failed"
}

set result [step13_run_checked "xelab tb_dbf_complex_mac" [list xelab -nolog -debug off tb_dbf_complex_mac -s tb_dbf_complex_mac_sim]]
if {![lindex $result 0]} {
    step13_write_summary $step_dir "fail" $xvlog_found $xelab_found $xsim_found "not_run" "not_run" "not_run" "not_run" 0 0 "xelab_tb_dbf_complex_mac_failed"
    error "xelab tb_dbf_complex_mac failed"
}

set result [step13_run_checked "xsim tb_dbf_complex_mac" [list xsim tb_dbf_complex_mac_sim -nolog -tclbatch sim/xsim_run_all.tcl]]
set mac_ok [lindex $result 0]
if {!$mac_ok} {
    step13_write_summary $step_dir "fail" $xvlog_found $xelab_found $xsim_found "fail" "not_run" "not_run" "not_run" 0 0 "xsim_tb_dbf_complex_mac_failed"
    error "xsim tb_dbf_complex_mac failed"
}

set result [step13_run_checked "xelab tb_dbf_core_accum" [list xelab -nolog -debug off tb_dbf_core_accum -s tb_dbf_core_accum_sim]]
if {![lindex $result 0]} {
    step13_write_summary $step_dir "fail" $xvlog_found $xelab_found $xsim_found "pass" "not_run" "not_run" "not_run" 0 0 "xelab_tb_dbf_core_accum_failed"
    error "xelab tb_dbf_core_accum failed"
}

set result [step13_run_checked "xsim tb_dbf_core_accum" [list xsim tb_dbf_core_accum_sim -nolog -tclbatch sim/xsim_run_all.tcl]]
set core_ok [lindex $result 0]
set csv_path [file join $step_dir results_step13_fpga_soc_dbf_boundary rtl_sim dbf_core_accum_output.csv]
set csv_created [file exists $csv_path]
if {!$core_ok} {
    step13_write_summary $step_dir "fail" $xvlog_found $xelab_found $xsim_found "pass" "fail" "not_run" "not_run" $csv_created 0 "xsim_tb_dbf_core_accum_failed"
    error "xsim tb_dbf_core_accum failed"
}
if {!$csv_created} {
    step13_write_summary $step_dir "fail" $xvlog_found $xelab_found $xsim_found "pass" "fail" "not_run" "not_run" 0 0 "dbf_core_accum_output_csv_missing"
    error "dbf_core_accum_output.csv was not created"
}

set result [step13_run_checked "xelab tb_dbf_z24_quantizer" [list xelab -nolog -debug off tb_dbf_z24_quantizer -s tb_dbf_z24_quantizer_sim]]
if {![lindex $result 0]} {
    step13_write_summary $step_dir "fail" $xvlog_found $xelab_found $xsim_found "pass" "pass" "not_run" "not_run" 1 0 "xelab_tb_dbf_z24_quantizer_failed"
    error "xelab tb_dbf_z24_quantizer failed"
}

set result [step13_run_checked "xsim tb_dbf_z24_quantizer" [list xsim tb_dbf_z24_quantizer_sim -nolog -tclbatch sim/xsim_run_all.tcl]]
set z24_quant_ok [lindex $result 0]
if {!$z24_quant_ok} {
    step13_write_summary $step_dir "fail" $xvlog_found $xelab_found $xsim_found "pass" "pass" "fail" "not_run" 1 0 "xsim_tb_dbf_z24_quantizer_failed"
    error "xsim tb_dbf_z24_quantizer failed"
}

set result [step13_run_checked "xelab tb_dbf_core_z24" [list xelab -nolog -debug off tb_dbf_core_z24 -s tb_dbf_core_z24_sim]]
if {![lindex $result 0]} {
    step13_write_summary $step_dir "fail" $xvlog_found $xelab_found $xsim_found "pass" "pass" "pass" "not_run" 1 0 "xelab_tb_dbf_core_z24_failed"
    error "xelab tb_dbf_core_z24 failed"
}

set result [step13_run_checked "xsim tb_dbf_core_z24" [list xsim tb_dbf_core_z24_sim -nolog -tclbatch sim/xsim_run_all.tcl]]
set z24_core_ok [lindex $result 0]
set z24_csv_path [file join $step_dir results_step13_fpga_soc_dbf_boundary rtl_sim dbf_core_z24_output.csv]
set z24_csv_created [file exists $z24_csv_path]
if {!$z24_core_ok} {
    step13_write_summary $step_dir "fail" $xvlog_found $xelab_found $xsim_found "pass" "pass" "pass" "fail" 1 $z24_csv_created "xsim_tb_dbf_core_z24_failed"
    error "xsim tb_dbf_core_z24 failed"
}
if {!$z24_csv_created} {
    step13_write_summary $step_dir "fail" $xvlog_found $xelab_found $xsim_found "pass" "pass" "pass" "fail" 1 0 "dbf_core_z24_output_csv_missing"
    error "dbf_core_z24_output.csv was not created"
}

step13_write_summary $step_dir "pass" $xvlog_found $xelab_found $xsim_found "pass" "pass" "pass" "pass" 1 1 "xsim_raw_accumulator_and_z24_smoke_passed"
puts "STEP13_XSIM_PASS: raw DBF accumulator and Z24 output smoke completed."
