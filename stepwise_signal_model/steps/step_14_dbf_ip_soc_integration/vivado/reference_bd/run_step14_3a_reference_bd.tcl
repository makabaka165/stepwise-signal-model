set script_dir [file dirname [file normalize [info script]]]
set reference_bd_dir [file normalize $script_dir]
set vivado_dir [file dirname $reference_bd_dir]
set step14_dir [file dirname $vivado_dir]
set ip_repo_dir [file normalize [file join $step14_dir "ip_repo"]]
set result_dir [file normalize [file join $step14_dir "results_step14_dbf_ip_soc_integration" "reference_bd"]]
set work_dir [file normalize [file join $step14_dir "vivado" "work" "step14_3a_reference_bd"]]
set project_name "step14_3a_reference_bd"
set bd_name "dbf_reference_bd"
set wrapper_top "dbf_reference_bd_wrapper"
set ip_vlnv "user.org:radar:dbf_axis:1.0"
set blocker_if_any ""
file mkdir $result_dir

proc bool_str {flag} {
    if {$flag} { return "true" }
    return "false"
}

proc write_pairs {path pairs} {
    set fh [open $path "w"]
    puts $fh "metric,value"
    foreach pair $pairs {
        puts $fh "[lindex $pair 0],[lindex $pair 1]"
    }
    close $fh
}

proc safe_rebuild_dir {step14_dir target_dir required_tail} {
    set norm_target [file normalize $target_dir]
    set parent_l [string tolower [file normalize $step14_dir]]
    set target_l [string tolower $norm_target]
    if {[string first $parent_l $target_l] != 0 || [file tail $norm_target] ne $required_tail} {
        error "Refusing to delete unsafe reference BD directory: $norm_target"
    }
    if {[file exists $norm_target]} {
        file delete -force $norm_target
    }
    file mkdir $norm_target
}

