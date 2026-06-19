`timescale 1ns/1ps

// B-lane beam-parallel Step13 DBF reference top.
// Lane 0 is packed in the least-significant bus slice: bus[0 +: WIDTH].
module dbf_core_z24_bparallel #(
    parameter integer B_BEAMS = 7,
    parameter integer W_BITS = 18,
    parameter integer Y_BITS = 16,
    parameter integer ACC_BITS = 48,
    parameter integer Z_BITS = 24,
    parameter integer SHIFT_BITS = 20
) (
    input  wire                              clk,
    input  wire                              rst,
    input  wire                              in_valid,
    input  wire                              in_last,
    input  wire signed [B_BEAMS*W_BITS-1:0] w_re_bus,
    input  wire signed [B_BEAMS*W_BITS-1:0] w_im_bus,
    input  wire signed [Y_BITS-1:0]         y_re,
    input  wire signed [Y_BITS-1:0]         y_im,
    output wire                             out_valid,
    output wire [B_BEAMS-1:0]               lane_out_valid,
    output wire signed [B_BEAMS*ACC_BITS-1:0] acc_re_bus,
    output wire signed [B_BEAMS*ACC_BITS-1:0] acc_im_bus,
    output wire signed [B_BEAMS*Z_BITS-1:0] z_re_bus,
    output wire signed [B_BEAMS*Z_BITS-1:0] z_im_bus,
    output wire [B_BEAMS-1:0]               clip_re_bus,
    output wire [B_BEAMS-1:0]               clip_im_bus,
    output wire [B_BEAMS-1:0]               overflow_re_bus,
    output wire [B_BEAMS-1:0]               overflow_im_bus
);

    genvar lane;
    generate
        for (lane = 0; lane < B_BEAMS; lane = lane + 1) begin : gen_lane
            dbf_core_z24 #(
                .W_BITS(W_BITS),
                .Y_BITS(Y_BITS),
                .ACC_BITS(ACC_BITS),
                .Z_BITS(Z_BITS),
                .SHIFT_BITS(SHIFT_BITS)
            ) u_lane (
                .clk(clk),
                .rst(rst),
                .in_valid(in_valid),
                .in_last(in_last),
                .w_re(w_re_bus[lane*W_BITS +: W_BITS]),
                .w_im(w_im_bus[lane*W_BITS +: W_BITS]),
                .y_re(y_re),
                .y_im(y_im),
                .out_valid(lane_out_valid[lane]),
                .acc_re(acc_re_bus[lane*ACC_BITS +: ACC_BITS]),
                .acc_im(acc_im_bus[lane*ACC_BITS +: ACC_BITS]),
                .z_re(z_re_bus[lane*Z_BITS +: Z_BITS]),
                .z_im(z_im_bus[lane*Z_BITS +: Z_BITS]),
                .clip_re(clip_re_bus[lane]),
                .clip_im(clip_im_bus[lane]),
                .overflow_re(overflow_re_bus[lane]),
                .overflow_im(overflow_im_bus[lane])
            );
        end
    endgenerate

    assign out_valid = &lane_out_valid;

endmodule
