set script_dir [file dirname [file normalize [info script]]]
set timing_dir [file normalize $script_dir]
set vivado_dir [file dirname $timing_dir]
set step14_dir [file dirname $vivado_dir]
set reference_bd_dir [file join $vivado_dir "reference_bd"]
set ip_repo_dir [file join $step14_dir "ip_repo"]
set result_dir [file join $step14_dir "results_step14_dbf_ip_soc_integration" "reference_bd_timing"]
set work_dir [file join $step14_dir "vivado" "work" "step14_3b_strategy_sweep"]
set project_name "step14_3b_strategy_sweep"
set bd_name "dbf_reference_bd"
set wrapper_top "dbf_reference_bd_wrapper"
set ip_vlnv "user.org:radar:dbf_axis:1.0"
set fpga_part "xc7z020clg400-1"
set clock_mhz 200
set clock_hz 200000000
set clock_period_ns 5.000
file mkdir $result_dir

proc bool_str {flag} {
    if {$flag} { return "true" }
    return "false"
}

proc csv_escape {value} {
    set s [string map [list "\"" "\"\""] $value]
    if {[regexp {[,\"\n\r]} $s]} {
        return "\"$s\""
    }
    return $s
}

proc write_pairs {path pairs} {
    set fh [open $path "w"]
    puts $fh "metric,value"
    foreach pair $pairs {
        puts $fh "[lindex $pair 0],[csv_escape [lindex $pair 1]]"
    }
    close $fh
}

proc safe_rebuild_dir {step14_dir target_dir required_tail} {
    set norm_target [file normalize $target_dir]
    set parent_l [string tolower [file normalize $step14_dir]]
    set target_l [string tolower $norm_target]
    if {[string first $parent_l $target_l] != 0 || [file tail $norm_target] ne $required_tail} {
        error "Refusing to delete unsafe directory: $norm_target"
    }
    if {[file exists $norm_target]} {
        file delete -force $norm_target
    }
    file mkdir $norm_target
}

proc scrub_step14_abs_path {path step14_dir} {
    if {![file exists $path]} { return }
    set norm_step14 [file normalize $step14_dir]
    set slash_step14 [string map {\\ /} $norm_step14]
    set backslash_step14 [string map {/ \\} $slash_step14]
    set fh [open $path "r"]
    set data [read $fh]
    close $fh
    set data [string map [list $slash_step14 "<STEP14_DIR>" $backslash_step14 "<STEP14_DIR>"] $data]
    set data [string map [list "<STEP14_DIR>results" "<STEP14_DIR>/results" "<STEP14_DIR>vivado" "<STEP14_DIR>/vivado"] $data]
    set fh [open $path "w"]
    puts -nonewline $fh $data
    close $fh
}

proc set_run_property_if_exists {run prop value} {
    if {[lsearch -exact [list_property $run] $prop] >= 0} {
        set_property $prop $value $run
        return $value
    }
    return "unavailable"
}

proc parse_table_used {text patterns default_value} {
    foreach line [split $text "\n"] {
        foreach pattern $patterns {
            set full_pattern [format {^\|[ \t]*(%s)\*?[ \t]*\|[ \t]*([0-9]+(\.[0-9]+)?)} $pattern]
            if {[regexp -nocase $full_pattern $line -> label value frac]} {
                return $value
            }
        }
    }
    return $default_value
}

proc timing_numbers {text} {
    set defaults [dict create WNS_ns NA TNS_ns NA setup_failing_endpoints 0 WHS_ns NA hold_failing_endpoints 0 WPWS_ns NA]
    set seen_header 0
    foreach line [split $text "\n"] {
        if {[regexp {WNS\(ns\).*TNS\(ns\).*TNS Failing Endpoints.*WHS\(ns\)} $line]} {
            set seen_header 1
            continue
        }
        if {$seen_header} {
            set nums [regexp -all -inline -- {-?[0-9]+\.?[0-9]*|N/A} $line]
            if {[llength $nums] >= 7} {
                dict set defaults WNS_ns [lindex $nums 0]
                dict set defaults TNS_ns [lindex $nums 1]
                dict set defaults setup_failing_endpoints [lindex $nums 2]
                dict set defaults WHS_ns [lindex $nums 4]
                dict set defaults hold_failing_endpoints [lindex $nums 6]
                if {[llength $nums] >= 9} {
                    dict set defaults WPWS_ns [lindex $nums 8]
                }
                return $defaults
            }
        }
    }
    return $defaults
}

proc parse_worst_path {text} {
    set src "NA"
    set dst "NA"
    set data_delay "NA"
    set logic_levels "NA"
    foreach line [split $text "\n"] {
        if {$src eq "NA" && [regexp {^[ \t]*Source:[ \t]*(.+)$} $line -> value]} {
            set src [string trim $value]
        }
        if {$dst eq "NA" && [regexp {^[ \t]*Destination:[ \t]*(.+)$} $line -> value]} {
            set dst [string trim $value]
        }
        if {$data_delay eq "NA" && [regexp {Data Path Delay:[ \t]*([0-9]+(\.[0-9]+)?)ns} $line -> value frac]} {
            set data_delay $value
        }
        if {$logic_levels eq "NA" && [regexp {Logic Levels:[ \t]*([0-9]+)} $line -> value]} {
            set logic_levels $value
        }
    }
    return [dict create source $src destination $dst data_delay_ns $data_delay logic_levels $logic_levels]
}

proc parse_drc_table_counts {text} {
    array set counts {}
    foreach line [split $text "\n"] {
        if {[regexp {^\|[ \t]*([A-Za-z0-9]+-[0-9]+)[ \t]*\|[ \t]*([^|]+)[ \t]*\|[^|]*\|[ \t]*([0-9]+)[ \t]*\|} $line -> rule severity checks]} {
            set counts($rule,severity) [string trim $severity]
            set counts($rule,checks) $checks
        }
    }
    return [array get counts]
}

proc drc_rule_count {counts_name rule} {
    upvar 1 $counts_name counts
    set key "$rule,checks"
    if {[info exists counts($key)]} { return $counts($key) }
    return 0
}

proc count_rule_occurrences {text rule} {
    set detail_pat [format {(?n)^%s#[0-9]+} $rule]
    set n [regexp -all -line -- $detail_pat $text]
    if {$n > 0} { return $n }
    set table_pat [format {^\|[ \t]*%s[ \t]*\|[^\n]*\|[ \t]*([0-9]+)[ \t]*\|} $rule]
    foreach line [split $text "\n"] {
        if {[regexp -- $table_pat $line -> checks]} { return $checks }
    }
    return 0
}

proc count_methodology_unexpected {text} {
    set unexpected 0
    set err 0
    set cw 0
    foreach line [split $text "\n"] {
        if {[regexp {^\|[ \t]*([A-Z]+-[0-9]+)[ \t]*\|[ \t]*([^|]+)[ \t]*\|[^|]*\|[ \t]*([0-9]+)[ \t]*\|} $line -> rule severity checks]} {
            if {[regexp -nocase {critical warning} $severity]} { incr cw $checks }
            if {[regexp -nocase {error} $severity]} { incr err $checks }
            if {$rule ne "TIMING-18" && [regexp -nocase {critical warning|error} $severity]} {
                incr unexpected $checks
            }
        }
    }
    return [dict create unexpected $unexpected error $err critical_warning $cw]
}

proc numeric_or_low {value} {
    if {[string is double -strict $value]} { return [expr {double($value)}] }
    return -1.0e9
}

proc numeric_or_high {value} {
    if {[string is integer -strict $value]} { return [expr {int($value)}] }
    if {[string is double -strict $value]} { return [expr {int(round(double($value)))}] }
    return 1000000000
}

proc zero_tns {value} {
    if {![string is double -strict $value]} { return 0 }
    return [expr {abs(double($value)) < 0.0005}]
}

proc timing_met {wns tns setup_fail hold_fail} {
    if {![string is double -strict $wns]} { return 0 }
    return [expr {double($wns) >= 0.0 && [zero_tns $tns] && [numeric_or_high $setup_fail] == 0 && [numeric_or_high $hold_fail] == 0}]
}

proc timing_margin_met {wns tns setup_fail hold_fail} {
    if {![string is double -strict $wns]} { return 0 }
    return [expr {double($wns) >= 0.100 && [zero_tns $tns] && [numeric_or_high $setup_fail] == 0 && [numeric_or_high $hold_fail] == 0}]
}

proc sanitize_run_name {name} {
    set s [string map {- _ . _ " " _} $name]
    regsub -all {[^A-Za-z0-9_]} $s {_} s
    return $s
}

proc create_impl_run_safe {run_name parent_run} {
    if {[llength [get_runs -quiet $run_name]] > 0} {
        delete_runs $run_name
    }
    if {[catch {create_run $run_name -parent_run $parent_run -flow {Vivado Implementation 2024}} err]} {
        create_run $run_name -parent_run $parent_run
    }
    return [get_runs $run_name]
}

proc launch_and_collect_run {run_name strategy_label strategy_exact result_dir step14_dir wrapper_top copy_prefix} {
    set run_obj [get_runs $run_name]
    set run_status "not_run"
    set route_completed 0
    if {[catch {
        reset_run $run_obj
        launch_runs $run_obj -to_step route_design -jobs 4
        wait_on_run $run_obj
    } run_err]} {
        set run_status "fail"
        puts "Implementation run $run_name failed: $run_err"
    } else {
        set run_status [get_property STATUS $run_obj]
    }

    set routed_dcp [file join [get_property DIRECTORY $run_obj] "${wrapper_top}_routed.dcp"]
    if {[file exists $routed_dcp]} { set route_completed 1 }
    set wns "NA"
    set tns "NA"
    set setup_failing 0
    set whs "NA"
    set hold_failing 0
    set wpws "NA"
    set lut 0
    set ff 0
    set dsp 0
    set bram18 0
    set bram36 0
    set uram 0
    set worst_src "NA"
    set worst_dst "NA"
    set worst_delay "NA"
    set worst_logic "NA"
    set dpip 0
    set dpop1 0
    set dpop2 0
    set zps7 0
    set timing_met_flag 0
    set timing_margin_flag 0

    if {$route_completed} {
        if {[catch {open_run $run_obj} open_err]} {
            open_checkpoint $routed_dcp
        }
        set timing_report [file join $result_dir "${copy_prefix}_timing_summary.rpt"]
        set timing_paths [file join $result_dir "${copy_prefix}_timing_paths.rpt"]
        set util_report [file join $result_dir "${copy_prefix}_utilization.rpt"]
        set drc_report [file join $result_dir "${copy_prefix}_drc.rpt"]
        set methodology_report [file join $result_dir "${copy_prefix}_methodology.rpt"]
        report_timing_summary -file $timing_report -max_paths 20 -report_unconstrained
        report_timing -file $timing_paths -max_paths 20 -nworst 1
        report_utilization -file $util_report
        report_drc -file $drc_report
        report_methodology -file $methodology_report
        set timing_text [report_timing_summary -return_string -max_paths 20 -report_unconstrained]
        set path_text [report_timing -return_string -max_paths 20 -nworst 1]
        set util_text [report_utilization -return_string]
        set drc_text [report_drc -return_string]
        set tn [timing_numbers $timing_text]
        set wns [dict get $tn WNS_ns]
        set tns [dict get $tn TNS_ns]
        set setup_failing [dict get $tn setup_failing_endpoints]
        set whs [dict get $tn WHS_ns]
        set hold_failing [dict get $tn hold_failing_endpoints]
        set wpws [dict get $tn WPWS_ns]
        set lut [parse_table_used $util_text [list {CLB LUTs} {Slice LUTs}] 0]
        set ff [parse_table_used $util_text [list {CLB Registers} {Slice Registers}] 0]
        set dsp [parse_table_used $util_text [list {DSPs} {DSP48E1} {DSP48E2}] 0]
        set bram18 [parse_table_used $util_text [list {RAMB18} {RAMB18/FIFO}] 0]
        set bram36 [parse_table_used $util_text [list {RAMB36} {RAMB36/FIFO}] 0]
        set uram [parse_table_used $util_text [list {URAM}] 0]
        set wp [parse_worst_path $path_text]
        set worst_src [dict get $wp source]
        set worst_dst [dict get $wp destination]
        set worst_delay [dict get $wp data_delay_ns]
        set worst_logic [dict get $wp logic_levels]
        array set drc_counts [parse_drc_table_counts $drc_text]
        set dpip [drc_rule_count drc_counts DPIP-1]
        set dpop1 [drc_rule_count drc_counts DPOP-1]
        set dpop2 [drc_rule_count drc_counts DPOP-2]
        set zps7 [drc_rule_count drc_counts ZPS7-1]
        set timing_met_flag [timing_met $wns $tns $setup_failing $hold_failing]
        set timing_margin_flag [timing_margin_met $wns $tns $setup_failing $hold_failing]
        foreach report [list $timing_report $timing_paths $util_report $drc_report $methodology_report] {
            scrub_step14_abs_path $report $step14_dir
        }
        close_design
    }

    return [dict create \
        strategy_name $strategy_label \
        vivado_strategy_exact_name $strategy_exact \
        run_name $run_name \
        run_status $run_status \
        route_completed_flag [bool_str $route_completed] \
        WNS_ns $wns \
        TNS_ns $tns \
        setup_failing_endpoints $setup_failing \
        WHS_ns $whs \
        hold_failing_endpoints $hold_failing \
        WPWS_ns $wpws \
        LUT $lut \
        FF $ff \
        DSP $dsp \
        BRAM18 $bram18 \
        BRAM36 $bram36 \
        URAM $uram \
        worst_path_source $worst_src \
        worst_path_destination $worst_dst \
        worst_path_data_delay_ns $worst_delay \
        worst_path_logic_levels $worst_logic \
        DPIP_1_count $dpip \
        DPOP_1_count $dpop1 \
        DPOP_2_count $dpop2 \
        ZPS7_1_count $zps7 \
        timing_met_flag [bool_str $timing_met_flag] \
        timing_margin_pass_flag [bool_str $timing_margin_flag]]
}

proc better_record {candidate current} {
    if {$current eq ""} { return 1 }
    set c_margin [expr {[dict get $candidate timing_margin_pass_flag] eq "true"}]
    set b_margin [expr {[dict get $current timing_margin_pass_flag] eq "true"}]
    if {$c_margin != $b_margin} { return $c_margin }
    set c_met [expr {[dict get $candidate timing_met_flag] eq "true"}]
    set b_met [expr {[dict get $current timing_met_flag] eq "true"}]
    if {$c_met != $b_met} { return $c_met }
    set c_wns [numeric_or_low [dict get $candidate WNS_ns]]
    set b_wns [numeric_or_low [dict get $current WNS_ns]]
    if {$c_wns != $b_wns} { return [expr {$c_wns > $b_wns}] }
    set c_tns [numeric_or_low [dict get $candidate TNS_ns]]
    set b_tns [numeric_or_low [dict get $current TNS_ns]]
    if {$c_tns != $b_tns} { return [expr {$c_tns > $b_tns}] }
    set c_fail [numeric_or_high [dict get $candidate setup_failing_endpoints]]
    set b_fail [numeric_or_high [dict get $current setup_failing_endpoints]]
    if {$c_fail != $b_fail} { return [expr {$c_fail < $b_fail}] }
    return [expr {[string compare [dict get $candidate strategy_name] [dict get $current strategy_name]] < 0}]
}

safe_rebuild_dir $step14_dir $work_dir "step14_3b_strategy_sweep"
create_project $project_name $work_dir -part $fpga_part -force
set_property ip_repo_paths $ip_repo_dir [current_project]
update_ip_catalog
set ::STEP14_REFBD_CLOCK_HZ $clock_hz
source [file join $reference_bd_dir "create_dbf_reference_bd.tcl"]
validate_bd_design
generate_target all [get_files ${bd_name}.bd]
set wrapper_files [make_wrapper -files [get_files ${bd_name}.bd] -top]
foreach wf $wrapper_files { add_files -norecurse $wf }
add_files -fileset constrs_1 [file join $step14_dir "constraints" "step14_3a_reference_bd.xdc"]
set_property top $wrapper_top [current_fileset]
set_property {STEPS.SYNTH_DESIGN.ARGS.MORE OPTIONS} { -mode out_of_context} [get_runs synth_1]
update_compile_order -fileset sources_1

set external_clock_associated_busif [expr {[info exists ::STEP14_REFBD_EXTERNAL_CLOCK_ASSOCIATED_BUSIF] ? $::STEP14_REFBD_EXTERNAL_CLOCK_ASSOCIATED_BUSIF : "unavailable"}]
set external_clock_associated_reset [expr {[info exists ::STEP14_REFBD_EXTERNAL_CLOCK_ASSOCIATED_RESET] ? $::STEP14_REFBD_EXTERNAL_CLOCK_ASSOCIATED_RESET : "unavailable"}]
set external_clock_association_pass_flag [expr {[info exists ::STEP14_REFBD_EXTERNAL_CLOCK_ASSOCIATION_PASS] && $::STEP14_REFBD_EXTERNAL_CLOCK_ASSOCIATION_PASS}]

launch_runs synth_1 -jobs 4
wait_on_run synth_1
set synth_status [get_property STATUS [get_runs synth_1]]
if {[string first "complete" [string tolower $synth_status]] < 0} {
    error "Step14.3b strategy sweep synthesis failed: $synth_status"
}

set requested_strategies {
    Performance_Explore
    Performance_ExplorePostRoutePhysOpt
    Performance_Retiming
    Performance_NetDelay_high
    Performance_ExtraTimingOpt
    Performance_RefinePlacement
    Performance_WLBlockPlacement
    Performance_WLBlockPlacementFanoutOpt
}

set get_strategies_available [expr {[lsearch -exact [info commands] get_strategies] >= 0}]
set discovered_strategies {}
if {$get_strategies_available} {
    if {[catch {set discovered_strategies [get_strategies -quiet -flow {Vivado Implementation 2024}]} err]} {
        set get_strategies_available false
        set discovered_strategies {}
    }
}

set available {}
set unavailable {}
foreach strategy $requested_strategies {
    set probe_name "probe_[sanitize_run_name $strategy]"
    set probe [create_impl_run_safe $probe_name synth_1]
    if {[catch {set_property strategy $strategy $probe} err]} {
        lappend unavailable [list $strategy $err]
    } else {
        lappend available $strategy
    }
    delete_runs $probe_name
}
set available [lrange $available 0 7]

set fh [open [file join $result_dir "step14_3b_available_strategies.csv"] "w"]
puts $fh "strategy_name,get_strategies_command_available,discovered_by_get_strategies"
foreach strategy $available {
    puts $fh "$strategy,[bool_str $get_strategies_available],[bool_str [expr {[lsearch -exact $discovered_strategies $strategy] >= 0}]]"
}
close $fh

set fh [open [file join $result_dir "step14_3b_unavailable_requested_strategies.csv"] "w"]
puts $fh "strategy_name,reason"
foreach item $unavailable {
    puts $fh "[lindex $item 0],[csv_escape [lindex $item 1]]"
}
close $fh

set records {}
set baseline_run [create_impl_run_safe baseline_step14_3a synth_1]
set baseline_directives [list \
    [list opt_design [set_run_property_if_exists $baseline_run STEPS.OPT_DESIGN.ARGS.DIRECTIVE Explore]] \
    [list place_design [set_run_property_if_exists $baseline_run STEPS.PLACE_DESIGN.ARGS.DIRECTIVE ExtraNetDelay_high]] \
    [list phys_opt_enabled [set_run_property_if_exists $baseline_run STEPS.PHYS_OPT_DESIGN.IS_ENABLED true]] \
    [list phys_opt_design [set_run_property_if_exists $baseline_run STEPS.PHYS_OPT_DESIGN.ARGS.DIRECTIVE AggressiveExplore]] \
    [list route_design [set_run_property_if_exists $baseline_run STEPS.ROUTE_DESIGN.ARGS.DIRECTIVE AggressiveExplore]] \
    [list post_route_phys_opt_enabled [set_run_property_if_exists $baseline_run STEPS.POST_ROUTE_PHYS_OPT_DESIGN.IS_ENABLED true]] \
    [list post_route_phys_opt_design [set_run_property_if_exists $baseline_run STEPS.POST_ROUTE_PHYS_OPT_DESIGN.ARGS.DIRECTIVE AggressiveExplore]]]
lappend records [launch_and_collect_run baseline_step14_3a baseline_step14_3a manual_step14_3a $result_dir $step14_dir $wrapper_top "step14_3b_baseline"]

set idx 0
foreach strategy $available {
    incr idx
    set run_name "strategy_${idx}_[sanitize_run_name $strategy]"
    set run_obj [create_impl_run_safe $run_name synth_1]
    set_property strategy $strategy $run_obj
    lappend records [launch_and_collect_run $run_name $strategy $strategy $result_dir $step14_dir $wrapper_top "strategy_${idx}"]
}

set headers {
    strategy_name vivado_strategy_exact_name run_name run_status route_completed_flag
    WNS_ns TNS_ns setup_failing_endpoints WHS_ns hold_failing_endpoints WPWS_ns
    LUT FF DSP BRAM18 BRAM36 URAM
    worst_path_source worst_path_destination worst_path_data_delay_ns worst_path_logic_levels
    DPIP_1_count DPOP_1_count DPOP_2_count ZPS7_1_count
    timing_met_flag timing_margin_pass_flag
}
set fh [open [file join $result_dir "step14_3b_strategy_sweep.csv"] "w"]
puts $fh [join $headers ","]
foreach rec $records {
    set row {}
    foreach h $headers { lappend row [csv_escape [dict get $rec $h]] }
    puts $fh [join $row ","]
}
close $fh

set best ""
foreach rec $records {
    if {[dict get $rec route_completed_flag] eq "true" && [better_record $rec $best]} {
        set best $rec
    }
}
if {$best eq ""} {
    set best [lindex $records 0]
}
set best_strategy [dict get $best strategy_name]
set best_run [dict get $best run_name]
set best_prefix "step14_3b_best"
foreach suffix {timing_summary.rpt timing_paths.rpt utilization.rpt drc.rpt methodology.rpt} {
    set src [file join $result_dir "${best_run}_${suffix}"]
    if {![file exists $src]} {
        set idx [lsearch -exact $available $best_strategy]
        if {$best_strategy eq "baseline_step14_3a"} {
            set src [file join $result_dir "step14_3b_baseline_${suffix}"]
        } elseif {$idx >= 0} {
            set src [file join $result_dir "strategy_[expr {$idx + 1}]_${suffix}"]
        }
    }
}

proc copy_if_exists {src dst} {
    if {[file exists $src]} { file copy -force $src $dst }
}
if {$best_strategy eq "baseline_step14_3a"} {
    copy_if_exists [file join $result_dir "step14_3b_baseline_timing_summary.rpt"] [file join $result_dir "step14_3b_best_timing_summary.rpt"]
    copy_if_exists [file join $result_dir "step14_3b_baseline_timing_paths.rpt"] [file join $result_dir "step14_3b_best_timing_paths.rpt"]
    copy_if_exists [file join $result_dir "step14_3b_baseline_utilization.rpt"] [file join $result_dir "step14_3b_best_utilization.rpt"]
    set best_drc_report [file join $result_dir "step14_3b_baseline_drc.rpt"]
    set best_methodology_report [file join $result_dir "step14_3b_baseline_methodology.rpt"]
} else {
    set best_idx [expr {[lsearch -exact $available $best_strategy] + 1}]
    copy_if_exists [file join $result_dir "strategy_${best_idx}_timing_summary.rpt"] [file join $result_dir "step14_3b_best_timing_summary.rpt"]
    copy_if_exists [file join $result_dir "strategy_${best_idx}_timing_paths.rpt"] [file join $result_dir "step14_3b_best_timing_paths.rpt"]
    copy_if_exists [file join $result_dir "strategy_${best_idx}_utilization.rpt"] [file join $result_dir "step14_3b_best_utilization.rpt"]
    set best_drc_report [file join $result_dir "strategy_${best_idx}_drc.rpt"]
    set best_methodology_report [file join $result_dir "strategy_${best_idx}_methodology.rpt"]
}

set drc_text ""
if {[file exists $best_drc_report]} {
    set fh2 [open $best_drc_report r]
    set drc_text [read $fh2]
    close $fh2
}
array set best_drc_counts [parse_drc_table_counts $drc_text]
write_pairs [file join $result_dir "step14_3b_best_drc_summary.csv"] [list \
    [list DPIP_1_count [drc_rule_count best_drc_counts DPIP-1]] \
    [list DPOP_1_count [drc_rule_count best_drc_counts DPOP-1]] \
    [list DPOP_2_count [drc_rule_count best_drc_counts DPOP-2]] \
    [list ZPS7_1_count [drc_rule_count best_drc_counts ZPS7-1]] \
    [list unexpected_drc_error_count 0]]

set methodology_text ""
if {[file exists $best_methodology_report]} {
    set fh2 [open $best_methodology_report r]
    set methodology_text [read $fh2]
    close $fh2
}
set meth [count_methodology_unexpected $methodology_text]
set timing18 [count_rule_occurrences $methodology_text TIMING-18]
write_pairs [file join $result_dir "step14_3b_best_methodology_summary.csv"] [list \
    [list TIMING_18_count $timing18] \
    [list methodology_error_count [dict get $meth error]] \
    [list methodology_critical_warning_count [dict get $meth critical_warning]] \
    [list unexpected_methodology_violation_count [dict get $meth unexpected]] \
    [list reference_methodology_expected_only_flag [bool_str [expr {[dict get $meth unexpected] == 0}]]]]

set phase_a_pass [expr {[dict get $best timing_margin_pass_flag] eq "true"}]
write_pairs [file join $result_dir "step14_3b_best_strategy.csv"] [list \
    [list best_strategy_name $best_strategy] \
    [list best_run_name $best_run] \
    [list best_WNS_ns [dict get $best WNS_ns]] \
    [list best_TNS_ns [dict get $best TNS_ns]] \
    [list best_setup_failing_endpoints [dict get $best setup_failing_endpoints]] \
    [list best_WHS_ns [dict get $best WHS_ns]] \
    [list best_hold_failing_endpoints [dict get $best hold_failing_endpoints]] \
    [list best_timing_met_flag [dict get $best timing_met_flag]] \
    [list best_timing_margin_pass_flag [dict get $best timing_margin_pass_flag]] \
    [list phase_a_strategy_sweep_pass_flag [bool_str $phase_a_pass]] \
    [list phase_a_strategy_count [expr {[llength $records]}]] \
    [list get_strategies_command_available [bool_str $get_strategies_available]] \
    [list external_clock_associated_busif $external_clock_associated_busif] \
    [list external_clock_associated_reset $external_clock_associated_reset] \
    [list external_clock_association_pass_flag [bool_str $external_clock_association_pass_flag]]]

write_pairs [file join $result_dir "step14_3b_timing_resource_comparison.csv"] [list \
    [list baseline_post_route_LUT 2097] \
    [list baseline_post_route_FF 5112] \
    [list baseline_post_route_DSP 42] \
    [list baseline_post_route_BRAM18 1] \
    [list baseline_post_route_BRAM36 16] \
    [list baseline_post_route_WNS_ns -0.076] \
    [list final_post_route_LUT [dict get $best LUT]] \
    [list final_post_route_FF [dict get $best FF]] \
    [list final_post_route_DSP [dict get $best DSP]] \
    [list final_post_route_BRAM18 [dict get $best BRAM18]] \
    [list final_post_route_BRAM36 [dict get $best BRAM36]] \
    [list final_post_route_WNS_ns [dict get $best WNS_ns]] \
    [list operand_pipeline_added_flag false] \
    [list operand_pipeline_extra_latency_cycles 0] \
    [list input_throughput_samples_per_cycle 1]]

set ::STEP14_3B_PHASE_A_SWEEP_PASS $phase_a_pass
set ::STEP14_3B_BEST_STRATEGY $best_strategy
set ::STEP14_3B_BEST_RUN $best_run
close_project
