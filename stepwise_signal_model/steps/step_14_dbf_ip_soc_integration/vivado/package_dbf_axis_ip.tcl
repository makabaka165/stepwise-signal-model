set script_dir [file dirname [file normalize [info script]]]
set step14_dir [file normalize [file join $script_dir ".."]]
set repo_root [file normalize [file join $step14_dir ".." ".."]]
set ip_root [file normalize [file join $step14_dir "ip_repo" "dbf_axis_ip_1_0"]]
set work_dir [file normalize [file join $step14_dir "vivado" "work" "step14_2a_package"]]
set result_dir [file normalize [file join $step14_dir "results_step14_dbf_ip_soc_integration" "ip_package"]]
file mkdir $result_dir

set ip_vlnv "user.org:radar:dbf_axis:1.0"
set blocker_if_any ""
set reference_device_only "false"

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

proc rel_to {base path} {
    set base [file normalize $base]
    set path [file normalize $path]
    if {[string first [string tolower $base] [string tolower $path]] == 0} {
        set rel [string range $path [expr {[string length $base] + 1}] end]
        return [string map {"\\" "/"} $rel]
    }
    return [string map {"\\" "/"} $path]
}

proc path_inside {parent child} {
    set parent_l [string tolower [file normalize $parent]]
    set child_l [string tolower [file normalize $child]]
    return [expr {[string first $parent_l $child_l] == 0}]
}

proc safe_rebuild_dir {step14_dir target_dir required_tail} {
    set norm_target [file normalize $target_dir]
    if {![path_inside $step14_dir $norm_target] || [file tail $norm_target] ne $required_tail} {
        error "Refusing to delete unsafe package directory: $norm_target"
    }
    if {[file exists $norm_target]} {
        file delete -force $norm_target
    }
    file mkdir $norm_target
}

proc sha256_file {path} {
    set native [file nativename [file normalize $path]]
    if {[catch {
        exec powershell -NoProfile -ExecutionPolicy Bypass -Command "((Get-FileHash -Algorithm SHA256 -LiteralPath '$native').Hash).ToLower()"
    } hash]} {
        return "sha256_unavailable"
    }
    return [string trim $hash]
}

proc copy_and_record {repo_root source_path packaged_path role commit manifest_var package_manifest_var} {
    upvar $manifest_var manifest
    upvar $package_manifest_var package_manifest
    set dst_dir [file dirname $packaged_path]
    file mkdir $dst_dir
    file copy -force $source_path $packaged_path
    set src_rel [rel_to $repo_root $source_path]
    set pkg_rel [rel_to [file dirname [file dirname $packaged_path]] $packaged_path]
    set sha [sha256_file $source_path]
    lappend manifest [list $src_rel $pkg_rel $role $commit $sha]
    lappend package_manifest [list $pkg_rel $role $sha]
}

proc write_source_manifest {path rows} {
    set fh [open $path "w"]
    puts $fh "source_path,packaged_path,role,source_git_commit,sha256"
    foreach row $rows {
        puts $fh "[lindex $row 0],[lindex $row 1],[lindex $row 2],[lindex $row 3],[lindex $row 4]"
    }
    close $fh
}

proc write_package_manifest {path rows} {
    set fh [open $path "w"]
    puts $fh "packaged_path,role,sha256"
    foreach row $rows {
        puts $fh "[lindex $row 0],[lindex $row 1],[lindex $row 2]"
    }
    close $fh
}

proc add_bus_param {busif name value} {
    if {[catch {ipx::add_bus_parameter $name $busif}]} {}
    set param [ipx::get_bus_parameters $name -of_objects $busif]
    set_property value $value $param
}

