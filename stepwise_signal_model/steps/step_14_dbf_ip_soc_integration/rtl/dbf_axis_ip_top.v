`timescale 1ns/1ps

// Step14.2 packaged IP top.
// This module only fixes the Step14.1 AXIS DBF system parameters and W ROM
// filenames for Vivado IP Packager. It does not alter the datapath behavior.
module dbf_axis_ip_top (
    input  wire        aclk,
    input  wire        aresetn,

    input  wire [31:0] s_axis_y_tdata,
    input  wire [3:0]  s_axis_y_tkeep,
    input  wire        s_axis_y_tvalid,
    output wire        s_axis_y_tready,
    input  wire        s_axis_y_tlast,

    output wire [63:0] m_axis_z_tdata,
    output wire [7:0]  m_axis_z_tkeep,
    output wire        m_axis_z_tvalid,
    input  wire        m_axis_z_tready,
    output wire        m_axis_z_tlast,

    output wire        status_busy,
    output wire [31:0] status_frame_count,
    output wire        status_protocol_error,
    output wire        status_early_tlast,
    output wire        status_missing_tlast,
    output wire        status_bad_tkeep,
    output wire        status_clip_seen,
    output wire        status_overflow_seen
);

    wire [11:0] debug_element_index_unused;
    wire [11:0] debug_w_req_index_unused;
    wire        debug_sample_accept_unused;

    dbf_axis_system_top #(
        .N_ELEMS(2080),
        .B_BEAMS(7),
        .W_BITS(18),
        .Y_BITS(16),
        .ACC_BITS(48),
        .Z_BITS(24),
        .SHIFT_BITS(20),
        .ADDR_BITS(12),
        .W_RE_B0_FILE("step14_1_w_re_b0.mem"),
        .W_IM_B0_FILE("step14_1_w_im_b0.mem"),
        .W_RE_B1_FILE("step14_1_w_re_b1.mem"),
        .W_IM_B1_FILE("step14_1_w_im_b1.mem"),
        .W_RE_B2_FILE("step14_1_w_re_b2.mem"),
        .W_IM_B2_FILE("step14_1_w_im_b2.mem"),
        .W_RE_B3_FILE("step14_1_w_re_b3.mem"),
        .W_IM_B3_FILE("step14_1_w_im_b3.mem"),
        .W_RE_B4_FILE("step14_1_w_re_b4.mem"),
        .W_IM_B4_FILE("step14_1_w_im_b4.mem"),
        .W_RE_B5_FILE("step14_1_w_re_b5.mem"),
        .W_IM_B5_FILE("step14_1_w_im_b5.mem"),
        .W_RE_B6_FILE("step14_1_w_re_b6.mem"),
        .W_IM_B6_FILE("step14_1_w_im_b6.mem")
    ) u_system (
        .aclk(aclk),
        .aresetn(aresetn),
        .s_axis_y_tdata(s_axis_y_tdata),
        .s_axis_y_tkeep(s_axis_y_tkeep),
        .s_axis_y_tvalid(s_axis_y_tvalid),
        .s_axis_y_tready(s_axis_y_tready),
        .s_axis_y_tlast(s_axis_y_tlast),
        .m_axis_z_tdata(m_axis_z_tdata),
        .m_axis_z_tkeep(m_axis_z_tkeep),
        .m_axis_z_tvalid(m_axis_z_tvalid),
        .m_axis_z_tready(m_axis_z_tready),
        .m_axis_z_tlast(m_axis_z_tlast),
        .status_busy(status_busy),
        .status_frame_count(status_frame_count),
        .status_protocol_error(status_protocol_error),
        .status_early_tlast(status_early_tlast),
        .status_missing_tlast(status_missing_tlast),
        .status_bad_tkeep(status_bad_tkeep),
        .status_clip_seen(status_clip_seen),
        .status_overflow_seen(status_overflow_seen),
        .debug_element_index(debug_element_index_unused),
        .debug_w_req_index(debug_w_req_index_unused),
        .debug_sample_accept(debug_sample_accept_unused)
    );

endmodule
