`timescale 1ns/1ps

// Thin wrapper for the first Step13.2 DBF accumulator prototype.
// It reuses one beam accumulator lane; testbench sequences beam/snapshot work.
module dbf_core_accum #(
    parameter integer W_BITS = 18,
    parameter integer Y_BITS = 16,
    parameter integer ACC_BITS = 42,
    parameter integer B_BEAMS = 7
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
    output wire signed [ACC_BITS-1:0]   acc_im
);

    dbf_beam_accum_core #(
        .W_BITS(W_BITS),
        .Y_BITS(Y_BITS),
        .ACC_BITS(ACC_BITS)
    ) u_beam_accum (
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

endmodule

