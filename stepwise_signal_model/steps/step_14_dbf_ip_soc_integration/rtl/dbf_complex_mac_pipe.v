`timescale 1ns/1ps

// Step14.2a pipelined complex multiply for conj(W) * Y.
module dbf_complex_mac_pipe #(
    parameter integer W_BITS = 18,
    parameter integer Y_BITS = 16,
    parameter integer MUL_BITS = W_BITS + Y_BITS,
    parameter integer P_BITS = W_BITS + Y_BITS + 1
) (
    input  wire                         clk,
    input  wire                         rst,
    input  wire                         in_valid,
    input  wire                         in_last,
    input  wire signed [W_BITS-1:0]     w_re,
    input  wire signed [W_BITS-1:0]     w_im,
    input  wire signed [Y_BITS-1:0]     y_re,
    input  wire signed [Y_BITS-1:0]     y_im,
    output reg                          out_valid,
    output reg                          out_last,
    output reg  signed [P_BITS-1:0]     p_re,
    output reg  signed [P_BITS-1:0]     p_im
);

    reg signed [W_BITS-1:0] w_re_s0;
    reg signed [W_BITS-1:0] w_im_s0;
    reg signed [Y_BITS-1:0] y_re_s0;
    reg signed [Y_BITS-1:0] y_im_s0;
    reg                     valid_s0;
    reg                     last_s0;

    (* use_dsp = "yes" *) reg signed [MUL_BITS-1:0] wr_yr_s1;
    (* use_dsp = "yes" *) reg signed [MUL_BITS-1:0] wi_yi_s1;
    (* use_dsp = "yes" *) reg signed [MUL_BITS-1:0] wr_yi_s1;
    (* use_dsp = "yes" *) reg signed [MUL_BITS-1:0] wi_yr_s1;
    reg                     valid_s1;
    reg                     last_s1;

    wire signed [P_BITS-1:0] wr_yr_ext;
    wire signed [P_BITS-1:0] wi_yi_ext;
    wire signed [P_BITS-1:0] wr_yi_ext;
    wire signed [P_BITS-1:0] wi_yr_ext;

    assign wr_yr_ext = {{(P_BITS-MUL_BITS){wr_yr_s1[MUL_BITS-1]}}, wr_yr_s1};
    assign wi_yi_ext = {{(P_BITS-MUL_BITS){wi_yi_s1[MUL_BITS-1]}}, wi_yi_s1};
    assign wr_yi_ext = {{(P_BITS-MUL_BITS){wr_yi_s1[MUL_BITS-1]}}, wr_yi_s1};
    assign wi_yr_ext = {{(P_BITS-MUL_BITS){wi_yr_s1[MUL_BITS-1]}}, wi_yr_s1};

    always @(posedge clk) begin
        if (rst) begin
            w_re_s0 <= {W_BITS{1'b0}};
            w_im_s0 <= {W_BITS{1'b0}};
            y_re_s0 <= {Y_BITS{1'b0}};
            y_im_s0 <= {Y_BITS{1'b0}};
            valid_s0 <= 1'b0;
            last_s0 <= 1'b0;
            wr_yr_s1 <= {MUL_BITS{1'b0}};
            wi_yi_s1 <= {MUL_BITS{1'b0}};
            wr_yi_s1 <= {MUL_BITS{1'b0}};
            wi_yr_s1 <= {MUL_BITS{1'b0}};
            valid_s1 <= 1'b0;
            last_s1 <= 1'b0;
            p_re <= {P_BITS{1'b0}};
            p_im <= {P_BITS{1'b0}};
            out_valid <= 1'b0;
            out_last <= 1'b0;
        end else begin
            w_re_s0 <= w_re;
            w_im_s0 <= w_im;
            y_re_s0 <= y_re;
            y_im_s0 <= y_im;
            valid_s0 <= in_valid;
            last_s0 <= in_last;

            wr_yr_s1 <= w_re_s0 * y_re_s0;
            wi_yi_s1 <= w_im_s0 * y_im_s0;
            wr_yi_s1 <= w_re_s0 * y_im_s0;
            wi_yr_s1 <= w_im_s0 * y_re_s0;
            valid_s1 <= valid_s0;
            last_s1 <= last_s0;

            p_re <= wr_yr_ext + wi_yi_ext;
            p_im <= wr_yi_ext - wi_yr_ext;
            out_valid <= valid_s1;
            out_last <= last_s1;
        end
    end

endmodule