proc read_metric {path key default_value} {
    if {![file exists $path]} { return $default_value }
    set fh [open $path "r"]
    set value $default_value
    gets $fh
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

proc parse_wns {text default_value} {
    set seen_header 0
    foreach line [split $text "\n"] {
        if {[regexp {WNS\(ns\)} $line]} {
            set seen_header 1
            continue
        }
        if {$seen_header && [regexp {^[ \t\|]*(-?[0-9]+(\.[0-9]+)?)[ \t]+-?[0-9]+(\.[0-9]+)?} $line -> value frac tail_frac]} {
            return $value
        }
    }
    return $default_value
}

proc parse_tns {text default_value} {
    set seen_header 0
    foreach line [split $text "\n"] {
        if {[regexp {WNS\(ns\).*TNS\(ns\).*TNS Failing Endpoints} $line]} {
            set seen_header 1
            continue
        }
        if {$seen_header && [regexp {^[ \t\|]*-?[0-9]+(\.[0-9]+)?[ \t]+(-?[0-9]+(\.[0-9]+)?)} $line -> frac value tail_frac]} {
            return $value
        }
    }
    return $default_value
}

proc parse_failing_endpoints {text default_value} {
    set seen_header 0
    foreach line [split $text "\n"] {
        if {[regexp {WNS\(ns\).*TNS\(ns\).*TNS Failing Endpoints} $line]} {
            set seen_header 1
            continue
        }
        if {$seen_header && [regexp {^[ \t\|]*-?[0-9]+(\.[0-9]+)?[ \t]+-?[0-9]+(\.[0-9]+)?[ \t]+([0-9]+)} $line -> f1 f2 value]} {
            return $value
        }
    }
    return $default_value
}

proc parse_timing_table_number {text number_index default_value} {
    set seen_header 0
    foreach line [split $text "\n"] {
        if {[regexp {WNS\(ns\).*TNS\(ns\).*TNS Failing Endpoints.*WHS\(ns\)} $line]} {
            set seen_header 1
            continue
        }
        if {$seen_header} {
            set nums [regexp -all -inline -- {-?[0-9]+\.?[0-9]*} $line]
            if {[llength $nums] >= 7} {
                return [lindex $nums $number_index]
            }
        }
    }
    return $default_value
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
    if {[info exists counts($key)]} {
        return $counts($key)
    }
    return 0
}

proc set_run_property_if_exists {run prop value} {
    if {[lsearch -exact [list_property $run] $prop] >= 0} {
        set_property $prop $value $run
        return $value
    }
    return "unavailable"
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
    set fh [open $path "w"]
    puts -nonewline $fh $data
    close $fh
}

proc write_unavailable_summaries {result_dir blocker} {
    write_pairs [file join $result_dir "step14_3a_bd_structure_summary.csv"] [list \
        [list reference_bd_structure_pass_flag false] \
        [list bd_validate_pass_flag false] \
        [list bd_wrapper_generated_flag false] \
        [list blocker_if_any $blocker] \
    ]
    write_pairs [file join $result_dir "step14_3a_bd_xsim_summary.csv"] [list \
        [list reference_bd_xsim_pass_flag false] \
        [list simulation_status not_run] \
        [list blocker_if_any $blocker] \
    ]
    write_pairs [file join $result_dir "step14_3a_bd_synth_summary.csv"] [list \
        [list synthesis_status not_run] \
        [list blocker_if_any $blocker] \
    ]
    write_pairs [file join $result_dir "step14_3a_bd_implementation_summary.csv"] [list \
        [list implementation_status not_run] \
        [list route_completed_flag false] \
        [list post_route_timing_200MHz_met_flag false] \
        [list blocker_if_any $blocker] \
    ]
    write_pairs [file join $result_dir "step14_3a_bd_drc_summary.csv"] [list \
        [list unexpected_drc_error_count 0] \
        [list blocker_if_any $blocker] \
    ]
}

if {[info exists ::env(STEP14_FPGA_PART)] && $::env(STEP14_FPGA_PART) ne ""} {
    set fpga_part $::env(STEP14_FPGA_PART)
    set fpga_part_source "environment"
} else {
    set fpga_part "xc7z020clg400-1"
    set fpga_part_source "reference_default"
}
if {[info exists ::env(STEP14_CLOCK_MHZ)] && $::env(STEP14_CLOCK_MHZ) ne ""} {
    set clock_mhz $::env(STEP14_CLOCK_MHZ)
    set clock_source "environment"
} else {
    set clock_mhz 200
    set clock_source "reference_default"
}
set clock_period_ns [expr {1000.0 / double($clock_mhz)}]
set clock_hz [expr {int(round(double($clock_mhz) * 1000000.0))}]

if {[llength [get_parts -quiet $fpga_part]] != 1} {
    set blocker_if_any "requested_fpga_part_not_found"
    write_unavailable_summaries $result_dir $blocker_if_any
    error $blocker_if_any
}

safe_rebuild_dir $step14_dir $work_dir "step14_3a_reference_bd"
create_project $project_name $work_dir -part $fpga_part -force
set_property ip_repo_paths $ip_repo_dir [current_project]
update_ip_catalog

set ipdef_count [llength [get_ipdefs -all $ip_vlnv]]
set ip_catalog_registration_pass_flag [expr {$ipdef_count == 1}]
if {!$ip_catalog_registration_pass_flag} {
    set blocker_if_any "custom_ip_catalog_registration_failed"
}

set bd_create_status "not_run"
set bd_validate_pass_flag false
set bd_wrapper_generated_flag false
set reference_bd_structure_pass_flag false
set forbidden_auto_cell_count 0
set actual_cells "NA"
set actual_input_fifo_config "NA"
set actual_output_fifo_config "NA"

if {$ip_catalog_registration_pass_flag} {
    set ::STEP14_REFBD_CLOCK_HZ $clock_hz
    if {[catch {source [file join $reference_bd_dir "create_dbf_reference_bd.tcl"]} bd_err]} {
        set bd_create_status "fail"
        set blocker_if_any "bd_create_or_validate_failed"
        puts $bd_err
    } else {
        set bd_create_status "pass"
        set bd_validate_pass_flag true
        set cells {}
        foreach cell [get_bd_cells -quiet] {
            lappend cells [get_property NAME $cell]
        }
        set actual_cells [join [lsort $cells] ";"]
        foreach cell $cells {
            if {$cell ni {axis_in_fifo_0 axis_out_fifo_0 dbf_axis_0}} {
                incr forbidden_auto_cell_count
            }
        }
        set reference_bd_structure_pass_flag [expr {$actual_cells eq "axis_in_fifo_0;axis_out_fifo_0;dbf_axis_0" && $forbidden_auto_cell_count == 0}]
        set input_props {}
        set output_props {}
        foreach prop {TDATA_NUM_BYTES FIFO_DEPTH HAS_TKEEP HAS_TLAST IS_ACLK_ASYNC} {
            if {[llength [list_property [get_bd_cells axis_in_fifo_0] CONFIG.$prop]] > 0} {
                lappend input_props "$prop=[get_property CONFIG.$prop [get_bd_cells axis_in_fifo_0]]"
            }
            if {[llength [list_property [get_bd_cells axis_out_fifo_0] CONFIG.$prop]] > 0} {
                lappend output_props "$prop=[get_property CONFIG.$prop [get_bd_cells axis_out_fifo_0]]"
            }
        }
        set actual_input_fifo_config [join $input_props ";"]
        set actual_output_fifo_config [join $output_props ";"]
        generate_target all [get_files ${bd_name}.bd]
        set wrapper_files [make_wrapper -files [get_files ${bd_name}.bd] -top]
        foreach wf $wrapper_files { add_files -norecurse $wf }
        update_compile_order -fileset sources_1
        set bd_wrapper_generated_flag [expr {[llength $wrapper_files] > 0}]
        set external_clock_associated_busif [expr {[info exists ::STEP14_REFBD_EXTERNAL_CLOCK_ASSOCIATED_BUSIF] ? $::STEP14_REFBD_EXTERNAL_CLOCK_ASSOCIATED_BUSIF : "unavailable"}]
        set external_clock_associated_reset [expr {[info exists ::STEP14_REFBD_EXTERNAL_CLOCK_ASSOCIATED_RESET] ? $::STEP14_REFBD_EXTERNAL_CLOCK_ASSOCIATED_RESET : "unavailable"}]
        set external_clock_association_pass_flag [expr {[info exists ::STEP14_REFBD_EXTERNAL_CLOCK_ASSOCIATION_PASS] && $::STEP14_REFBD_EXTERNAL_CLOCK_ASSOCIATION_PASS}]
    }
}
if {![info exists external_clock_associated_busif]} { set external_clock_associated_busif "unavailable" }
if {![info exists external_clock_associated_reset]} { set external_clock_associated_reset "unavailable" }
if {![info exists external_clock_association_pass_flag]} { set external_clock_association_pass_flag false }

write_pairs [file join $result_dir "step14_3a_bd_structure_summary.csv"] [list \
    [list vivado_version [version -short]] \
    [list fpga_part $fpga_part] \
    [list fpga_part_source $fpga_part_source] \
    [list clock_MHz $clock_mhz] \
    [list clock_source $clock_source] \
    [list project_name $project_name] \
    [list bd_name $bd_name] \
    [list wrapper_top $wrapper_top] \
    [list ip_vlnv $ip_vlnv] \
    [list ip_catalog_registration_pass_flag [bool_str $ip_catalog_registration_pass_flag]] \
    [list bd_create_status $bd_create_status] \
    [list bd_validate_pass_flag [bool_str $bd_validate_pass_flag]] \
    [list bd_wrapper_generated_flag [bool_str $bd_wrapper_generated_flag]] \
    [list actual_cells $actual_cells] \
    [list forbidden_auto_cell_count $forbidden_auto_cell_count] \
    [list external_clock_associated_busif $external_clock_associated_busif] \
    [list external_clock_associated_reset $external_clock_associated_reset] \
    [list external_clock_association_pass_flag [bool_str $external_clock_association_pass_flag]] \
    [list reference_bd_structure_pass_flag [bool_str $reference_bd_structure_pass_flag]] \
    [list bitstream_generated_flag false] \
    [list xsa_generated_flag false] \
    [list hwh_generated_flag false] \
    [list formal_result_claimed false] \
    [list blocker_if_any $blocker_if_any] \
]

write_pairs [file join $result_dir "step14_3a_bd_interface_summary.csv"] [list \
    [list external_clock_port aclk] \
    [list external_reset_port aresetn] \
    [list external_s_axis_interface S_AXIS_Y] \
    [list external_m_axis_interface M_AXIS_Z] \
    [list input_fifo_cell axis_in_fifo_0] \
    [list input_fifo_actual_config $actual_input_fifo_config] \
    [list dbf_ip_cell dbf_axis_0] \
    [list output_fifo_cell axis_out_fifo_0] \
    [list output_fifo_actual_config $actual_output_fifo_config] \
    [list status_busy_scope dbf_custom_ip_frame_activity_only_not_fifo_occupancy] \
    [list axi_dma_present_flag false] \
    [list zynq_ps_present_flag false] \
    [list axi_lite_present_flag false] \
    [list block_design_uses_custom_ip_catalog_flag [bool_str $ip_catalog_registration_pass_flag]] \
    [list module_reference_used_flag false] \
    [list formal_result_claimed false] \
]

set reference_bd_xsim_pass_flag false
set compile_status "not_run"
set elaboration_status "not_run"
set simulation_status "not_run"
set tb_summary_created false
set case_a_output_csv_created false
set case_b_output_csv_created false

if {$reference_bd_structure_pass_flag && $bd_wrapper_generated_flag} {
    set xdc_src [file normalize [file join $step14_dir "constraints" "step14_3a_reference_bd.xdc"]]
    if {$clock_mhz == 200} {
        add_files -fileset constrs_1 -norecurse $xdc_src
    } else {
        set tmp_xdc [file join $work_dir "step14_3a_reference_bd_clock_override.xdc"]
        set fh [open $tmp_xdc "w"]
        puts $fh [format "create_clock -name aclk -period %.3f \[get_ports aclk\]" $clock_period_ns]
        puts $fh "set_false_path -from \[get_ports aresetn\]"
        close $fh
        add_files -fileset constrs_1 -norecurse $tmp_xdc
    }
    set tb_file [file normalize [file join $step14_dir "tb" "tb_dbf_reference_bd.v"]]
    set y_mem [file normalize [file join $step14_dir "results_step14_dbf_ip_soc_integration" "axis_vectors" "step14_1_y_axis_tdata.mem"]]
    set z_mem [file normalize [file join $step14_dir "results_step14_dbf_ip_soc_integration" "axis_vectors" "step14_1_z_axis_expected.mem"]]
    add_files -fileset sim_1 -norecurse $tb_file
    add_files -fileset sim_1 -norecurse $y_mem
    add_files -fileset sim_1 -norecurse $z_mem
    set_property top tb_dbf_reference_bd [get_filesets sim_1]
    set_property xsim.simulate.runtime all [get_filesets sim_1]
    set_property target_simulator XSim [current_project]
    update_compile_order -fileset sim_1
    set xsim_run_dir [file normalize [file join $work_dir "${project_name}.sim" "sim_1" "behav" "xsim"]]
    file mkdir $xsim_run_dir
    file copy -force $y_mem [file join $xsim_run_dir "step14_1_y_axis_tdata.mem"]
    file copy -force $z_mem [file join $xsim_run_dir "step14_1_z_axis_expected.mem"]
    if {[catch {launch_simulation -simset sim_1 -mode behavioral} sim_err]} {
        set simulation_status "fail"
        if {$blocker_if_any eq ""} { set blocker_if_any "reference_bd_xsim_failed" }
        puts $sim_err
    } else {
        set compile_status "pass"
        set elaboration_status "pass"
        set simulation_status "pass"
    }
    catch {close_sim}
    foreach fname {step14_3a_reference_bd_output.csv step14_3a_reference_bd_stress_output.csv step14_3a_reference_bd_tb_summary.csv} {
        set src [file join $xsim_run_dir $fname]
        if {[file exists $src]} {
            file copy -force $src [file join $result_dir $fname]
        }
    }
    set tb_summary_created [file exists [file join $result_dir "step14_3a_reference_bd_tb_summary.csv"]]
    set case_a_output_csv_created [file exists [file join $result_dir "step14_3a_reference_bd_output.csv"]]
    set case_b_output_csv_created [file exists [file join $result_dir "step14_3a_reference_bd_stress_output.csv"]]
    set tb_pass [expr {[read_metric [file join $result_dir "step14_3a_reference_bd_tb_summary.csv"] reference_bd_tb_pass_flag false] eq "true"}]
    set reference_bd_xsim_pass_flag [expr {$tb_summary_created && $case_a_output_csv_created && $case_b_output_csv_created && $tb_pass && $simulation_status eq "pass"}]
    if {!$reference_bd_xsim_pass_flag && $blocker_if_any eq ""} {
        set blocker_if_any "reference_bd_tb_failed"
    }
}

write_pairs [file join $result_dir "step14_3a_bd_xsim_summary.csv"] [list \
    [list tool_vivado_found true] \
    [list compile_status $compile_status] \
    [list elaboration_status $elaboration_status] \
    [list simulation_status $simulation_status] \
    [list tb_summary_created [bool_str $tb_summary_created]] \
    [list case_a_output_csv_created [bool_str $case_a_output_csv_created]] \
    [list case_b_output_csv_created [bool_str $case_b_output_csv_created]] \
    [list reference_bd_xsim_pass_flag [bool_str $reference_bd_xsim_pass_flag]] \
    [list formal_result_claimed false] \
    [list dma_validation_flag false] \
    [list ps_validation_flag false] \
    [list board_validation_flag false] \
    [list blocker_if_any $blocker_if_any] \
]

set synthesis_status "not_run"
set implementation_status "not_run"
set route_completed_flag false
set post_route_timing_200MHz_met_flag false
set lut 0
set ff 0
set dsp 0
set bram18 0
set bram36 0
set wns "NA"
set tns "NA"
set failing_endpoints 0
set whs "NA"
set hold_failing_endpoints 0
set unexpected_drc_error_count 0
set drc_error_count 0
set drc_critical_warning_count 0
set drc_warning_count 0
set zps7_1_count 0
set ucio_1_count 0
set nstd_1_count 0
set dpip_1_count 0
set dpop_1_count 0
set allowed_drc_rules "ZPS7-1;UCIO-1;NSTD-1;DPOP-1"
set opt_design_directive "not_run"
set place_design_directive "not_run"
set phys_opt_enabled "not_run"
set phys_opt_directive "not_run"
set route_design_directive "not_run"
set post_route_phys_opt_enabled "not_run"
set post_route_phys_opt_directive "not_run"
set post_route_phys_opt_manual_status "not_run"

if {$reference_bd_structure_pass_flag && $bd_wrapper_generated_flag} {
    set_property top $wrapper_top [current_fileset]
    set_property {STEPS.SYNTH_DESIGN.ARGS.MORE OPTIONS} { -mode out_of_context} [get_runs synth_1]
    update_compile_order -fileset sources_1
    if {[catch {
        launch_runs synth_1 -jobs 4
        wait_on_run synth_1
    } synth_err]} {
        set synthesis_status "fail"
        if {$blocker_if_any eq ""} { set blocker_if_any "reference_bd_synthesis_failed" }
        puts $synth_err
    } else {
        set synth_status_prop [get_property STATUS [get_runs synth_1]]
        if {[string match "*Complete*" $synth_status_prop]} {
            set synthesis_status "pass"
            open_run synth_1
            report_utilization -file [file join $result_dir "step14_3a_bd_synth_utilization.rpt"]
            report_timing_summary -file [file join $result_dir "step14_3a_bd_synth_timing_summary.rpt"]
        } else {
            set synthesis_status "fail"
            if {$blocker_if_any eq ""} { set blocker_if_any "reference_bd_synthesis_not_complete" }
        }
    }
}

if {$synthesis_status eq "pass"} {
    set impl_run [get_runs impl_1]
    set opt_design_directive [set_run_property_if_exists $impl_run STEPS.OPT_DESIGN.ARGS.DIRECTIVE Explore]
    set place_design_directive [set_run_property_if_exists $impl_run STEPS.PLACE_DESIGN.ARGS.DIRECTIVE ExtraNetDelay_high]
    set phys_opt_enabled [set_run_property_if_exists $impl_run STEPS.PHYS_OPT_DESIGN.IS_ENABLED true]
    set phys_opt_directive [set_run_property_if_exists $impl_run STEPS.PHYS_OPT_DESIGN.ARGS.DIRECTIVE AggressiveExplore]
    set route_design_directive [set_run_property_if_exists $impl_run STEPS.ROUTE_DESIGN.ARGS.DIRECTIVE AggressiveExplore]
    set post_route_phys_opt_enabled [set_run_property_if_exists $impl_run STEPS.POST_ROUTE_PHYS_OPT_DESIGN.IS_ENABLED true]
    set post_route_phys_opt_directive [set_run_property_if_exists $impl_run STEPS.POST_ROUTE_PHYS_OPT_DESIGN.ARGS.DIRECTIVE AggressiveExplore]
    if {[catch {
        launch_runs impl_1 -to_step route_design -jobs 4
        wait_on_run impl_1
    } impl_err]} {
        set implementation_status "fail"
        if {$blocker_if_any eq ""} { set blocker_if_any "reference_bd_route_failed" }
        puts $impl_err
    } else {
        set impl_status_prop [get_property STATUS [get_runs impl_1]]
        set routed_dcp [file join $work_dir "${project_name}.runs" "impl_1" "${wrapper_top}_routed.dcp"]
        if {([string first "complete" [string tolower $impl_status_prop]] >= 0 &&
                [string first "route_design" [string tolower $impl_status_prop]] >= 0) ||
                [file exists $routed_dcp]} {
            set implementation_status "pass"
            set route_completed_flag true
            if {[catch {open_run impl_1} open_run_err]} {
                puts "open_run impl_1 failed, falling back to routed checkpoint: $open_run_err"
                open_checkpoint $routed_dcp
            }
            if {[catch {phys_opt_design -directive AggressiveExplore} post_route_phys_err]} {
                set post_route_phys_opt_manual_status "fail"
                puts $post_route_phys_err
            } else {
                set post_route_phys_opt_manual_status "pass"
            }
            set util_report [file join $result_dir "step14_3a_bd_post_route_utilization.rpt"]
            set timing_report [file join $result_dir "step14_3a_bd_post_route_timing_summary.rpt"]
            set drc_report [file join $result_dir "step14_3a_bd_post_route_drc.rpt"]
            set methodology_report [file join $result_dir "step14_3a_bd_post_route_methodology.rpt"]
            report_utilization -file $util_report
            report_timing_summary -file $timing_report
            report_drc -file $drc_report
            report_methodology -file $methodology_report
            set util_text [report_utilization -return_string]
            set timing_text [report_timing_summary -return_string]
            set drc_text [report_drc -return_string]
            set lut [parse_table_used $util_text [list {CLB LUTs} {Slice LUTs}] 0]
            set ff [parse_table_used $util_text [list {CLB Registers} {Slice Registers}] 0]
            set dsp [parse_table_used $util_text [list {DSPs} {DSP48E1} {DSP48E2}] 0]
            set bram18 [parse_table_used $util_text [list {RAMB18} {RAMB18/FIFO}] 0]
            set bram36 [parse_table_used $util_text [list {RAMB36} {RAMB36/FIFO}] 0]
            set wns [parse_wns $timing_text NA]
            set tns [parse_tns $timing_text NA]
            set failing_endpoints [parse_failing_endpoints $timing_text 0]
            set whs [parse_timing_table_number $timing_text 4 NA]
            set hold_failing_endpoints [parse_timing_table_number $timing_text 6 0]
            if {$wns ne "NA"} {
                set post_route_timing_200MHz_met_flag [expr {double($wns) >= 0.0}]
            }
            array set drc_counts [parse_drc_table_counts $drc_text]
            foreach key [array names drc_counts "*,severity"] {
                set rule [lindex [split $key ","] 0]
                set severity $drc_counts($key)
                set checks_key "$rule,checks"
                set checks 0
                if {[info exists drc_counts($checks_key)]} { set checks $drc_counts($checks_key) }
                if {[regexp -nocase {critical warning} $severity]} {
                    incr drc_critical_warning_count $checks
                } elseif {[regexp -nocase {warning} $severity]} {
                    incr drc_warning_count $checks
                } elseif {[regexp -nocase {error} $severity]} {
                    incr drc_error_count $checks
                }
                if {[lsearch -exact {ZPS7-1 UCIO-1 NSTD-1 DPOP-1} $rule] < 0 &&
                        [regexp -nocase {critical|error} $severity]} {
                    incr unexpected_drc_error_count $checks
                }
            }
            set zps7_1_count [drc_rule_count drc_counts ZPS7-1]
            set ucio_1_count [drc_rule_count drc_counts UCIO-1]
            set nstd_1_count [drc_rule_count drc_counts NSTD-1]
            set dpip_1_count [drc_rule_count drc_counts DPIP-1]
            set dpop_1_count [drc_rule_count drc_counts DPOP-1]
            scrub_step14_abs_path $util_report $step14_dir
            scrub_step14_abs_path $timing_report $step14_dir
            scrub_step14_abs_path $drc_report $step14_dir
            scrub_step14_abs_path $methodology_report $step14_dir
            if {!$post_route_timing_200MHz_met_flag && $blocker_if_any eq ""} {
                set blocker_if_any "post_route_timing_200MHz_not_met"
            }
            if {$unexpected_drc_error_count > 0 && $blocker_if_any eq ""} {
                set blocker_if_any "unexpected_reference_bd_drc_error"
            }
        } else {
            set implementation_status "fail"
            if {$blocker_if_any eq ""} { set blocker_if_any "reference_bd_route_not_complete" }
        }
    }
}

write_pairs [file join $result_dir "step14_3a_bd_synth_summary.csv"] [list \
    [list synthesis_status $synthesis_status] \
    [list top $wrapper_top] \
    [list bitstream_generated_flag false] \
    [list xsa_generated_flag false] \
    [list hwh_generated_flag false] \
    [list formal_result_claimed false] \
    [list blocker_if_any $blocker_if_any] \
]

write_pairs [file join $result_dir "step14_3a_bd_implementation_summary.csv"] [list \
    [list implementation_status $implementation_status] \
    [list route_completed_flag [bool_str $route_completed_flag]] \
    [list clock_MHz $clock_mhz] \
    [list clock_period_ns [format %.3f $clock_period_ns]] \
    [list LUT $lut] \
    [list FF $ff] \
    [list DSP $dsp] \
    [list BRAM18 $bram18] \
    [list BRAM36 $bram36] \
    [list WNS_ns $wns] \
    [list TNS_ns $tns] \
    [list failing_endpoints $failing_endpoints] \
    [list WHS_ns $whs] \
    [list hold_failing_endpoints $hold_failing_endpoints] \
    [list post_route_timing_200MHz_met_flag [bool_str $post_route_timing_200MHz_met_flag]] \
    [list opt_design_directive $opt_design_directive] \
    [list place_design_directive $place_design_directive] \
    [list phys_opt_enabled $phys_opt_enabled] \
    [list phys_opt_directive $phys_opt_directive] \
    [list route_design_directive $route_design_directive] \
    [list post_route_phys_opt_enabled $post_route_phys_opt_enabled] \
    [list post_route_phys_opt_directive $post_route_phys_opt_directive] \
    [list post_route_phys_opt_manual_status $post_route_phys_opt_manual_status] \
    [list bitstream_generated_flag false] \
    [list xsa_generated_flag false] \
    [list hwh_generated_flag false] \
    [list implementation_closure_claimed false] \
    [list board_validation_flag false] \
    [list formal_result_claimed false] \
    [list blocker_if_any $blocker_if_any] \
]

write_pairs [file join $result_dir "step14_3a_bd_drc_summary.csv"] [list \
    [list DRC_error_count $drc_error_count] \
    [list DRC_critical_warning_count $drc_critical_warning_count] \
    [list DRC_warning_count $drc_warning_count] \
    [list ZPS7_1_count $zps7_1_count] \
    [list UCIO_1_count $ucio_1_count] \
    [list NSTD_1_count $nstd_1_count] \
    [list DPIP_1_count $dpip_1_count] \
    [list DPOP_1_count $dpop_1_count] \
    [list allowed_reference_warning_rules $allowed_drc_rules] \
    [list unexpected_drc_error_count $unexpected_drc_error_count] \
    [list reference_expected_drc_only_flag [bool_str [expr {$unexpected_drc_error_count == 0}]]] \
    [list drc_reference_design_pass_flag [bool_str [expr {$unexpected_drc_error_count == 0}]]] \
    [list bitstream_generated_flag false] \
    [list formal_result_claimed false] \
    [list board_validation_flag false] \
    [list blocker_if_any $blocker_if_any] \
]

close_project

if {!$reference_bd_structure_pass_flag || !$bd_validate_pass_flag || !$bd_wrapper_generated_flag ||
        !$reference_bd_xsim_pass_flag || $synthesis_status ne "pass" || !$route_completed_flag ||
        !$post_route_timing_200MHz_met_flag || $unexpected_drc_error_count > 0} {
    error "Step14.3a reference BD validation failed: $blocker_if_any"
}
