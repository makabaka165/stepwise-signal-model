`timescale 1ns/1ps

// Step14.2a one-beam accumulator with a pipelined complex multiply.
module dbf_beam_accum_core_pipe #(
    parameter integer W_BITS = 18,
    parameter integer Y_BITS = 16,
    parameter integer ACC_BITS = 48
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
    output reg signed [ACC_BITS-1:0]    acc_re,
    output reg signed [ACC_BITS-1:0]    acc_im
);

    localparam integer P_BITS = W_BITS + Y_BITS + 1;

    wire                         mac_out_valid;
    wire                         mac_out_last;
    wire signed [P_BITS-1:0]     p_re;
    wire signed [P_BITS-1:0]     p_im;
    reg  signed [ACC_BITS-1:0]   sum_re;
    reg  signed [ACC_BITS-1:0]   sum_im;
    wire signed [ACC_BITS-1:0]   p_re_ext;
    wire signed [ACC_BITS-1:0]   p_im_ext;
    wire signed [ACC_BITS-1:0]   next_sum_re;
    wire signed [ACC_BITS-1:0]   next_sum_im;

    dbf_complex_mac_pipe #(
        .W_BITS(W_BITS),
        .Y_BITS(Y_BITS),
        .MUL_BITS(W_BITS + Y_BITS),
        .P_BITS(P_BITS)
    ) u_mac (
        .clk(clk),
        .rst(rst),
        .in_valid(in_valid),
        .in_last(in_last),
        .w_re(w_re),
        .w_im(w_im),
        .y_re(y_re),
        .y_im(y_im),
        .out_valid(mac_out_valid),
        .out_last(mac_out_last),
        .p_re(p_re),
        .p_im(p_im)
    );

    assign p_re_ext = {{(ACC_BITS-P_BITS){p_re[P_BITS-1]}}, p_re};
    assign p_im_ext = {{(ACC_BITS-P_BITS){p_im[P_BITS-1]}}, p_im};
    assign next_sum_re = sum_re + p_re_ext;
    assign next_sum_im = sum_im + p_im_ext;

    always @(posedge clk) begin
        if (rst) begin
            sum_re <= {ACC_BITS{1'b0}};
            sum_im <= {ACC_BITS{1'b0}};
            acc_re <= {ACC_BITS{1'b0}};
            acc_im <= {ACC_BITS{1'b0}};
            out_valid <= 1'b0;
        end else begin
            out_valid <= 1'b0;
            if (mac_out_valid) begin
                if (mac_out_last) begin
                    acc_re <= next_sum_re;
                    acc_im <= next_sum_im;
                    out_valid <= 1'b1;
                    sum_re <= {ACC_BITS{1'b0}};
                    sum_im <= {ACC_BITS{1'b0}};
                end else begin
                    sum_re <= next_sum_re;
                    sum_im <= next_sum_im;
                end
            end
        end
    end

endmodule
