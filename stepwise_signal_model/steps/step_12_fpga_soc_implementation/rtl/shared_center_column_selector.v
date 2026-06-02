`timescale 1ns/1ps

module shared_center_column_selector #(
    parameter integer NAZ = 192,
    parameter integer Q = 65,
    parameter integer COL_WIDTH = 8
) (
    input  wire [COL_WIDTH-1:0] center_col,
    output reg  [Q*COL_WIDTH-1:0] selected_cols_flat
);

    integer i;
    integer raw_idx;
    integer wrapped_idx;

    always @* begin
        selected_cols_flat = {Q*COL_WIDTH{1'b0}};
        for (i = 0; i < Q; i = i + 1) begin
            raw_idx = center_col + i - (Q / 2);
            wrapped_idx = raw_idx;
            while (wrapped_idx < 0) begin
                wrapped_idx = wrapped_idx + NAZ;
            end
            while (wrapped_idx >= NAZ) begin
                wrapped_idx = wrapped_idx - NAZ;
            end
            selected_cols_flat[i*COL_WIDTH +: COL_WIDTH] = wrapped_idx[COL_WIDTH-1:0];
        end
    end

endmodule
