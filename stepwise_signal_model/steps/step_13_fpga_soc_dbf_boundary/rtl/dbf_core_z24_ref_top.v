`timescale 1ns/1ps

`include "step13_4_shift_params.vh"

module dbf_core_z24_ref_top (
    input  wire                         clk,
    input  wire                         rst,
    input  wire                         in_valid,
    input  wire                         in_last,
    input  wire signed [17:0]           w_re,
    input  wire signed [17:0]           w_im,
    input  wire signed [15:0]           y_re,
    input  wire signed [15:0]           y_im,
    output wire                         out_valid,
    output wire signed [47:0]           acc_re,
    output wire signed [47:0]           acc_im,
    output wire signed [23:0]           z_re,
    output wire signed [23:0]           z_im,
    output wire                         clip_re,
    output wire                         clip_im,
    output wire                         overflow_re,
    output wire                         overflow_im
);

    dbf_core_z24 #(
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
        .w_re(w_re),
        .w_im(w_im),
        .y_re(y_re),
        .y_im(y_im),
        .out_valid(out_valid),
        .acc_re(acc_re),
        .acc_im(acc_im),
        .z_re(z_re),
        .z_im(z_im),
        .clip_re(clip_re),
        .clip_im(clip_im),
        .overflow_re(overflow_re),
        .overflow_im(overflow_im)
    );

endmodule
