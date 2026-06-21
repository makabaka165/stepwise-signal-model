set script_dir [file dirname [file normalize [info script]]]
set step14_dir [file normalize [file join $script_dir ".."]]
set ip_repo_dir [file normalize [file join $step14_dir "ip_repo"]]
set work_dir [file normalize [file join $step14_dir "vivado" "work" "step14_2a_validate"]]
set pkg_result_dir [file normalize [file join $step14_dir "results_step14_dbf_ip_soc_integration" "ip_package"]]
set xsim_result_dir [file normalize [file join $step14_dir "results_step14_dbf_ip_soc_integration" "ip_xsim"]]
set synth_result_dir [file normalize [file join $step14_dir "results_step14_dbf_ip_soc_integration" "ip_synth"]]
file mkdir $pkg_result_dir
file mkdir $xsim_result_dir
file mkdir $synth_result_dir

set ip_vlnv "user.org:radar:dbf_axis:1.0"
set blocker_if_any ""
set vivado_version [version -short]

proc write_pairs {path pairs} {
    set fh [open $path "w"]
    puts $fh "metric,value"
    foreach pair $pairs {
        puts $fh "[lindex $pair 0],[lindex $pair 1]"
    }
    close $fh
}

proc bool_str {flag} {
    if {$flag} { return "true" }
    return "false"
}

