`timescale 1ns/1ps

// Step14.2a pipelined equivalent of the Step13 Z24 quantizer.
//
// The numeric rule is unchanged:
//   rounded_abs = (abs(acc_in) + 2^(SHIFT_BITS-1)) >> SHIFT_BITS
//   rounded     = sign(acc_in) ? -rounded_abs : rounded_abs
//   z_out       = saturate_to_signed_Z_BITS(rounded)
module dbf_z24_quantizer_pipe #(
    parameter integer ACC_BITS = 48,
    parameter integer Z_BITS = 24,
    parameter integer SHIFT_BITS = 20
) (
    input  wire                         clk,
    input  wire                         rst,
    input  wire                         in_valid,
    input  wire signed [ACC_BITS-1:0]   acc_in,
    output reg                          out_valid,
    output reg  signed [Z_BITS-1:0]     z_out,
    output reg                          clip_flag,
    output reg                          overflow_flag
);

    localparam integer WORK_BITS = ACC_BITS + 1;
    localparam integer SHIFT_SAFE = (SHIFT_BITS > 0) ? SHIFT_BITS : 1;

    localparam [WORK_BITS-1:0] ROUND_BIAS =
        (SHIFT_BITS == 0) ? {WORK_BITS{1'b0}} :
        ({{(WORK_BITS-1){1'b0}}, 1'b1} << (SHIFT_SAFE - 1));
    reg                         valid_s1;
    reg                         valid_s2;
    reg                         valid_s3;
    reg                         valid_s4;
    reg                         sign_s1;
    reg                         sign_s2;
    reg                         sign_s3;
    reg                         sign_s4;
    reg [WORK_BITS-1:0]         abs_s1;
    reg [WORK_BITS-1:0]         rounded_abs_s2;
    reg [Z_BITS-1:0]            abs_lower_s3;
    reg [Z_BITS-1:0]            pos_word_s4;
    reg [Z_BITS-1:0]            neg_word_s4;
    reg                         clip_pos_s3;
    reg                         clip_neg_s3;
    reg                         clip_pos_s4;
    reg                         clip_neg_s4;

    wire signed [WORK_BITS-1:0] acc_ext;
    wire [WORK_BITS-1:0]        abs_next;
    wire [WORK_BITS-1:0]        rounded_abs_next;
    wire                        pos_clip_next;
    wire                        neg_clip_next;
    wire [Z_BITS-1:0]           neg_lower_s3;

    assign acc_ext = {acc_in[ACC_BITS-1], acc_in};
    assign abs_next = acc_in[ACC_BITS-1] ? $unsigned(-acc_ext) : $unsigned(acc_ext);
    assign rounded_abs_next = (SHIFT_BITS == 0) ? abs_s1 : ((abs_s1 + ROUND_BIAS) >> SHIFT_BITS);
    assign pos_clip_next = |rounded_abs_s2[WORK_BITS-1:Z_BITS-1];
    assign neg_clip_next = (|rounded_abs_s2[WORK_BITS-1:Z_BITS]) ||
        (rounded_abs_s2[Z_BITS-1] && (|rounded_abs_s2[Z_BITS-2:0]));
    assign neg_lower_s3 = (~abs_lower_s3) + {{(Z_BITS-1){1'b0}}, 1'b1};

    always @(posedge clk) begin
        if (rst) begin
            valid_s1 <= 1'b0;
            valid_s2 <= 1'b0;
            valid_s3 <= 1'b0;
            valid_s4 <= 1'b0;
            sign_s1 <= 1'b0;
            sign_s2 <= 1'b0;
            sign_s3 <= 1'b0;
            sign_s4 <= 1'b0;
            abs_s1 <= {WORK_BITS{1'b0}};
            rounded_abs_s2 <= {WORK_BITS{1'b0}};
            abs_lower_s3 <= {Z_BITS{1'b0}};
            pos_word_s4 <= {Z_BITS{1'b0}};
            neg_word_s4 <= {Z_BITS{1'b0}};
            clip_pos_s3 <= 1'b0;
            clip_neg_s3 <= 1'b0;
            clip_pos_s4 <= 1'b0;
            clip_neg_s4 <= 1'b0;
            out_valid <= 1'b0;
            z_out <= {Z_BITS{1'b0}};
            clip_flag <= 1'b0;
            overflow_flag <= 1'b0;
        end else begin
            valid_s1 <= in_valid;
            valid_s2 <= valid_s1;
            valid_s3 <= valid_s2;
            valid_s4 <= valid_s3;
            out_valid <= valid_s4;

            if (in_valid) begin
                sign_s1 <= acc_in[ACC_BITS-1];
                abs_s1 <= abs_next;
            end

            if (valid_s1) begin
                sign_s2 <= sign_s1;
                rounded_abs_s2 <= rounded_abs_next;
            end

            if (valid_s2) begin
                sign_s3 <= sign_s2;
                abs_lower_s3 <= rounded_abs_s2[Z_BITS-1:0];
                clip_pos_s3 <= pos_clip_next;
                clip_neg_s3 <= neg_clip_next;
            end

            if (valid_s3) begin
                sign_s4 <= sign_s3;
                pos_word_s4 <= abs_lower_s3;
                neg_word_s4 <= neg_lower_s3;
                clip_pos_s4 <= clip_pos_s3;
                clip_neg_s4 <= clip_neg_s3;
            end

            if (valid_s4) begin
                clip_flag <= 1'b0;
                overflow_flag <= 1'b0;
                if (!sign_s4 && clip_pos_s4) begin
                    z_out <= {1'b0, {(Z_BITS-1){1'b1}}};
                    clip_flag <= 1'b1;
                    overflow_flag <= 1'b1;
                end else if (sign_s4 && clip_neg_s4) begin
                    z_out <= {1'b1, {(Z_BITS-1){1'b0}}};
                    clip_flag <= 1'b1;
                    overflow_flag <= 1'b1;
                end else if (sign_s4) begin
                    z_out <= neg_word_s4;
                end else begin
                    z_out <= pos_word_s4;
                end
            end
        end
    end

endmodule