proc get_or_rename_bus_if {core target candidates} {
    set busif [ipx::get_bus_interfaces $target -of_objects $core -quiet]
    if {[llength $busif] > 0} {
        return $busif
    }
    foreach cand $candidates {
        set busif [ipx::get_bus_interfaces $cand -of_objects $core -quiet]
        if {[llength $busif] > 0} {
            set_property name $target $busif
            return [ipx::get_bus_interfaces $target -of_objects $core]
        }
    }
    ipx::add_bus_interface $target $core
    return [ipx::get_bus_interfaces $target -of_objects $core]
}

proc ensure_port_map {busif logical physical} {
    set existing [ipx::get_port_maps -of_objects $busif -quiet]
    foreach pm $existing {
        if {[get_property logical_name $pm] eq $logical} {
            set_property physical_name $physical $pm
            return
        }
    }
    set pm [ipx::add_port_map $logical $busif]
    set_property physical_name $physical $pm
}

proc create_axis_if {core name mode width_bytes maps} {
    set busif [get_or_rename_bus_if $core $name [list [string tolower $name] [string map {"S_AXIS_Y" "s_axis_y" "M_AXIS_Z" "m_axis_z"} $name]]]
    set_property bus_type_vlnv xilinx.com:interface:axis:1.0 $busif
    set_property abstraction_type_vlnv xilinx.com:interface:axis_rtl:1.0 $busif
    set_property interface_mode $mode $busif
    foreach item $maps {
        ensure_port_map $busif [lindex $item 0] [lindex $item 1]
    }
    add_bus_param $busif TDATA_NUM_BYTES $width_bytes
    add_bus_param $busif HAS_TKEEP 1
    add_bus_param $busif HAS_TLAST 1
    add_bus_param $busif HAS_TREADY 1
}

proc create_clock_if {core} {
    set busif [get_or_rename_bus_if $core ACLK [list aclk]]
    set_property bus_type_vlnv xilinx.com:signal:clock:1.0 $busif
    set_property abstraction_type_vlnv xilinx.com:signal:clock_rtl:1.0 $busif
    set_property interface_mode slave $busif
    ensure_port_map $busif CLK aclk
    add_bus_param $busif ASSOCIATED_BUSIF "S_AXIS_Y:M_AXIS_Z"
    add_bus_param $busif ASSOCIATED_RESET "ARESETN"
    add_bus_param $busif FREQ_HZ 200000000
}

proc create_reset_if {core} {
    set busif [get_or_rename_bus_if $core ARESETN [list aresetn]]
    set_property bus_type_vlnv xilinx.com:signal:reset:1.0 $busif
    set_property abstraction_type_vlnv xilinx.com:signal:reset_rtl:1.0 $busif
    set_property interface_mode slave $busif
    ensure_port_map $busif RST aresetn
    add_bus_param $busif POLARITY ACTIVE_LOW
}

proc count_matches {text pattern} {
    return [regexp -all -nocase $pattern $text]
}

proc scan_absolute_paths {paths repo_root} {
    set bad 0
    set repo_native [string map {"\\" "\\\\"} [file nativename [file normalize $repo_root]]]
    set drive_colon_pattern {(^|[^A-Za-z])([A-Za-z]:[\\/])}
    set unix_abs_patterns [list [format "/%s/" home] [format "/%s/" mnt]]
    foreach path $paths {
        if {![file exists $path]} { continue }
        set fh [open $path "r"]
        set data [read $fh]
        close $fh
        if {[regexp $drive_colon_pattern $data] || [string first [lindex $unix_abs_patterns 0] $data] >= 0 || [string first [lindex $unix_abs_patterns 1] $data] >= 0 || [string first $repo_native $data] >= 0} {
            set bad 1
        }
    }
    return [expr {!$bad}]
}

if {[info exists ::env(STEP14_FPGA_PART)] && $::env(STEP14_FPGA_PART) ne ""} {
    set fpga_part $::env(STEP14_FPGA_PART)
    set fpga_part_source "environment"
} else {
    set fpga_part "xc7z020clg400-1"
    set fpga_part_source "reference_default"
    set reference_device_only "true"
}

