set script_dir [file dirname [file normalize [info script]]]
set timing_dir [file normalize $script_dir]
set vivado_dir [file dirname $timing_dir]
set step14_dir [file dirname $vivado_dir]
set result_dir [file join $step14_dir "results_step14_dbf_ip_soc_integration" "reference_bd_timing"]
set work_dir [file join $step14_dir "vivado" "work" "step14_3b_timing_closure"]
file mkdir $result_dir

source [file join $timing_dir "run_reference_bd_strategy_sweep.tcl"]
set work_dir [file join $step14_dir "vivado" "work" "step14_3b_timing_closure"]

proc read_metric {path key default_value} {
    if {![file exists $path]} { return $default_value }
    set fh [open $path r]
    gets $fh
    set value $default_value
    while {[gets $fh line] >= 0} {
        set comma [string first "," $line]
        if {$comma > 0} {
            set k [string trim [string range $line 0 [expr {$comma - 1}]]]
            set v [string trim [string range $line [expr {$comma + 1}] end]]
            if {$k eq $key} { set value $v }
        }
    }
    close $fh
    return $value
}

set best_path [file join $result_dir "step14_3b_best_strategy.csv"]
set phase_a_pass [expr {[read_metric $best_path phase_a_strategy_sweep_pass_flag false] eq "true"}]
set best_strategy [read_metric $best_path best_strategy_name NA]

if {!$phase_a_pass} {
    write_pairs [file join $result_dir "step14_3b_best_strategy_clean_rerun_summary.csv"] [list \
        [list clean_rerun_status not_run] \
        [list best_strategy_name $best_strategy] \
        [list phase_a_clean_rerun_pass_flag false] \
        [list phase_b_required_flag true] \
        [list blocker_if_any phase_a_strategy_sweep_margin_not_met]]
    return
}

set old_result_dir $result_dir
set old_work_dir $work_dir
set result_dir $old_result_dir
safe_rebuild_dir $step14_dir $old_work_dir "step14_3b_timing_closure"
create_project step14_3b_timing_closure $old_work_dir -part xc7z020clg400-1 -force
set_property ip_repo_paths [file join $step14_dir "ip_repo"] [current_project]
update_ip_catalog
set ::STEP14_REFBD_CLOCK_HZ 200000000
source [file join $vivado_dir "reference_bd" "create_dbf_reference_bd.tcl"]
validate_bd_design
generate_target all [get_files dbf_reference_bd.bd]
set wrapper_files [make_wrapper -files [get_files dbf_reference_bd.bd] -top]
foreach wf $wrapper_files { add_files -norecurse $wf }
add_files -fileset constrs_1 [file join $step14_dir "constraints" "step14_3a_reference_bd.xdc"]
set_property top dbf_reference_bd_wrapper [current_fileset]
set_property {STEPS.SYNTH_DESIGN.ARGS.MORE OPTIONS} { -mode out_of_context} [get_runs synth_1]
update_compile_order -fileset sources_1
launch_runs synth_1 -jobs 4
wait_on_run synth_1
set clean_run [create_impl_run_safe clean_rerun_best synth_1]
if {$best_strategy eq "baseline_step14_3a"} {
    set_run_property_if_exists $clean_run STEPS.OPT_DESIGN.ARGS.DIRECTIVE Explore
    set_run_property_if_exists $clean_run STEPS.PLACE_DESIGN.ARGS.DIRECTIVE ExtraNetDelay_high
    set_run_property_if_exists $clean_run STEPS.PHYS_OPT_DESIGN.IS_ENABLED true
    set_run_property_if_exists $clean_run STEPS.PHYS_OPT_DESIGN.ARGS.DIRECTIVE AggressiveExplore
    set_run_property_if_exists $clean_run STEPS.ROUTE_DESIGN.ARGS.DIRECTIVE AggressiveExplore
    set_run_property_if_exists $clean_run STEPS.POST_ROUTE_PHYS_OPT_DESIGN.IS_ENABLED true
    set_run_property_if_exists $clean_run STEPS.POST_ROUTE_PHYS_OPT_DESIGN.ARGS.DIRECTIVE AggressiveExplore
} else {
    set_property strategy $best_strategy $clean_run
}
set rec [launch_and_collect_run clean_rerun_best clean_rerun_best $best_strategy $result_dir $step14_dir dbf_reference_bd_wrapper "step14_3b_clean_rerun"]
set clean_pass [expr {[dict get $rec timing_margin_pass_flag] eq "true"}]
write_pairs [file join $result_dir "step14_3b_best_strategy_clean_rerun_summary.csv"] [list \
    [list clean_rerun_status [dict get $rec run_status]] \
    [list best_strategy_name $best_strategy] \
    [list final_WNS_ns [dict get $rec WNS_ns]] \
    [list final_TNS_ns [dict get $rec TNS_ns]] \
    [list final_setup_failing_endpoints [dict get $rec setup_failing_endpoints]] \
    [list final_WHS_ns [dict get $rec WHS_ns]] \
    [list final_hold_failing_endpoints [dict get $rec hold_failing_endpoints]] \
    [list final_LUT [dict get $rec LUT]] \
    [list final_FF [dict get $rec FF]] \
    [list final_DSP [dict get $rec DSP]] \
    [list final_BRAM18 [dict get $rec BRAM18]] \
    [list final_BRAM36 [dict get $rec BRAM36]] \
    [list final_URAM [dict get $rec URAM]] \
    [list step14_3b_post_route_timing_pass_flag [dict get $rec timing_met_flag]] \
    [list step14_3b_timing_margin_pass_flag [dict get $rec timing_margin_pass_flag]] \
    [list phase_a_clean_rerun_pass_flag [bool_str $clean_pass]] \
    [list phase_b_required_flag [bool_str [expr {!$clean_pass}]]] \
    [list blocker_if_any [expr {$clean_pass ? "" : "phase_a_clean_rerun_margin_not_met"}]]]
close_project
