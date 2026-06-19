# Step13.4 Vivado 2024.2 out-of-context synthesis.
#
# This script is intentionally limited to FPGA DBF arithmetic tops. It does not
# run implementation, generate a bitstream, or synthesize CPU/SoC-side ML logic.

proc step13_bool_text {value} {
    if {$value} { return "true" }
    return "false"
}

proc step13_csv_value {value} {
    set text [string map {"\"" "\"\""} $value]
    if {[regexp {[,\"\n\r]} $text]} {
        return "\"$text\""
    }
    return $text
}

proc step13_write_kv_csv {path rows} {
    set fh [open $path w]
    puts $fh "metric,value"
    foreach row $rows {
        puts $fh "[step13_csv_value [lindex $row 0]],[step13_csv_value [lindex $row 1]]"
    }
    close $fh
}

proc step13_write_resource_csv {path rows} {
    set fh [open $path w]
    puts $fh "architecture,LUT,FF,DSP,BRAM18,BRAM36,URAM,WNS_ns,timing_met_flag,synthesis_status,note"
    foreach row $rows {
        puts $fh [join [list \
            [step13_csv_value [dict get $row architecture]] \
            [dict get $row LUT] [dict get $row FF] [dict get $row DSP] \
            [dict get $row BRAM18] [dict get $row BRAM36] [dict get $row URAM] \
            [dict get $row WNS_ns] [dict get $row timing_met_flag] \
            [dict get $row synthesis_status] [step13_csv_value [dict get $row note]]] ","]
    }
    close $fh
}

proc step13_find_root {} {
    set cwd [file normalize [pwd]]
    if {[file isdirectory [file join $cwd rtl]] && [file isdirectory [file join $cwd synth]]} {
        return $cwd
    }
    if {[file tail $cwd] eq "synth"} {
        set parent [file normalize [file join $cwd ..]]
        if {[file isdirectory [file join $parent rtl]] && [file isdirectory [file join $parent synth]]} {
            return $parent
        }
    }
    set script_dir [file dirname [file normalize [info script]]]
    if {[file tail $script_dir] eq "synth"} {
        return [file normalize [file join $script_dir ..]]
    }
    error "Cannot locate Step13 DBF boundary directory."
}

proc step13_env {name default_value} {
    if {[info exists ::env($name)] && [string trim $::env($name)] ne ""} {
        return [string trim $::env($name)]
    }
    return $default_value
}

proc step13_repo_parts {repo_root} {
    set parts {}
    set rg_status [catch {
        exec rg -n {set_part|create_project.*-part|xc7|xczu|xcku|xcau|xcvu} $repo_root
    } rg_text]
    if {$rg_status != 0} {
        return $parts
    }
    foreach token [regexp -all -inline -nocase {(xc7[a-z0-9]+[-a-z0-9]*|xczu[a-z0-9]+[-a-z0-9]*|xcku[a-z0-9]+[-a-z0-9]*|xcau[a-z0-9]+[-a-z0-9]*|xcvu[a-z0-9]+[-a-z0-9]*)} $rg_text] {
        set part [string tolower [string trim $token]]
        if {[llength [get_parts -quiet $part]] > 0 && [lsearch -exact $parts $part] < 0} {
            lappend parts $part
        }
    }
    return $parts
}

proc step13_select_part {step_dir} {
    set requested [step13_env STEP13_FPGA_PART ""]
    if {$requested ne ""} {
        if {[llength [get_parts -quiet $requested]] > 0} {
            return [dict create part $requested source environment reference_only false blocker ""]
        }
        return [dict create part $requested source environment reference_only false blocker invalid_requested_fpga_part]
    }

    set repo_root [file normalize [file join $step_dir .. ..]]
    set repo_parts [step13_repo_parts $repo_root]
    if {[llength $repo_parts] == 1} {
        return [dict create part [lindex $repo_parts 0] source repository_existing_configuration reference_only false blocker ""]
    }

    foreach candidate {xc7z020clg400-1 xczu3eg-sbva484-1-e xc7a200tsbg484-1} {
        if {[llength [get_parts -quiet $candidate]] > 0} {
            return [dict create part $candidate source reference_default reference_only true blocker ""]
        }
    }
    return [dict create part unavailable source unavailable reference_only false blocker no_supported_reference_part_installed]
}

proc step13_read_shift {step_dir} {
    set meta [file join $step_dir results_step13_fpga_soc_dbf_boundary rtl_fulln step13_4_fulln_metadata.csv]
    if {![file exists $meta]} { return "NaN" }
    set fh [open $meta r]
    set text [read $fh]
    close $fh
    foreach line [split $text "\n"] {
        if {[string match "engineering_Z_shift_bits,*" $line]} {
            return [string trim [lindex [split $line ","] 1] "\" "]
        }
    }
    return "NaN"
}

proc step13_extract_util {util_text regex fallback_filter} {
    foreach line [split $util_text "\n"] {
        if {[regexp $regex $line -> used]} {
            return [string trim $used]
        }
    }
    if {$fallback_filter ne ""} {
        set count_status [catch {llength [get_cells -quiet -hier -filter $fallback_filter]} count]
        if {$count_status == 0} { return $count }
    }
    return "0"
}

proc step13_wns {} {
    set paths [get_timing_paths -quiet -setup -max_paths 1]
    if {[llength $paths] == 0} {
        return "NaN"
    }
    set slack [get_property SLACK [lindex $paths 0]]
    if {$slack eq ""} { return "NaN" }
    return [format "%.3f" $slack]
}

proc step13_timing_met {wns} {
    if {$wns eq "NaN" || $wns eq ""} { return "false" }
    if {[expr {double($wns) >= 0.0}]} { return "true" }
    return "false"
}

proc step13_run_ooc {step_dir result_dir part period_ns top label report_prefix} {
    set files [list \
        [file join $step_dir rtl dbf_complex_mac.v] \
        [file join $step_dir rtl dbf_beam_accum_core.v] \
        [file join $step_dir rtl dbf_z24_quantizer.v] \
        [file join $step_dir rtl dbf_core_z24.v] \
        [file join $step_dir rtl dbf_core_z24_bparallel.v] \
        [file join $step_dir rtl dbf_core_z24_ref_top.v] \
        [file join $step_dir rtl dbf_core_z24_b7_ref_top.v]]

    catch {close_design -quiet}
    set note ""
    set status "pass"
    set synth_status [catch {
        set old_dir [pwd]
        cd [file join $step_dir rtl]
        read_verilog $files
        cd $old_dir
        synth_design -mode out_of_context -flatten_hierarchy rebuilt -part $part -top $top
        create_clock -name clk -period $period_ns [get_ports clk]
    } synth_msg]
    if {$synth_status != 0} {
        puts $synth_msg
        set note "synth_design_failed"
        return [dict create architecture $label synthesis_status fail LUT NaN FF NaN DSP NaN BRAM18 NaN BRAM36 NaN URAM NaN WNS_ns NaN timing_met_flag false note $note]
    }

    set util_path [file join $result_dir "${report_prefix}_utilization.rpt"]
    set timing_path [file join $result_dir "${report_prefix}_timing_summary.rpt"]
    set drc_path [file join $result_dir "${report_prefix}_drc.rpt"]
    set util_text [report_utilization -return_string]
    set fh [open $util_path w]
    puts $fh $util_text
    close $fh
    report_timing_summary -file $timing_path -warn_on_violation
    report_drc -file $drc_path

    set lut [step13_extract_util $util_text {\|\s*CLB LUTs[^|]*\|\s*([0-9]+)} {REF_NAME =~ LUT*}]
    set ff [step13_extract_util $util_text {\|\s*CLB Registers[^|]*\|\s*([0-9]+)} {REF_NAME =~ FD*}]
    set dsp [step13_extract_util $util_text {\|\s*DSPs[^|]*\|\s*([0-9]+)} {REF_NAME =~ DSP*}]
    set bram18 [step13_extract_util $util_text {\|\s*RAMB18[^|]*\|\s*([0-9]+)} {REF_NAME =~ RAMB18*}]
    set bram36 [step13_extract_util $util_text {\|\s*RAMB36[^|]*\|\s*([0-9]+)} {REF_NAME =~ RAMB36*}]
    set uram [step13_extract_util $util_text {\|\s*URAM[^|]*\|\s*([0-9]+)} {REF_NAME =~ URAM*}]
    set wns [step13_wns]
    set timing_met [step13_timing_met $wns]

    return [dict create architecture $label synthesis_status $status LUT $lut FF $ff DSP $dsp BRAM18 $bram18 BRAM36 $bram36 URAM $uram WNS_ns $wns timing_met_flag $timing_met note "post_synthesis_ooc_only"]
}

set step_dir [step13_find_root]
cd $step_dir
set result_dir [file join $step_dir results_step13_fpga_soc_dbf_boundary synth]
file mkdir $result_dir
file mkdir [file join $step_dir synth work]

set clock_mhz [step13_env STEP13_4_CLOCK_MHZ 200]
set period_ns [format "%.3f" [expr {1000.0 / double($clock_mhz)}]]
set part_info [step13_select_part $step_dir]
set part [dict get $part_info part]
set part_source [dict get $part_info source]
set reference_only [dict get $part_info reference_only]
set blocker [dict get $part_info blocker]
set summary_path [file join $result_dir step13_4_ooc_synthesis_summary.csv]
set resource_path [file join $result_dir step13_4_ooc_resource_comparison.csv]

if {$blocker ne ""} {
    step13_write_kv_csv $summary_path [list \
        [list vivado_version [version -short]] \
        [list fpga_part $part] \
        [list fpga_part_source $part_source] \
        [list reference_device_only [step13_bool_text $reference_only]] \
        [list clock_MHz $clock_mhz] \
        [list clock_period_ns $period_ns] \
        [list single_lane_synthesis_status unavailable] \
        [list b7_synthesis_status unavailable] \
        [list ooc_synthesis_pass_flag false] \
        [list timing_200MHz_met_flag false] \
        [list formal_result_claimed false] \
        [list implementation_closure_claimed false] \
        [list board_validation_flag false] \
        [list blocker_if_any $blocker]]
    step13_write_resource_csv $resource_path {}
    error $blocker
}

puts "STEP13_4_SYNTH: part=$part source=$part_source reference_only=[step13_bool_text $reference_only] clock_MHz=$clock_mhz"
set single [step13_run_ooc $step_dir $result_dir $part $period_ns dbf_core_z24_ref_top single_lane single_lane]
set b7 [step13_run_ooc $step_dir $result_dir $part $period_ns dbf_core_z24_b7_ref_top b7_parallel b7_parallel]

set single_pass [expr {[dict get $single synthesis_status] eq "pass"}]
set b7_pass [expr {[dict get $b7 synthesis_status] eq "pass"}]
set ooc_pass [expr {$single_pass && $b7_pass}]
set timing_met [expr {[dict get $single timing_met_flag] eq "true" && [dict get $b7 timing_met_flag] eq "true"}]
set dsp_lane "NaN"
if {[string is integer -strict [dict get $single DSP]]} {
    set dsp_lane [dict get $single DSP]
}
set blocker_if_any ""
if {!$ooc_pass} {
    set blocker_if_any "ooc_synthesis_failed"
}
set timing_followup ""
if {$ooc_pass && !$timing_met} {
    set timing_followup "pipeline_complex_multiplier_or_accumulator"
}

step13_write_resource_csv $resource_path [list $single $b7]
step13_write_kv_csv $summary_path [list \
    [list vivado_version [version -short]] \
    [list fpga_part $part] \
    [list fpga_part_source $part_source] \
    [list reference_device_only [step13_bool_text $reference_only]] \
    [list clock_MHz $clock_mhz] \
    [list clock_period_ns $period_ns] \
    [list engineering_Z_shift_bits [step13_read_shift $step_dir]] \
    [list single_lane_synthesis_status [dict get $single synthesis_status]] \
    [list single_lane_LUT [dict get $single LUT]] \
    [list single_lane_FF [dict get $single FF]] \
    [list single_lane_DSP [dict get $single DSP]] \
    [list single_lane_BRAM18 [dict get $single BRAM18]] \
    [list single_lane_BRAM36 [dict get $single BRAM36]] \
    [list single_lane_URAM [dict get $single URAM]] \
    [list single_lane_WNS_ns [dict get $single WNS_ns]] \
    [list single_lane_timing_met_flag [dict get $single timing_met_flag]] \
    [list b7_synthesis_status [dict get $b7 synthesis_status]] \
    [list b7_LUT [dict get $b7 LUT]] \
    [list b7_FF [dict get $b7 FF]] \
    [list b7_DSP [dict get $b7 DSP]] \
    [list b7_BRAM18 [dict get $b7 BRAM18]] \
    [list b7_BRAM36 [dict get $b7 BRAM36]] \
    [list b7_URAM [dict get $b7 URAM]] \
    [list b7_WNS_ns [dict get $b7 WNS_ns]] \
    [list b7_timing_met_flag [dict get $b7 timing_met_flag]] \
    [list dsp_per_complex_lane_actual $dsp_lane] \
    [list rough_DSP_estimate_previous 21] \
    [list rough_vs_actual_note actual_counts_are_from_vivado_ooc_synthesis_not_rough_estimates] \
    [list ooc_synthesis_pass_flag [step13_bool_text $ooc_pass]] \
    [list timing_200MHz_met_flag [step13_bool_text $timing_met]] \
    [list timing_blocker_or_followup $timing_followup] \
    [list formal_result_claimed false] \
    [list implementation_closure_claimed false] \
    [list board_validation_flag false] \
    [list blocker_if_any $blocker_if_any]]

puts "STEP13_4_SYNTH_DONE: ooc_pass=[step13_bool_text $ooc_pass] timing_200MHz=[step13_bool_text $timing_met]"
if {!$ooc_pass} {
    error "Step13.4 OOC synthesis failed."
}
