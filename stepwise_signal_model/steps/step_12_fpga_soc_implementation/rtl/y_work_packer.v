`timescale 1ns/1ps

module y_work_packer #(
    parameter integer NAZ = 192,
    parameter integer NEL = 32,
    parameter integer Q = 65,
    parameter integer COL_WIDTH = 8,
    parameter integer LAYER_WIDTH = 6,
    parameter integer SAMPLE_WIDTH = 16,
    parameter integer LOCAL_COL_WIDTH = 7
) (
    input  wire clk,
    input  wire rst_n,
    input  wire [Q*COL_WIDTH-1:0] selected_cols_flat,
    input  wire [COL_WIDTH-1:0] column_index,
    input  wire [LAYER_WIDTH-1:0] layer_index,
    input  wire sample_valid,
    input  wire signed [SAMPLE_WIDTH-1:0] sample_i,
    input  wire signed [SAMPLE_WIDTH-1:0] sample_q,
    output reg  [LOCAL_COL_WIDTH-1:0] local_col_index,
    output reg  [LAYER_WIDTH-1:0] out_layer_index,
    output reg  signed [SAMPLE_WIDTH-1:0] out_sample_i,
    output reg  signed [SAMPLE_WIDTH-1:0] out_sample_q,
    output reg  out_valid
);

    integer k;
    reg match_found;
    reg [LOCAL_COL_WIDTH-1:0] match_local_col;
    reg [COL_WIDTH-1:0] selected_col;

    always @* begin
        match_found = 1'b0;
        match_local_col = {LOCAL_COL_WIDTH{1'b0}};
        for (k = 0; k < Q; k = k + 1) begin
            selected_col = selected_cols_flat[k*COL_WIDTH +: COL_WIDTH];
            if (!match_found && column_index == selected_col) begin
                match_found = 1'b1;
                match_local_col = k[LOCAL_COL_WIDTH-1:0];
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            local_col_index <= {LOCAL_COL_WIDTH{1'b0}};
            out_layer_index <= {LAYER_WIDTH{1'b0}};
            out_sample_i <= {SAMPLE_WIDTH{1'b0}};
            out_sample_q <= {SAMPLE_WIDTH{1'b0}};
            out_valid <= 1'b0;
        end else begin
            out_valid <= sample_valid && match_found;
            local_col_index <= match_local_col;
            out_layer_index <= layer_index;
            out_sample_i <= sample_i;
            out_sample_q <= sample_q;
        end
    end

endmodule
