`timescale 1ns/1ps

// Signed complex multiply for conj(W) * Y.
module dbf_complex_mac #(
    parameter integer W_BITS = 18,
    parameter integer Y_BITS = 16,
    parameter integer P_BITS = W_BITS + Y_BITS + 1
) (
    input  signed [W_BITS-1:0] w_re,
    input  signed [W_BITS-1:0] w_im,
    input  signed [Y_BITS-1:0] y_re,
    input  signed [Y_BITS-1:0] y_im,
    output signed [P_BITS-1:0] p_re,
    output signed [P_BITS-1:0] p_im
);

    wire signed [W_BITS+Y_BITS-1:0] wr_yr;
    wire signed [W_BITS+Y_BITS-1:0] wi_yi;
    wire signed [W_BITS+Y_BITS-1:0] wr_yi;
    wire signed [W_BITS+Y_BITS-1:0] wi_yr;

    assign wr_yr = w_re * y_re;
    assign wi_yi = w_im * y_im;
    assign wr_yi = w_re * y_im;
    assign wi_yr = w_im * y_re;

    assign p_re = {{1{wr_yr[W_BITS+Y_BITS-1]}}, wr_yr}
                + {{1{wi_yi[W_BITS+Y_BITS-1]}}, wi_yi};
    assign p_im = {{1{wr_yi[W_BITS+Y_BITS-1]}}, wr_yi}
                - {{1{wi_yr[W_BITS+Y_BITS-1]}}, wi_yr};

endmodule

