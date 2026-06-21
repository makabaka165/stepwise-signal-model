`timescale 1ns/1ps

// Step14.2a packaged IP top.
// This module fixes the Step14 AXIS DBF parameters and split W ROM filenames
// for Vivado IP Packager while using the optimized pipelined implementation.
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

    dbf_axis_system_top_opt #(
        .N_ELEMS(2080),
        .B_BEAMS(7),
        .W_BITS(18),
        .Y_BITS(16),
        .ACC_BITS(48),
        .Z_BITS(24),
        .SHIFT_BITS(20),
        .ADDR_BITS(12),
        .W_RE_B0_MAIN_FILE("step14_1_w_re_b0_main.mem"),
        .W_RE_B0_TAIL_FILE("step14_1_w_re_b0_tail.mem"),
        .W_IM_B0_MAIN_FILE("step14_1_w_im_b0_main.mem"),
        .W_IM_B0_TAIL_FILE("step14_1_w_im_b0_tail.mem"),
        .W_RE_B1_MAIN_FILE("step14_1_w_re_b1_main.mem"),
        .W_RE_B1_TAIL_FILE("step14_1_w_re_b1_tail.mem"),
        .W_IM_B1_MAIN_FILE("step14_1_w_im_b1_main.mem"),
        .W_IM_B1_TAIL_FILE("step14_1_w_im_b1_tail.mem"),
        .W_RE_B2_MAIN_FILE("step14_1_w_re_b2_main.mem"),
        .W_RE_B2_TAIL_FILE("step14_1_w_re_b2_tail.mem"),
        .W_IM_B2_MAIN_FILE("step14_1_w_im_b2_main.mem"),
        .W_IM_B2_TAIL_FILE("step14_1_w_im_b2_tail.mem"),
        .W_RE_B3_MAIN_FILE("step14_1_w_re_b3_main.mem"),
        .W_RE_B3_TAIL_FILE("step14_1_w_re_b3_tail.mem"),
        .W_IM_B3_MAIN_FILE("step14_1_w_im_b3_main.mem"),
        .W_IM_B3_TAIL_FILE("step14_1_w_im_b3_tail.mem"),
        .W_RE_B4_MAIN_FILE("step14_1_w_re_b4_main.mem"),
        .W_RE_B4_TAIL_FILE("step14_1_w_re_b4_tail.mem"),
        .W_IM_B4_MAIN_FILE("step14_1_w_im_b4_main.mem"),
        .W_IM_B4_TAIL_FILE("step14_1_w_im_b4_tail.mem"),
        .W_RE_B5_MAIN_FILE("step14_1_w_re_b5_main.mem"),
        .W_RE_B5_TAIL_FILE("step14_1_w_re_b5_tail.mem"),
        .W_IM_B5_MAIN_FILE("step14_1_w_im_b5_main.mem"),
        .W_IM_B5_TAIL_FILE("step14_1_w_im_b5_tail.mem"),
        .W_RE_B6_MAIN_FILE("step14_1_w_re_b6_main.mem"),
        .W_RE_B6_TAIL_FILE("step14_1_w_re_b6_tail.mem"),
        .W_IM_B6_MAIN_FILE("step14_1_w_im_b6_main.mem"),
        .W_IM_B6_TAIL_FILE("step14_1_w_im_b6_tail.mem")
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
