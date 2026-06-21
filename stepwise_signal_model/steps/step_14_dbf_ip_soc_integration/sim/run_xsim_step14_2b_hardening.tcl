set script_dir [file dirname [file normalize [info script]]]
set step14_dir [file normalize [file join $script_dir ".."]]
cd $step14_dir

set hardening_dir [file normalize "results_step14_dbf_ip_soc_integration/hardening"]
file mkdir $hardening_dir
set summary_path [file join $hardening_dir "step14_2b_hardening_xsim_summary.csv"]

proc write_xsim_summary {path compile_status w_elab w_sim q_elab q_sim} {
    set w_summary "results_step14_dbf_ip_soc_integration/hardening/step14_2b_w_provider_boundary_summary.csv"
    set q_summary "results_step14_dbf_ip_soc_integration/hardening/step14_2b_quantizer_equiv_summary.csv"
    set w_pass false
    set q_pass false
    if {[file exists $w_summary]} {
        set fh [open $w_summary "r"]
        while {[gets $fh line] >= 0} {
            if {$line eq "w_provider_boundary_pass,true"} { set w_pass true }
        }
        close $fh
    }
    if {[file exists $q_summary]} {
        set fh [open $q_summary "r"]
        while {[gets $fh line] >= 0} {
            if {$line eq "quantizer_pipe_equivalence_pass,true"} { set q_pass true }
        }
        close $fh
    }
    set fh [open $path "w"]
    puts $fh "metric,value"
    puts $fh "tool_xvlog_found,true"
    puts $fh "tool_xelab_found,true"
    puts $fh "tool_xsim_found,true"
    puts $fh "compile_status,$compile_status"
    puts $fh "w_provider_elaboration_status,$w_elab"
    puts $fh "w_provider_simulation_status,$w_sim"
    puts $fh "quantizer_elaboration_status,$q_elab"
    puts $fh "quantizer_simulation_status,$q_sim"
    puts $fh [format "w_provider_summary_created,%s" [expr {[file exists $w_summary] ? "true" : "false"}]]
    puts $fh [format "quantizer_summary_created,%s" [expr {[file exists $q_summary] ? "true" : "false"}]]
    puts $fh "w_provider_boundary_pass,$w_pass"
    puts $fh "quantizer_pipe_equivalence_pass,$q_pass"
    puts $fh [format "step14_2b_hardening_source_xsim_pass,%s" [expr {$w_pass && $q_pass && $compile_status eq "pass" && $w_elab eq "pass" && $w_sim eq "pass" && $q_elab eq "pass" && $q_sim eq "pass" ? "true" : "false"}]]
    puts $fh "formal_result_claimed,false"
    puts $fh "dma_validation_flag,false"
    puts $fh "ps_validation_flag,false"
    puts $fh "board_validation_flag,false"
    close $fh
}

set files [list \
    "../step_13_fpga_soc_dbf_boundary/rtl/dbf_z24_quantizer.v" \
    "rtl/dbf_z24_quantizer_pipe.v" \
    "rtl/dbf_w_rom18_split.v" \
    "rtl/dbf_w_provider_rom_opt.v" \
    "tb/tb_dbf_w_provider_rom_opt_boundary.v" \
    "tb/tb_dbf_z24_quantizer_pipe_equiv.v" \
]

set compile_status "pass"
if {[catch {exec xvlog -sv {*}$files} err]} {
    puts $err
    set compile_status "fail"
    write_xsim_summary $summary_path $compile_status "not_run" "not_run" "not_run" "not_run"
    exit 1
}

set w_elab "pass"
if {[catch {exec xelab tb_dbf_w_provider_rom_opt_boundary -debug typical -L xpm -s step14_2b_w_provider_boundary_sim} err]} {
    puts $err
    set w_elab "fail"
    write_xsim_summary $summary_path $compile_status $w_elab "not_run" "not_run" "not_run"
    exit 1
}

set run_tcl_w [file join $hardening_dir "xsim_step14_2b_w_provider_run_all.tcl"]
set fh [open $run_tcl_w "w"]
puts $fh "run all"
puts $fh "quit"
close $fh

set w_sim "pass"
if {[catch {exec xsim step14_2b_w_provider_boundary_sim -tclbatch $run_tcl_w} err]} {
    puts $err
    set w_sim "fail"
}

set q_elab "pass"
if {[catch {exec xelab tb_dbf_z24_quantizer_pipe_equiv -debug typical -L xpm -s step14_2b_quantizer_equiv_sim} err]} {
    puts $err
    set q_elab "fail"
    write_xsim_summary $summary_path $compile_status $w_elab $w_sim $q_elab "not_run"
    exit 1
}

set run_tcl_q [file join $hardening_dir "xsim_step14_2b_quantizer_run_all.tcl"]
set fh [open $run_tcl_q "w"]
puts $fh "run all"
puts $fh "quit"
close $fh

set q_sim "pass"
if {[catch {exec xsim step14_2b_quantizer_equiv_sim -tclbatch $run_tcl_q} err]} {
    puts $err
    set q_sim "fail"
}

write_xsim_summary $summary_path $compile_status $w_elab $w_sim $q_elab $q_sim
if {$w_sim ne "pass" || $q_sim ne "pass"} {
    exit 1
}
