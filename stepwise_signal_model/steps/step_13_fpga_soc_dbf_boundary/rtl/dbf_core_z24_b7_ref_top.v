`timescale 1ns/1ps

`include "step13_4_shift_params.vh"

module dbf_core_z24_b7_ref_top (
    input  wire                         clk,
    input  wire                         rst,
    input  wire                         in_valid,
    input  wire                         in_last,
    input  wire signed [7*18-1:0]       w_re_bus,
    input  wire signed [7*18-1:0]       w_im_bus,
    input  wire signed [15:0]           y_re,
    input  wire signed [15:0]           y_im,
    output wire                         out_valid,
    output wire [6:0]                   lane_out_valid,
    output wire signed [7*48-1:0]       acc_re_bus,
    output wire signed [7*48-1:0]       acc_im_bus,
    output wire signed [7*24-1:0]       z_re_bus,
    output wire signed [7*24-1:0]       z_im_bus,
    output wire [6:0]                   clip_re_bus,
    output wire [6:0]                   clip_im_bus,
    output wire [6:0]                   overflow_re_bus,
    output wire [6:0]                   overflow_im_bus
);

    dbf_core_z24_bparallel #(
        .B_BEAMS(7),
        .W_BITS(18),
        .Y_BITS(16),
        .ACC_BITS(48),
        .Z_BITS(24),
        .SHIFT_BITS(`STEP13_4_ENGINEERING_Z_SHIFT_BITS)
    ) u_top (
        .clk(clk),
        .rst(rst),
        .in_valid(in_valid),
        .in_last(in_last),
        .w_re_bus(w_re_bus),
        .w_im_bus(w_im_bus),
        .y_re(y_re),
        .y_im(y_im),
        .out_valid(out_valid),
        .lane_out_valid(lane_out_valid),
        .acc_re_bus(acc_re_bus),
        .acc_im_bus(acc_im_bus),
        .z_re_bus(z_re_bus),
        .z_im_bus(z_im_bus),
        .clip_re_bus(clip_re_bus),
        .clip_im_bus(clip_im_bus),
        .overflow_re_bus(overflow_re_bus),
        .overflow_im_bus(overflow_im_bus)
    );

endmodule