set vivado_version [version -short]
set part_ok [expr {[llength [get_parts -quiet $fpga_part]] == 1}]
if {!$part_ok} {
    set blocker_if_any "requested_fpga_part_not_found"
    write_pairs [file join $result_dir "step14_2_ip_package_summary.csv"] [list \
        [list vivado_version $vivado_version] \
        [list fpga_part $fpga_part] \
        [list fpga_part_source $fpga_part_source] \
        [list reference_device_only $reference_device_only] \
        [list ip_vlnv $ip_vlnv] \
        [list component_xml_created false] \
        [list ip_package_integrity_pass_flag false] \
        [list integrity_error_count 1] \
        [list integrity_warning_count 0] \
        [list s_axis_y_recognized_flag false] \
        [list m_axis_z_recognized_flag false] \
        [list aclk_recognized_flag false] \
        [list aresetn_recognized_flag false] \
        [list axis_clock_association_pass_flag false] \
        [list reset_polarity_pass_flag false] \
        [list advertised_aclk_Hz 200000000] \
        [list advertised_clock_MHz 200] \
        [list packaged_hdl_file_count 0] \
        [list packaged_w_mem_file_count 0] \
        [list absolute_path_scan_pass_flag false] \
        [list formal_result_claimed false] \
        [list blocker_if_any $blocker_if_any] \
    ]
    error $blocker_if_any
}

safe_rebuild_dir $step14_dir $ip_root "dbf_axis_ip_1_0"
safe_rebuild_dir $step14_dir $work_dir "step14_2a_package"
file mkdir [file join $ip_root "hdl"]
file mkdir [file join $ip_root "data"]
file mkdir [file join $ip_root "xgui"]

set git_commit [string trim [exec git -C $repo_root rev-parse --short HEAD]]
set source_manifest {}
set package_manifest {}

set step13_dir [file normalize [file join $step14_dir ".." "step_13_fpga_soc_dbf_boundary" "rtl"]]
set step14_rtl_dir [file normalize [file join $step14_dir "rtl"]]
set vec_dir [file normalize [file join $step14_dir "results_step14_dbf_ip_soc_integration" "axis_vectors"]]
set split_vec_dir [file normalize [file join $vec_dir "w_split"]]

set step13_files [list]
set step14_files [list \
    dbf_complex_mac_pipe.v \
    dbf_beam_accum_core_pipe.v \
    dbf_z24_quantizer_pipe.v \
    dbf_core_z24_pipe.v \
    dbf_core_z24_bparallel_pipe.v \
    dbf_w_rom18_split.v \
    dbf_w_provider_rom_opt.v \
    dbf_axis_z_serializer.v \
    dbf_axis_datapath_pipe.v \
    dbf_axis_system_top_opt.v \
    dbf_axis_ip_top.v \
]
foreach f $step13_files {
    copy_and_record $repo_root [file join $step13_dir $f] [file join $ip_root "hdl" $f] "step13_arithmetic_rtl" $git_commit source_manifest package_manifest
}
foreach f $step14_files {
    copy_and_record $repo_root [file join $step14_rtl_dir $f] [file join $ip_root "hdl" $f] "step14_axis_rtl" $git_commit source_manifest package_manifest
}
for {set b 0} {$b < 7} {incr b} {
    foreach part {re im} {
        foreach seg {main tail} {
            set f [format "step14_1_w_%s_b%d_%s.mem" $part $b $seg]
            copy_and_record $repo_root [file join $split_vec_dir $f] [file join $ip_root "data" $f] "step14_2a_split_w_rom_mem" $git_commit source_manifest package_manifest
        }
    }
}
write_source_manifest [file join $ip_root "source_manifest.csv"] $source_manifest
write_package_manifest [file join $ip_root "package_manifest.csv"] $package_manifest

set hdl_files [glob -nocomplain [file join $ip_root "hdl" "*.v"]]
set mem_files [glob -nocomplain [file join $ip_root "data" "*.mem"]]

