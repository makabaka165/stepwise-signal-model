`timescale 1ns/1ps

// Step14.2a single-lane DBF core with pipelined MAC and ACC-to-Z quantization.
module dbf_core_z24_pipe #(
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
    output reg                          out_valid,
    output reg signed [ACC_BITS-1:0]    acc_re,
    output reg signed [ACC_BITS-1:0]    acc_im,
    output reg signed [Z_BITS-1:0]      z_re,
    output reg signed [Z_BITS-1:0]      z_im,
    output reg                          clip_re,
    output reg                          clip_im,
    output reg                          overflow_re,
    output reg                          overflow_im
);

    wire                         acc_valid;
    wire signed [ACC_BITS-1:0]   acc_re_wire;
    wire signed [ACC_BITS-1:0]   acc_im_wire;
    reg                          acc_valid_q;
    reg signed [ACC_BITS-1:0]    acc_re_q;
    reg signed [ACC_BITS-1:0]    acc_im_q;
    wire                         q_valid_re;
    wire                         q_valid_im;
    wire signed [Z_BITS-1:0]     z_re_wire;
    wire signed [Z_BITS-1:0]     z_im_wire;
    wire                         clip_re_wire;
    wire                         clip_im_wire;
    wire                         overflow_re_wire;
    wire                         overflow_im_wire;
    reg signed [ACC_BITS-1:0]    acc_re_d0;
    reg signed [ACC_BITS-1:0]    acc_re_d1;
    reg signed [ACC_BITS-1:0]    acc_re_d2;
    reg signed [ACC_BITS-1:0]    acc_re_d3;
    reg signed [ACC_BITS-1:0]    acc_re_d4;
    reg signed [ACC_BITS-1:0]    acc_im_d0;
    reg signed [ACC_BITS-1:0]    acc_im_d1;
    reg signed [ACC_BITS-1:0]    acc_im_d2;
    reg signed [ACC_BITS-1:0]    acc_im_d3;
    reg signed [ACC_BITS-1:0]    acc_im_d4;

    dbf_beam_accum_core_pipe #(
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
        .out_valid(acc_valid),
        .acc_re(acc_re_wire),
        .acc_im(acc_im_wire)
    );

    dbf_z24_quantizer_pipe #(
        .ACC_BITS(ACC_BITS),
        .Z_BITS(Z_BITS),
        .SHIFT_BITS(SHIFT_BITS)
    ) u_quant_re (
        .clk(clk),
        .rst(rst),
        .in_valid(acc_valid_q),
        .acc_in(acc_re_q),
        .out_valid(q_valid_re),
        .z_out(z_re_wire),
        .clip_flag(clip_re_wire),
        .overflow_flag(overflow_re_wire)
    );

    dbf_z24_quantizer_pipe #(
        .ACC_BITS(ACC_BITS),
        .Z_BITS(Z_BITS),
        .SHIFT_BITS(SHIFT_BITS)
    ) u_quant_im (
        .clk(clk),
        .rst(rst),
        .in_valid(acc_valid_q),
        .acc_in(acc_im_q),
        .out_valid(q_valid_im),
        .z_out(z_im_wire),
        .clip_flag(clip_im_wire),
        .overflow_flag(overflow_im_wire)
    );

    always @(posedge clk) begin
        if (rst) begin
            acc_valid_q <= 1'b0;
            acc_re_q <= {ACC_BITS{1'b0}};
            acc_im_q <= {ACC_BITS{1'b0}};
            acc_re_d0 <= {ACC_BITS{1'b0}};
            acc_re_d1 <= {ACC_BITS{1'b0}};
            acc_re_d2 <= {ACC_BITS{1'b0}};
            acc_re_d3 <= {ACC_BITS{1'b0}};
            acc_re_d4 <= {ACC_BITS{1'b0}};
            acc_im_d0 <= {ACC_BITS{1'b0}};
            acc_im_d1 <= {ACC_BITS{1'b0}};
            acc_im_d2 <= {ACC_BITS{1'b0}};
            acc_im_d3 <= {ACC_BITS{1'b0}};
            acc_im_d4 <= {ACC_BITS{1'b0}};
            out_valid <= 1'b0;
            acc_re <= {ACC_BITS{1'b0}};
            acc_im <= {ACC_BITS{1'b0}};
            z_re <= {Z_BITS{1'b0}};
            z_im <= {Z_BITS{1'b0}};
            clip_re <= 1'b0;
            clip_im <= 1'b0;
            overflow_re <= 1'b0;
            overflow_im <= 1'b0;
        end else begin
            if (acc_valid) begin
                acc_re_q <= acc_re_wire;
                acc_im_q <= acc_im_wire;
            end

            acc_valid_q <= acc_valid;
            acc_re_d0 <= acc_re_q;
            acc_re_d1 <= acc_re_d0;
            acc_re_d2 <= acc_re_d1;
            acc_re_d3 <= acc_re_d2;
            acc_re_d4 <= acc_re_d3;
            acc_im_d0 <= acc_im_q;
            acc_im_d1 <= acc_im_d0;
            acc_im_d2 <= acc_im_d1;
            acc_im_d3 <= acc_im_d2;
            acc_im_d4 <= acc_im_d3;

            out_valid <= q_valid_re && q_valid_im;
            if (q_valid_re && q_valid_im) begin
                acc_re <= acc_re_d4;
                acc_im <= acc_im_d4;
                z_re <= z_re_wire;
                z_im <= z_im_wire;
                clip_re <= clip_re_wire;
                clip_im <= clip_im_wire;
                overflow_re <= overflow_re_wire;
                overflow_im <= overflow_im_wire;
            end
        end
    end

endmodule
