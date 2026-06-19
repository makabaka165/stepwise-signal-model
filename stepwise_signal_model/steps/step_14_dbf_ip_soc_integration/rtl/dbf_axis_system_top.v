`timescale 1ns/1ps

// Step14.1 AXIS DBF system top: W provider + AXIS datapath only.
module dbf_axis_system_top #(
    parameter integer N_ELEMS = 2080,
    parameter integer B_BEAMS = 7,
    parameter integer W_BITS = 18,
    parameter integer Y_BITS = 16,
    parameter integer ACC_BITS = 48,
    parameter integer Z_BITS = 24,
    parameter integer SHIFT_BITS = 20,
    parameter integer ADDR_BITS = 12,
    parameter W_RE_B0_FILE = "",
    parameter W_IM_B0_FILE = "",
    parameter W_RE_B1_FILE = "",
    parameter W_IM_B1_FILE = "",
    parameter W_RE_B2_FILE = "",
    parameter W_IM_B2_FILE = "",
    parameter W_RE_B3_FILE = "",
    parameter W_IM_B3_FILE = "",
    parameter W_RE_B4_FILE = "",
    parameter W_IM_B4_FILE = "",
    parameter W_RE_B5_FILE = "",
    parameter W_IM_B5_FILE = "",
    parameter W_RE_B6_FILE = "",
    parameter W_IM_B6_FILE = ""
) (
    input  wire                         aclk,
    input  wire                         aresetn,
    input  wire [31:0]                  s_axis_y_tdata,
    input  wire [3:0]                   s_axis_y_tkeep,
    input  wire                         s_axis_y_tvalid,
    output wire                         s_axis_y_tready,
    input  wire                         s_axis_y_tlast,
    output wire [63:0]                  m_axis_z_tdata,
    output wire [7:0]                   m_axis_z_tkeep,
    output wire                         m_axis_z_tvalid,
    input  wire                         m_axis_z_tready,
    output wire                         m_axis_z_tlast,
    output wire                         status_busy,
    output wire [31:0]                  status_frame_count,
    output wire                         status_protocol_error,
    output wire                         status_early_tlast,
    output wire                         status_missing_tlast,
    output wire                         status_bad_tkeep,
    output wire                         status_clip_seen,
    output wire                         status_overflow_seen,
    output wire [ADDR_BITS-1:0]         debug_element_index,
    output wire [ADDR_BITS-1:0]         debug_w_req_index,
    output wire                         debug_sample_accept
);

    wire w_req_valid;
    wire [ADDR_BITS-1:0] w_req_index;
    wire w_rsp_valid;
    wire signed [B_BEAMS*W_BITS-1:0] w_re_bus;
    wire signed [B_BEAMS*W_BITS-1:0] w_im_bus;

    dbf_w_provider_rom #(
        .N_ELEMS(N_ELEMS),
        .ADDR_BITS(ADDR_BITS),
        .W_BITS(W_BITS),
        .W_RE_B0_FILE(W_RE_B0_FILE),
        .W_IM_B0_FILE(W_IM_B0_FILE),
        .W_RE_B1_FILE(W_RE_B1_FILE),
        .W_IM_B1_FILE(W_IM_B1_FILE),
        .W_RE_B2_FILE(W_RE_B2_FILE),
        .W_IM_B2_FILE(W_IM_B2_FILE),
        .W_RE_B3_FILE(W_RE_B3_FILE),
        .W_IM_B3_FILE(W_IM_B3_FILE),
        .W_RE_B4_FILE(W_RE_B4_FILE),
        .W_IM_B4_FILE(W_IM_B4_FILE),
        .W_RE_B5_FILE(W_RE_B5_FILE),
        .W_IM_B5_FILE(W_IM_B5_FILE),
        .W_RE_B6_FILE(W_RE_B6_FILE),
        .W_IM_B6_FILE(W_IM_B6_FILE)
    ) u_w_provider (
        .clk(aclk),
        .rst(!aresetn),
        .req_valid(w_req_valid),
        .req_index(w_req_index),
        .rsp_valid(w_rsp_valid),
        .w_re_bus(w_re_bus),
        .w_im_bus(w_im_bus)
    );

    dbf_axis_datapath #(
        .N_ELEMS(N_ELEMS),
        .B_BEAMS(B_BEAMS),
        .W_BITS(W_BITS),
        .Y_BITS(Y_BITS),
        .ACC_BITS(ACC_BITS),
        .Z_BITS(Z_BITS),
        .SHIFT_BITS(SHIFT_BITS),
        .ADDR_BITS(ADDR_BITS)
    ) u_datapath (
        .aclk(aclk),
        .aresetn(aresetn),
        .s_axis_y_tdata(s_axis_y_tdata),
        .s_axis_y_tkeep(s_axis_y_tkeep),
        .s_axis_y_tvalid(s_axis_y_tvalid),
        .s_axis_y_tready(s_axis_y_tready),
        .s_axis_y_tlast(s_axis_y_tlast),
        .w_req_valid(w_req_valid),
        .w_req_index(w_req_index),
        .w_rsp_valid(w_rsp_valid),
        .w_re_bus(w_re_bus),
        .w_im_bus(w_im_bus),
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
        .debug_element_index(debug_element_index),
        .debug_w_req_index(debug_w_req_index),
        .debug_sample_accept(debug_sample_accept)
    );

endmodule
