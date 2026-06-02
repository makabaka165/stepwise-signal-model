`timescale 1ns/1ps

module projection_score_core #(
    parameter integer SAMPLE_WIDTH = 16,
    parameter integer ACC_WIDTH = 48
) (
    input  wire clk,
    input  wire rst_n,
    input  wire clear,
    input  wire sample_valid,
    input  wire signed [SAMPLE_WIDTH-1:0] y_i,
    input  wire signed [SAMPLE_WIDTH-1:0] y_q,
    input  wire signed [SAMPLE_WIDTH-1:0] steering_i,
    input  wire signed [SAMPLE_WIDTH-1:0] steering_q,
    output reg  signed [ACC_WIDTH-1:0] score_i,
    output reg  signed [ACC_WIDTH-1:0] score_q,
    output reg  score_valid
);

    wire signed [2*SAMPLE_WIDTH-1:0] mult_ii = y_i * steering_i;
    wire signed [2*SAMPLE_WIDTH-1:0] mult_qq = y_q * steering_q;
    wire signed [2*SAMPLE_WIDTH-1:0] mult_qi = y_q * steering_i;
    wire signed [2*SAMPLE_WIDTH-1:0] mult_iq = y_i * steering_q;

    wire signed [2*SAMPLE_WIDTH:0] prod_i = mult_ii + mult_qq;
    wire signed [2*SAMPLE_WIDTH:0] prod_q = mult_qi - mult_iq;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            score_i <= {ACC_WIDTH{1'b0}};
            score_q <= {ACC_WIDTH{1'b0}};
            score_valid <= 1'b0;
        end else if (clear) begin
            score_i <= {ACC_WIDTH{1'b0}};
            score_q <= {ACC_WIDTH{1'b0}};
            score_valid <= 1'b0;
        end else begin
            score_valid <= sample_valid;
            if (sample_valid) begin
                score_i <= score_i + prod_i;
                score_q <= score_q + prod_q;
            end
        end
    end

endmodule
