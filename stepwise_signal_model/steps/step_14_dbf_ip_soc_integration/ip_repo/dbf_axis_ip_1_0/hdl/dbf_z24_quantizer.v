`timescale 1ns/1ps

// Shift-based signed output quantizer for Step13 DBF Z samples.
//
// Rounding convention:
//   rounded_abs = (abs(acc_in) + 2^(SHIFT_BITS-1)) >> SHIFT_BITS
//   rounded     = sign(acc_in) ? -rounded_abs : rounded_abs
//
// The output is saturated to signed Z_BITS range. clip_flag and overflow_flag
// are identical in this first DBF datapath prototype.
module dbf_z24_quantizer #(
    parameter integer ACC_BITS = 42,
    parameter integer Z_BITS = 24,
    parameter integer SHIFT_BITS = 18
) (
    input  wire signed [ACC_BITS-1:0] acc_in,
    output reg  signed [Z_BITS-1:0]   z_out,
    output reg                        clip_flag,
    output reg                        overflow_flag
);

    localparam integer WORK_BITS = ACC_BITS + 1;
    localparam integer SHIFT_SAFE = (SHIFT_BITS > 0) ? SHIFT_BITS : 1;

    wire acc_negative;
    wire signed [WORK_BITS-1:0] acc_ext;
    wire [WORK_BITS-1:0] abs_acc;
    wire [WORK_BITS-1:0] round_bias;
    wire [WORK_BITS-1:0] rounded_abs;
    wire signed [WORK_BITS-1:0] rounded_signed;
    wire signed [WORK_BITS-1:0] max_z_ext;
    wire signed [WORK_BITS-1:0] min_z_ext;

    assign acc_negative = acc_in[ACC_BITS-1];
    assign acc_ext = {acc_in[ACC_BITS-1], acc_in};
    assign abs_acc = acc_negative ? $unsigned(-acc_ext) : $unsigned(acc_ext);
    assign round_bias = (SHIFT_BITS == 0) ? {WORK_BITS{1'b0}} :
        ({{(WORK_BITS-1){1'b0}}, 1'b1} << (SHIFT_SAFE - 1));
    assign rounded_abs = (SHIFT_BITS == 0) ? abs_acc : ((abs_acc + round_bias) >> SHIFT_BITS);
    assign rounded_signed = acc_negative ? -$signed(rounded_abs) : $signed(rounded_abs);
    assign max_z_ext = {{(WORK_BITS-Z_BITS){1'b0}}, {1'b0, {(Z_BITS-1){1'b1}}}};
    assign min_z_ext = {{(WORK_BITS-Z_BITS){1'b1}}, {1'b1, {(Z_BITS-1){1'b0}}}};

    always @* begin
        clip_flag = 1'b0;
        overflow_flag = 1'b0;
        if (rounded_signed > max_z_ext) begin
            z_out = {1'b0, {(Z_BITS-1){1'b1}}};
            clip_flag = 1'b1;
            overflow_flag = 1'b1;
        end else if (rounded_signed < min_z_ext) begin
            z_out = {1'b1, {(Z_BITS-1){1'b0}}};
            clip_flag = 1'b1;
            overflow_flag = 1'b1;
        end else begin
            z_out = rounded_signed[Z_BITS-1:0];
        end
    end

endmodule