create_project step14_2a_package $work_dir -part $fpga_part -force
add_files -norecurse $hdl_files
add_files -norecurse $mem_files
set_property file_type {Memory Initialization Files} [get_files *.mem]
set_property top dbf_axis_ip_top [current_fileset]
update_compile_order -fileset sources_1

ipx::package_project -root_dir $ip_root -vendor user.org -library radar -taxonomy /UserIP -import_files -set_current true
set core [ipx::current_core]
set_property name dbf_axis $core
set_property version 1.0 $core
set_property display_name {Step14 DBF AXI Stream} $core
set_property description {B7 fixed-point DBF AXI4-Stream IP using Step13 W18/Y16/ACC48/Z24 arithmetic} $core
set_property taxonomy {/UserIP} $core
set_property supported_families {{zynq} {Production} {artix7} {Production} {kintex7} {Production} {virtex7} {Production}} $core

create_axis_if $core S_AXIS_Y slave 4 [list \
    [list TDATA s_axis_y_tdata] \
    [list TKEEP s_axis_y_tkeep] \
    [list TVALID s_axis_y_tvalid] \
    [list TREADY s_axis_y_tready] \
    [list TLAST s_axis_y_tlast] \
]
create_axis_if $core M_AXIS_Z master 8 [list \
    [list TDATA m_axis_z_tdata] \
    [list TKEEP m_axis_z_tkeep] \
    [list TVALID m_axis_z_tvalid] \
    [list TREADY m_axis_z_tready] \
    [list TLAST m_axis_z_tlast] \
]
create_clock_if $core
create_reset_if $core

set integrity_text ""
set integrity_error_count 0
set integrity_warning_count 0
if {[catch {ipx::check_integrity $core} integrity_text]} {
    set integrity_error_count 1
}
append integrity_text "\n"
set integrity_error_count [expr {$integrity_error_count + [count_matches $integrity_text {(^|\n).*(ERROR|CRITICAL).*}]}]
set integrity_warning_count [count_matches $integrity_text {(^|\n).*WARNING.*}]
set ip_package_integrity_pass_flag [expr {$integrity_error_count == 0}]

catch {ipx::create_xgui_files $core}
ipx::save_core $core

set component_xml [file join $ip_root "component.xml"]
set component_xml_created [file exists $component_xml]

set s_axis_y_recognized_flag [expr {[llength [ipx::get_bus_interfaces S_AXIS_Y -of_objects $core -quiet]] == 1}]
set m_axis_z_recognized_flag [expr {[llength [ipx::get_bus_interfaces M_AXIS_Z -of_objects $core -quiet]] == 1}]
set aclk_recognized_flag [expr {[llength [ipx::get_bus_interfaces ACLK -of_objects $core -quiet]] == 1}]
set aresetn_recognized_flag [expr {[llength [ipx::get_bus_interfaces ARESETN -of_objects $core -quiet]] == 1}]
set axis_clock_association_pass_flag false
if {$aclk_recognized_flag} {
    set clk_if [ipx::get_bus_interfaces ACLK -of_objects $core]
    set assoc_bus [get_property value [ipx::get_bus_parameters ASSOCIATED_BUSIF -of_objects $clk_if]]
    set assoc_reset [get_property value [ipx::get_bus_parameters ASSOCIATED_RESET -of_objects $clk_if]]
    set axis_clock_association_pass_flag [expr {$assoc_bus eq "S_AXIS_Y:M_AXIS_Z" && $assoc_reset eq "ARESETN"}]
}
set reset_polarity_pass_flag false
if {$aresetn_recognized_flag} {
    set rst_if [ipx::get_bus_interfaces ARESETN -of_objects $core]
    set polarity [get_property value [ipx::get_bus_parameters POLARITY -of_objects $rst_if]]
    set reset_polarity_pass_flag [expr {$polarity eq "ACTIVE_LOW"}]
}

