`timescale 1ns/1ps

// Single-lane Step13 DBF core: raw accumulator plus signed Z output.
module dbf_core_z24 #(
    parameter integer W_BITS = 18,
    parameter integer Y_BITS = 16,
    parameter integer ACC_BITS = 48,
    parameter integer Z_BITS = 24,
    parameter integer SHIFT_BITS = 20
) (
    input  wire                         clk,
    input  wire                         rst,
    input  wire                         in_valid,
    input  wire                         in_last,
    input  wire signed [W_BITS-1:0]     w_re,
    input  wire signed [W_BITS-1:0]     w_im,
    input  wire signed [Y_BITS-1:0]     y_re,
    input  wire signed [Y_BITS-1:0]     y_im,
    output wire                         out_valid,
    output wire signed [ACC_BITS-1:0]   acc_re,
    output wire signed [ACC_BITS-1:0]   acc_im,
    output wire signed [Z_BITS-1:0]     z_re,
    output wire signed [Z_BITS-1:0]     z_im,
    output wire                         clip_re,
    output wire                         clip_im,
    output wire                         overflow_re,
    output wire                         overflow_im
);

    dbf_beam_accum_core #(
        .W_BITS(W_BITS),
        .Y_BITS(Y_BITS),
        .ACC_BITS(ACC_BITS)
    ) u_accum (
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
        .acc_im(acc_im)
    );

    dbf_z24_quantizer #(
        .ACC_BITS(ACC_BITS),
        .Z_BITS(Z_BITS),
        .SHIFT_BITS(SHIFT_BITS)
    ) u_quant_re (
        .acc_in(acc_re),
        .z_out(z_re),
        .clip_flag(clip_re),
        .overflow_flag(overflow_re)
    );

    dbf_z24_quantizer #(
        .ACC_BITS(ACC_BITS),
        .Z_BITS(Z_BITS),
        .SHIFT_BITS(SHIFT_BITS)
    ) u_quant_im (
        .acc_in(acc_im),
        .z_out(z_im),
        .clip_flag(clip_im),
        .overflow_flag(overflow_im)
    );

endmodule