proc safe_rebuild_dir {step14_dir target_dir required_tail} {
    set norm_target [file normalize $target_dir]
    set parent_l [string tolower [file normalize $step14_dir]]
    set target_l [string tolower $norm_target]
    if {[string first $parent_l $target_l] != 0 || [file tail $norm_target] ne $required_tail} {
        error "Refusing to delete unsafe validate directory: $norm_target"
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

proc file_contains {path pattern} {
    if {![file exists $path]} { return 0 }
    set fh [open $path "r"]
    set data [read $fh]
    close $fh
    return [regexp $pattern $data]
}

proc parse_first_number {text patterns default_value} {
    foreach pattern $patterns {
        if {[regexp -nocase $pattern $text -> value]} {
            return $value
        }
    }
    return $default_value
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
    foreach line [split $text "\n"] {
        if {[regexp -nocase {Worst Slack[ \t]+(-?[0-9]+(\.[0-9]+)?)ns} $line -> value frac]} {
            return $value
        }
        if {[regexp -nocase {Slack[ \t]+\(VIOLATED\)[ \t]*:[ \t]*(-?[0-9]+(\.[0-9]+)?)ns} $line -> value frac]} {
            return $value
        }
    }
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
    foreach line [split $text "\n"] {
        if {[regexp -nocase {Total Negative Slack[ \t]+(-?[0-9]+(\.[0-9]+)?)ns} $line -> value frac]} {
            return $value
        }
    }
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

proc count_regex {text pattern} {
    return [regexp -all -nocase $pattern $text]
}

proc parse_drc_table_count {text rule} {
    set pattern [format {^\|[ \t]*%s[ \t]*\|[^|]*\|[^|]*\|[ \t]*([0-9]+)[ \t]*\|} $rule]
    foreach line [split $text "\n"] {
        if {[regexp -nocase $pattern $line -> value]} {
            return $value
        }
    }
    return 0
}

proc parse_drc_detail_count {text rule} {
    set pattern [format {^%s#[0-9]+[ \t]+} $rule]
    return [regexp -all -line -nocase $pattern $text]
}

proc parse_drc_rule_counts {text} {
    set result {}
    foreach rule {DPIP-1 DPOP-1 DPOP-2 ZPS7-1} {
        set table_count [parse_drc_table_count $text $rule]
        set detail_count [parse_drc_detail_count $text $rule]
        lappend result $rule $table_count
        lappend result "${rule},detail" $detail_count
        lappend result "${rule},consistent" [expr {$table_count == $detail_count}]
    }
    return $result
}

proc parse_timing_detail {text key default_value} {
    foreach line [split $text "\n"] {
        if {$key eq "source" && [regexp -nocase {Source:[ \t]+([^ \t]+)} $line -> value]} {
            return $value
        }
        if {$key eq "destination" && [regexp -nocase {Destination:[ \t]+([^ \t]+)} $line -> value]} {
            return $value
        }
        if {$key eq "data_delay" && [regexp -nocase {Data Path Delay:[ \t]+([0-9]+(\.[0-9]+)?)} $line -> value frac]} {
            return $value
        }
        if {$key eq "logic_levels" && [regexp -nocase {Logic Levels:[ \t]+([0-9]+)} $line -> value]} {
            return $value
        }
    }
    return $default_value
}

proc find_files_recursive {root pattern} {
    set result {}
    foreach item [glob -nocomplain -directory $root *] {
        if {[file isdirectory $item]} {
            set result [concat $result [find_files_recursive $item $pattern]]
        } elseif {[string match $pattern [file tail $item]]} {
            lappend result $item
        }
    }
    return $result
}

proc scrub_step14_abs_path {path step14_dir} {
    if {![file exists $path]} {
        return
    }
    set norm_step14 [file normalize $step14_dir]
    set slash_step14 [string map {\\ /} $norm_step14]
    set backslash_step14 [string map {/ \\} $slash_step14]

    set fh [open $path "r"]
    set data [read $fh]
    close $fh

    set data [string map [list \
        $slash_step14 "<STEP14_DIR>" \
        $backslash_step14 "<STEP14_DIR>" \
    ] $data]

    set fh [open $path "w"]
    puts -nonewline $fh $data
    close $fh
}

if {[info exists ::env(STEP14_FPGA_PART)] && $::env(STEP14_FPGA_PART) ne ""} {
    set fpga_part $::env(STEP14_FPGA_PART)
    set fpga_part_source "environment"
    set reference_device_only "false"
} else {
    set fpga_part "xc7z020clg400-1"
    set fpga_part_source "reference_default"
    set reference_device_only "true"
}
if {[info exists ::env(STEP14_CLOCK_MHZ)] && $::env(STEP14_CLOCK_MHZ) ne ""} {
    set clock_mhz $::env(STEP14_CLOCK_MHZ)
} else {
    set clock_mhz 200
}
set clock_period_ns [expr {1000.0 / double($clock_mhz)}]

proc write_catalog_summary {path registration ipdef_count create_ip_pass generate_target_pass sim_target synth_target blocker} {
    global ip_vlnv
    write_pairs $path [list \
        [list ip_catalog_registration_pass_flag [bool_str $registration]] \
        [list ipdef_count $ipdef_count] \
        [list ipdef_vlnv $ip_vlnv] \
        [list create_ip_pass_flag [bool_str $create_ip_pass]] \
        [list generate_target_pass_flag [bool_str $generate_target_pass]] \
        [list generated_module_name dbf_axis_0] \
        [list simulation_target_generated_flag [bool_str $sim_target]] \
        [list synthesis_target_generated_flag [bool_str $synth_target]] \
        [list formal_result_claimed false] \
        [list blocker_if_any $blocker] \
    ]
}

proc write_xsim_summary {path registration create_ip_pass gen_sim compile elaboration simulation tb_created output_created xsim_pass blocker} {
    write_pairs $path [list \
        [list tool_vivado_found true] \
        [list tool_xvlog_found true] \
        [list tool_xelab_found true] \
        [list tool_xsim_found true] \
        [list ip_catalog_registration_pass_flag [bool_str $registration]] \
        [list create_ip_pass_flag [bool_str $create_ip_pass]] \
        [list generate_simulation_target_pass_flag [bool_str $gen_sim]] \
        [list compile_status $compile] \
        [list elaboration_status $elaboration] \
        [list simulation_status $simulation] \
        [list packaged_ip_tb_summary_created [bool_str $tb_created]] \
        [list packaged_ip_output_csv_created [bool_str $output_created]] \
        [list packaged_ip_xsim_pass_flag [bool_str $xsim_pass]] \
        [list formal_result_claimed false] \
        [list blocker_if_any $blocker] \
    ]
}

proc write_synth_summary {path status lut ff dsp bram18 bram36 uram dram wns timing_met mem_flag blocker} {
    global vivado_version fpga_part fpga_part_source reference_device_only clock_mhz clock_period_ns
    write_pairs $path [list \
        [list vivado_version $vivado_version] \
        [list fpga_part $fpga_part] \
        [list fpga_part_source $fpga_part_source] \
        [list reference_device_only $reference_device_only] \
        [list clock_MHz $clock_mhz] \
        [list clock_period_ns [format %.3f $clock_period_ns]] \
        [list packaged_ip_ooc_synthesis_status $status] \
        [list LUT $lut] \
        [list FF $ff] \
        [list DSP $dsp] \
        [list BRAM18 $bram18] \
        [list BRAM36 $bram36] \
        [list URAM $uram] \
        [list distributed_RAM $dram] \
        [list WNS_ns $wns] \
        [list timing_200MHz_met_flag [bool_str $timing_met]] \
        [list w_memory_inferred_flag [bool_str $mem_flag]] \
        [list formal_result_claimed false] \
        [list implementation_closure_claimed false] \
        [list board_validation_flag false] \
        [list blocker_if_any $blocker] \
    ]
}

if {[llength [get_parts -quiet $fpga_part]] != 1} {
    set blocker_if_any "requested_fpga_part_not_found"
    write_catalog_summary [file join $pkg_result_dir "step14_2_ip_catalog_summary.csv"] false 0 false false false false $blocker_if_any
    write_xsim_summary [file join $xsim_result_dir "step14_2_packaged_ip_xsim_summary.csv"] false false false unavailable unavailable unavailable false false false $blocker_if_any
    write_synth_summary [file join $synth_result_dir "step14_2_packaged_ip_ooc_synthesis_summary.csv"] not_run 0 0 0 0 0 0 0 NA false false $blocker_if_any
    error $blocker_if_any
}

safe_rebuild_dir $step14_dir $work_dir "step14_2a_validate"
create_project step14_2a_validate $work_dir -part $fpga_part -force
set_property ip_repo_paths $ip_repo_dir [current_project]
update_ip_catalog

set ipdefs [get_ipdefs -all $ip_vlnv]
set ipdef_count [llength $ipdefs]
set ip_catalog_registration_pass_flag [expr {$ipdef_count == 1}]
if {!$ip_catalog_registration_pass_flag} {
    set blocker_if_any "ip_catalog_registration_failed"
}

set create_ip_pass_flag false
set generate_target_pass_flag false
set simulation_target_generated_flag false
set synthesis_target_generated_flag false

if {$ip_catalog_registration_pass_flag} {
    if {[catch {create_ip -vlnv $ip_vlnv -module_name dbf_axis_0} err]} {
        set blocker_if_any "create_ip_failed"
    } else {
        set create_ip_pass_flag true
        if {[catch {generate_target all [get_ips dbf_axis_0]} err]} {
            set blocker_if_any "generate_target_failed"
        } else {
            set generate_target_pass_flag true
        }
    }
}

set xci_files [get_files -quiet *dbf_axis_0.xci]
set generated_module_found false
foreach full [find_files_recursive $work_dir *dbf_axis_0*.v] {
    if {[file_contains $full {module[ \t\r\n]+dbf_axis_0}]} {
        set generated_module_found true
    }
}
foreach full [find_files_recursive $work_dir *dbf_axis_0*.sv] {
    if {[file_contains $full {module[ \t\r\n]+dbf_axis_0}]} {
        set generated_module_found true
    }
}
set sim_glob [glob -nocomplain [file join $work_dir "*.ip_user_files" "sim_scripts" "dbf_axis_0" "*"]]
set synth_glob [glob -nocomplain [file join $work_dir "*.srcs" "sources_1" "ip" "dbf_axis_0" "*.xci"]]
set simulation_target_generated_flag [expr {[llength $sim_glob] > 0 || $generated_module_found}]
set synthesis_target_generated_flag [expr {[llength $synth_glob] > 0 || [llength $xci_files] > 0}]
if {!$generated_module_found && $blocker_if_any eq ""} {
    set blocker_if_any "generated_module_dbf_axis_0_not_found"
}

write_catalog_summary [file join $pkg_result_dir "step14_2_ip_catalog_summary.csv"] \
    $ip_catalog_registration_pass_flag $ipdef_count $create_ip_pass_flag $generate_target_pass_flag \
    $simulation_target_generated_flag $synthesis_target_generated_flag $blocker_if_any

set compile_status "not_run"
set elaboration_status "not_run"
set simulation_status "not_run"
set packaged_ip_xsim_pass_flag false
set tb_created false
set output_created false

if {$create_ip_pass_flag && $generate_target_pass_flag} {
    set tb_file [file normalize [file join $step14_dir "tb" "tb_dbf_axis_packaged_ip.v"]]
    set y_mem [file normalize [file join $step14_dir "results_step14_dbf_ip_soc_integration" "axis_vectors" "step14_1_y_axis_tdata.mem"]]
    set z_mem [file normalize [file join $step14_dir "results_step14_dbf_ip_soc_integration" "axis_vectors" "step14_1_z_axis_expected.mem"]]
    set xsim_run_dir [file normalize [file join $work_dir "step14_2_validate.sim" "sim_1" "behav" "xsim"]]
    set y_mem_run [file join $xsim_run_dir "step14_1_y_axis_tdata.mem"]
    set z_mem_run [file join $xsim_run_dir "step14_1_z_axis_expected.mem"]
    set output_run_path [file join $xsim_run_dir "step14_2_packaged_ip_output.csv"]
    set tb_summary_run_path [file join $xsim_run_dir "step14_2_packaged_ip_tb_summary.csv"]
    add_files -fileset sim_1 -norecurse $tb_file
    add_files -fileset sim_1 -norecurse $y_mem
    add_files -fileset sim_1 -norecurse $z_mem
    set_property top tb_dbf_axis_packaged_ip [get_filesets sim_1]
    set_property xsim.simulate.runtime all [get_filesets sim_1]
    set_property target_simulator XSim [current_project]
    update_compile_order -fileset sim_1
    file mkdir $xsim_run_dir
    file copy -force $y_mem $y_mem_run
    file copy -force $z_mem $z_mem_run
    if {[catch {launch_simulation -simset sim_1 -mode behavioral} err]} {
        set simulation_status "fail"
        if {$blocker_if_any eq ""} { set blocker_if_any "packaged_ip_xsim_failed" }
    } else {
        set compile_status "pass"
        set elaboration_status "pass"
        set simulation_status "pass"
    }
    catch {close_sim}
    set tb_summary_path [file join $xsim_result_dir "step14_2_packaged_ip_tb_summary.csv"]
    set output_path [file join $xsim_result_dir "step14_2_packaged_ip_output.csv"]
    if {[file exists $tb_summary_run_path]} {
        file copy -force $tb_summary_run_path $tb_summary_path
    }
    if {[file exists $output_run_path]} {
        file copy -force $output_run_path $output_path
    }
    set tb_created [file exists $tb_summary_path]
    set output_created [file exists $output_path]
    set tb_pass [expr {[read_metric $tb_summary_path packaged_ip_tb_pass_flag false] eq "true"}]
    set packaged_ip_xsim_pass_flag [expr {$tb_created && $output_created && $tb_pass && $simulation_status eq "pass"}]
    if {!$packaged_ip_xsim_pass_flag && $blocker_if_any eq ""} {
        set blocker_if_any "packaged_ip_tb_failed"
    }
} else {
    set compile_status "not_run"
    set elaboration_status "not_run"
    set simulation_status "not_run"
    set tb_created false
    set output_created false
}
if {![info exists tb_created]} { set tb_created [file exists [file join $xsim_result_dir "step14_2_packaged_ip_tb_summary.csv"]] }
if {![info exists output_created]} { set output_created [file exists [file join $xsim_result_dir "step14_2_packaged_ip_output.csv"]] }
write_xsim_summary [file join $xsim_result_dir "step14_2_packaged_ip_xsim_summary.csv"] \
    $ip_catalog_registration_pass_flag $create_ip_pass_flag $generate_target_pass_flag \
    $compile_status $elaboration_status $simulation_status $tb_created $output_created \
    $packaged_ip_xsim_pass_flag $blocker_if_any

set synth_status "not_run"
set lut 0
set ff 0
set dsp 0
set bram18 0
set bram36 0
set uram 0
set distributed_ram 0
set wns "NA"
set tns "NA"
set failing_endpoints 0
set worst_path_source "NA"
set worst_path_destination "NA"
set worst_path_data_delay_ns "NA"
set worst_path_logic_levels "NA"
set dpip_1_count 0
set dpop_1_count 0
set dpop_2_count 0
set zps7_1_count 0
set dpip_1_detail_count 0
set dpop_1_detail_count 0
set dpop_2_detail_count 0
set zps7_1_detail_count 0
set drc_parser_consistency_pass_flag false
set bram36_equiv 0
set w_memory_resource_optimization_pass_flag false
set timing_validates_advertised_clock_flag false
set timing_met false
set w_memory_inferred_flag false

if {$create_ip_pass_flag && $generate_target_pass_flag} {
    if {[catch {
        generate_target synthesis [get_ips dbf_axis_0]
        set_property top dbf_axis_0 [current_fileset]
        update_compile_order -fileset sources_1
        synth_design -top dbf_axis_0 -part $fpga_part -mode out_of_context
    } synth_err]} {
        set synth_status "fail"
        if {$blocker_if_any eq ""} { set blocker_if_any "packaged_ip_ooc_synthesis_failed" }
    } else {
        set synth_status "pass"
        create_clock -period $clock_period_ns -name aclk [get_ports aclk]
        set util_report [file join $synth_result_dir "packaged_ip_utilization_optimized.rpt"]
        set timing_report [file join $synth_result_dir "packaged_ip_timing_summary_optimized.rpt"]
        set drc_report [file join $synth_result_dir "packaged_ip_drc_optimized.rpt"]
        report_utilization -file $util_report
        report_timing_summary -file $timing_report
        report_drc -file $drc_report
        set timing_detail_report [report_timing -max_paths 1 -return_string]
        scrub_step14_abs_path $util_report $step14_dir
        scrub_step14_abs_path $timing_report $step14_dir
        scrub_step14_abs_path $drc_report $step14_dir

        set util_text [report_utilization -return_string]
        set timing_text [report_timing_summary -return_string]
        set drc_text [report_drc -return_string]
        set lut [parse_table_used $util_text [list {CLB LUTs} {Slice LUTs}] 0]
        set ff [parse_table_used $util_text [list {CLB Registers} {Slice Registers}] 0]
        set dsp [parse_table_used $util_text [list {DSPs} {DSP48E1} {DSP48E2}] 0]
        set bram18 [parse_table_used $util_text [list {RAMB18} {RAMB18/FIFO}] 0]
        set bram36 [parse_table_used $util_text [list {RAMB36} {RAMB36/FIFO}] 0]
        if {$bram36 == 0} {
            set bram36 [parse_table_used $util_text [list {RAMB36E1 only} {RAMB36E1}] 0]
        }
        if {$bram18 == 0} {
            set bram18 [parse_table_used $util_text [list {RAMB18E1 only} {RAMB18E1}] 0]
        }
        set uram [parse_table_used $util_text [list {URAM}] 0]
        set distributed_ram [parse_table_used $util_text [list {Distributed RAM} {LUT as Memory} {LUTRAM}] 0]
        set wns [parse_wns $timing_text NA]
        set tns [parse_tns $timing_text NA]
        set failing_endpoints [parse_failing_endpoints $timing_text 0]
        set worst_path_source [parse_timing_detail $timing_detail_report "source" "NA"]
        set worst_path_destination [parse_timing_detail $timing_detail_report "destination" "NA"]
        set worst_path_data_delay_ns [parse_timing_detail $timing_detail_report "data_delay" "NA"]
        set worst_path_logic_levels [parse_timing_detail $timing_detail_report "logic_levels" "NA"]
        array set drc_counts [parse_drc_rule_counts $drc_text]
        set dpip_1_count $drc_counts(DPIP-1)
        set dpip_1_detail_count $drc_counts(DPIP-1,detail)
        set dpop_1_count $drc_counts(DPOP-1)
        set dpop_1_detail_count $drc_counts(DPOP-1,detail)
        set dpop_2_count $drc_counts(DPOP-2)
        set dpop_2_detail_count $drc_counts(DPOP-2,detail)
        set zps7_1_count $drc_counts(ZPS7-1)
        set zps7_1_detail_count $drc_counts(ZPS7-1,detail)
        set drc_parser_consistency_pass_flag [expr {$drc_counts(DPIP-1,consistent) && $drc_counts(DPOP-1,consistent) && $drc_counts(DPOP-2,consistent) && $drc_counts(ZPS7-1,consistent)}]
        if {$wns ne "NA"} {
            set timing_met [expr {double($wns) >= 0.0}]
        }
        set timing_validates_advertised_clock_flag $timing_met
        set bram36_equiv [expr {double($bram36) + double($bram18) / 2.0}]
        set w_memory_inferred_flag [expr {double($bram18) > 0.0 || double($bram36) > 0.0 || double($uram) > 0.0 || double($distributed_ram) > 0.0}]
        set w_memory_resource_optimization_pass_flag [expr {$w_memory_inferred_flag && $bram36_equiv <= 16.0}]
        if {!$w_memory_inferred_flag && $blocker_if_any eq ""} {
            set blocker_if_any "w_rom_not_inferred_as_memory_resource"
        }
        if {!$w_memory_resource_optimization_pass_flag && $blocker_if_any eq ""} {
            set blocker_if_any "w_rom_bram36_equivalent_above_16"
        }
        if {!$timing_met && $blocker_if_any eq ""} {
            set blocker_if_any "timing_200MHz_not_met"
        }
    }
}
write_synth_summary [file join $synth_result_dir "step14_2_packaged_ip_ooc_synthesis_summary.csv"] \
    $synth_status $lut $ff $dsp $bram18 $bram36 $uram $distributed_ram $wns \
    $timing_met $w_memory_inferred_flag $blocker_if_any

write_pairs [file join $synth_result_dir "step14_2a_timing_path_summary.csv"] [list \
    [list clock_MHz $clock_mhz] \
    [list clock_period_ns [format %.3f $clock_period_ns]] \
    [list WNS_ns $wns] \
    [list TNS_ns $tns] \
    [list failing_endpoints $failing_endpoints] \
    [list timing_200MHz_met_flag [bool_str $timing_met]] \
    [list worst_path_source $worst_path_source] \
    [list worst_path_destination $worst_path_destination] \
    [list worst_path_data_delay_ns $worst_path_data_delay_ns] \
    [list worst_path_logic_levels $worst_path_logic_levels] \
    [list formal_result_claimed false] \
]

write_pairs [file join $synth_result_dir "step14_2a_drc_warning_summary.csv"] [list \
    [list DPIP_1_count $dpip_1_count] \
    [list DPOP_1_count $dpop_1_count] \
    [list DPOP_2_count $dpop_2_count] \
    [list ZPS7_1_count $zps7_1_count] \
    [list DPIP_1_detail_count $dpip_1_detail_count] \
    [list DPOP_1_detail_count $dpop_1_detail_count] \
    [list DPOP_2_detail_count $dpop_2_detail_count] \
    [list ZPS7_1_detail_count $zps7_1_detail_count] \
    [list drc_parser_consistency_pass_flag [bool_str $drc_parser_consistency_pass_flag]] \
    [list zps7_1_expected_warning true] \
    [list formal_result_claimed false] \
]

write_pairs [file join $synth_result_dir "step14_2a_resource_comparison.csv"] [list \
    [list old_LUT 3594] \
    [list new_LUT $lut] \
    [list old_FF 1810] \
    [list new_FF $ff] \
    [list old_DSP 28] \
    [list new_DSP $dsp] \
    [list old_BRAM18 0] \
    [list new_BRAM18 $bram18] \
    [list old_BRAM36 28] \
    [list new_BRAM36 $bram36] \
    [list old_BRAM36_equiv 28] \
    [list new_BRAM36_equiv [format %.3f $bram36_equiv]] \
    [list old_WNS_ns -8.586] \
    [list new_WNS_ns $wns] \
    [list w_memory_resource_optimization_pass_flag [bool_str $w_memory_resource_optimization_pass_flag]] \
    [list formal_result_claimed false] \
]

write_pairs [file join $synth_result_dir "step14_2a_optimized_ip_ooc_summary.csv"] [list \
    [list vivado_version $vivado_version] \
    [list fpga_part $fpga_part] \
    [list fpga_part_source $fpga_part_source] \
    [list reference_device_only $reference_device_only] \
    [list clock_MHz $clock_mhz] \
    [list clock_period_ns [format %.3f $clock_period_ns]] \
    [list advertised_aclk_Hz 200000000] \
    [list advertised_clock_MHz 200] \
    [list packaged_ip_ooc_synthesis_status $synth_status] \
    [list LUT $lut] \
    [list FF $ff] \
    [list DSP $dsp] \
    [list BRAM18 $bram18] \
    [list BRAM36 $bram36] \
    [list BRAM36_equiv [format %.3f $bram36_equiv]] \
    [list URAM $uram] \
    [list distributed_RAM $distributed_ram] \
    [list WNS_ns $wns] \
    [list TNS_ns $tns] \
    [list failing_endpoints $failing_endpoints] \
    [list timing_200MHz_met_flag [bool_str $timing_met]] \
    [list timing_validates_advertised_clock_flag [bool_str $timing_validates_advertised_clock_flag]] \
    [list worst_path_source $worst_path_source] \
    [list worst_path_destination $worst_path_destination] \
    [list worst_path_data_delay_ns $worst_path_data_delay_ns] \
    [list worst_path_logic_levels $worst_path_logic_levels] \
    [list w_memory_inferred_flag [bool_str $w_memory_inferred_flag]] \
    [list w_memory_resource_optimization_pass_flag [bool_str $w_memory_resource_optimization_pass_flag]] \
    [list formal_result_claimed false] \
    [list implementation_closure_claimed false] \
    [list board_validation_flag false] \
    [list blocker_if_any $blocker_if_any] \
]

close_project

if {!$ip_catalog_registration_pass_flag || !$create_ip_pass_flag || !$generate_target_pass_flag || !$packaged_ip_xsim_pass_flag || $synth_status ne "pass" || !$w_memory_inferred_flag} {
    error "Step14.2 validation failed: $blocker_if_any"
}