set scan_files [list $component_xml [file join $ip_root "source_manifest.csv"] [file join $ip_root "package_manifest.csv"]]
foreach f [glob -nocomplain [file join $ip_root "xgui" "*.tcl"]] {
    lappend scan_files $f
}
set absolute_path_scan_pass_flag [scan_absolute_paths $scan_files $repo_root]
if {!$absolute_path_scan_pass_flag && $blocker_if_any eq ""} {
    set blocker_if_any "absolute_path_found_in_packaged_metadata"
}
if {!$ip_package_integrity_pass_flag && $blocker_if_any eq ""} {
    set blocker_if_any "ip_package_integrity_failed"
}

set package_summary [list \
    [list vivado_version $vivado_version] \
    [list fpga_part $fpga_part] \
    [list fpga_part_source $fpga_part_source] \
    [list reference_device_only $reference_device_only] \
    [list ip_vlnv $ip_vlnv] \
    [list component_xml_created [bool_str $component_xml_created]] \
    [list ip_package_integrity_pass_flag [bool_str $ip_package_integrity_pass_flag]] \
    [list integrity_error_count $integrity_error_count] \
    [list integrity_warning_count $integrity_warning_count] \
    [list s_axis_y_recognized_flag [bool_str $s_axis_y_recognized_flag]] \
    [list m_axis_z_recognized_flag [bool_str $m_axis_z_recognized_flag]] \
    [list aclk_recognized_flag [bool_str $aclk_recognized_flag]] \
    [list aresetn_recognized_flag [bool_str $aresetn_recognized_flag]] \
    [list axis_clock_association_pass_flag [bool_str $axis_clock_association_pass_flag]] \
    [list reset_polarity_pass_flag [bool_str $reset_polarity_pass_flag]] \
    [list advertised_aclk_Hz 200000000] \
    [list advertised_clock_MHz 200] \
    [list packaged_hdl_file_count [llength $hdl_files]] \
    [list packaged_w_mem_file_count [llength $mem_files]] \
    [list absolute_path_scan_pass_flag [bool_str $absolute_path_scan_pass_flag]] \
    [list formal_result_claimed false] \
    [list blocker_if_any $blocker_if_any] \
]
write_pairs [file join $result_dir "step14_2_ip_package_summary.csv"] $package_summary

set if_fh [open [file join $result_dir "step14_2_ip_interface_summary.csv"] "w"]
puts $if_fh "interface,mode,bus_type,abstraction,parameter,value,logical_port,physical_port"
foreach if_name {S_AXIS_Y M_AXIS_Z ACLK ARESETN} {
    set busif [ipx::get_bus_interfaces $if_name -of_objects $core -quiet]
    if {[llength $busif] == 0} { continue }
    set mode [get_property interface_mode $busif]
    set bus_type [get_property bus_type_vlnv $busif]
    set abstraction [get_property abstraction_type_vlnv $busif]
    foreach pm [ipx::get_port_maps -of_objects $busif] {
        puts $if_fh "$if_name,$mode,$bus_type,$abstraction,,, [get_property logical_name $pm],[get_property physical_name $pm]"
    }
    foreach param [ipx::get_bus_parameters -of_objects $busif] {
        puts $if_fh "$if_name,$mode,$bus_type,$abstraction,[get_property name $param],[get_property value $param],,"
    }
}
close $if_fh

set mf_fh [open [file join $result_dir "step14_2_ip_file_manifest.csv"] "w"]
puts $mf_fh "packaged_path,role,sha256"
foreach row $package_manifest {
    puts $mf_fh "[lindex $row 0],[lindex $row 1],[lindex $row 2]"
}
close $mf_fh

close_project

if {!$ip_package_integrity_pass_flag || !$absolute_path_scan_pass_flag || !$component_xml_created} {
    error "Step14.2 package failed: $blocker_if_any"
}
