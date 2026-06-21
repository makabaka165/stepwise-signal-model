set bd_name "dbf_reference_bd"
set ip_vlnv "user.org:radar:dbf_axis:1.0"

proc bd_fail {msg} {
    error "Step14.3a reference BD create failed: $msg"
}

proc set_cfg_if_exists {cell prop value} {
    set full_prop "CONFIG.$prop"
    if {[llength [list_property $cell $full_prop]] > 0} {
        set_property $full_prop $value $cell
        return 1
    }
    return 0
}

proc set_bd_prop_if_exists {obj prop value} {
    if {[llength [list_property $obj $prop]] > 0} {
        set_property $prop $value $obj
        return [get_property $prop $obj]
    }
    return "unavailable"
}

proc connect_pin_if_exists {net pin_path} {
    set pin [get_bd_pins -quiet $pin_path]
    if {[llength $pin] == 1} {
        connect_bd_net $net $pin
        return 1
    }
    return 0
}

proc make_scalar_out {name source_pin} {
    set port [create_bd_port -dir O $name]
    connect_bd_net [get_bd_pins $source_pin] $port
}

if {[llength [get_bd_designs -quiet $bd_name]] > 0} {
    current_bd_design $bd_name
    close_bd_design [current_bd_design]
}

create_bd_design $bd_name
current_bd_design $bd_name

if {[info exists ::STEP14_REFBD_CLOCK_HZ]} {
    set aclk [create_bd_port -dir I -type clk -freq_hz $::STEP14_REFBD_CLOCK_HZ aclk]
} else {
    set aclk [create_bd_port -dir I -type clk -freq_hz 200000000 aclk]
}
if {[info exists ::STEP14_REFBD_CLOCK_HZ]} {
    set_property CONFIG.FREQ_HZ $::STEP14_REFBD_CLOCK_HZ $aclk
} else {
    set_property CONFIG.FREQ_HZ 200000000 $aclk
}
set aresetn [create_bd_port -dir I -type rst aresetn]
set_property CONFIG.POLARITY ACTIVE_LOW $aresetn

set axis_in_fifo_0 [create_bd_cell -type ip -vlnv xilinx.com:ip:axis_data_fifo:2.0 axis_in_fifo_0]
set dbf_axis_0 [create_bd_cell -type ip -vlnv $ip_vlnv dbf_axis_0]
set axis_out_fifo_0 [create_bd_cell -type ip -vlnv xilinx.com:ip:axis_data_fifo:2.0 axis_out_fifo_0]

foreach {cell bytes depth} [list $axis_in_fifo_0 4 64 $axis_out_fifo_0 8 16] {
    set_cfg_if_exists $cell TDATA_NUM_BYTES $bytes
    set_cfg_if_exists $cell FIFO_DEPTH $depth
    set_cfg_if_exists $cell HAS_TKEEP 1
    set_cfg_if_exists $cell HAS_TLAST 1
    set_cfg_if_exists $cell IS_ACLK_ASYNC 0
}

connect_bd_net $aclk [get_bd_pins dbf_axis_0/aclk]
connect_bd_net $aresetn [get_bd_pins dbf_axis_0/aresetn]

foreach cell {axis_in_fifo_0 axis_out_fifo_0} {
    connect_pin_if_exists $aclk "$cell/s_axis_aclk"
    connect_pin_if_exists $aclk "$cell/m_axis_aclk"
    connect_pin_if_exists $aresetn "$cell/s_axis_aresetn"
    connect_pin_if_exists $aresetn "$cell/m_axis_aresetn"
    connect_pin_if_exists $aresetn "$cell/axis_aresetn"
}

connect_bd_intf_net [get_bd_intf_pins axis_in_fifo_0/M_AXIS] [get_bd_intf_pins dbf_axis_0/S_AXIS_Y]
connect_bd_intf_net [get_bd_intf_pins dbf_axis_0/M_AXIS_Z] [get_bd_intf_pins axis_out_fifo_0/S_AXIS]

set s_axis_y [create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:axis_rtl:1.0 S_AXIS_Y]
set_property CONFIG.TDATA_NUM_BYTES 4 $s_axis_y
set_property CONFIG.HAS_TKEEP 1 $s_axis_y
set_property CONFIG.HAS_TLAST 1 $s_axis_y
connect_bd_intf_net $s_axis_y [get_bd_intf_pins axis_in_fifo_0/S_AXIS]

set m_axis_z [create_bd_intf_port -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 M_AXIS_Z]
set_property CONFIG.TDATA_NUM_BYTES 8 $m_axis_z
set_property CONFIG.HAS_TKEEP 1 $m_axis_z
set_property CONFIG.HAS_TLAST 1 $m_axis_z
connect_bd_intf_net [get_bd_intf_pins axis_out_fifo_0/M_AXIS] $m_axis_z

set ::STEP14_REFBD_EXTERNAL_CLOCK_ASSOCIATED_BUSIF [set_bd_prop_if_exists $aclk CONFIG.ASSOCIATED_BUSIF S_AXIS_Y:M_AXIS_Z]
set ::STEP14_REFBD_EXTERNAL_CLOCK_ASSOCIATED_RESET [set_bd_prop_if_exists $aclk CONFIG.ASSOCIATED_RESET aresetn]
if {[info exists ::STEP14_REFBD_CLOCK_HZ]} {
    set ::STEP14_REFBD_EXTERNAL_CLOCK_FREQ_HZ [set_bd_prop_if_exists $aclk CONFIG.FREQ_HZ $::STEP14_REFBD_CLOCK_HZ]
} else {
    set ::STEP14_REFBD_EXTERNAL_CLOCK_FREQ_HZ [set_bd_prop_if_exists $aclk CONFIG.FREQ_HZ 200000000]
}
set ::STEP14_REFBD_EXTERNAL_CLOCK_ASSOCIATION_PASS [expr {$::STEP14_REFBD_EXTERNAL_CLOCK_ASSOCIATED_BUSIF eq "S_AXIS_Y:M_AXIS_Z" && $::STEP14_REFBD_EXTERNAL_CLOCK_ASSOCIATED_RESET eq "aresetn"}]

make_scalar_out dbf_status_busy dbf_axis_0/status_busy
make_scalar_out dbf_status_frame_count dbf_axis_0/status_frame_count
make_scalar_out dbf_status_protocol_error dbf_axis_0/status_protocol_error
make_scalar_out dbf_status_early_tlast dbf_axis_0/status_early_tlast
make_scalar_out dbf_status_missing_tlast dbf_axis_0/status_missing_tlast
make_scalar_out dbf_status_bad_tkeep dbf_axis_0/status_bad_tkeep
make_scalar_out dbf_status_clip_seen dbf_axis_0/status_clip_seen
make_scalar_out dbf_status_overflow_seen dbf_axis_0/status_overflow_seen

assign_bd_address
regenerate_bd_layout
validate_bd_design
save_bd_design

set allowed_cells [lsort {axis_in_fifo_0 axis_out_fifo_0 dbf_axis_0}]
set actual_cells {}
foreach cell [get_bd_cells -quiet] {
    lappend actual_cells [get_property NAME $cell]
}
set actual_cells [lsort $actual_cells]
if {$actual_cells ne $allowed_cells} {
    bd_fail "unexpected cells: $actual_cells"
}
