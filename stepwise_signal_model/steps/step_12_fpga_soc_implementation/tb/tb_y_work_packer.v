`timescale 1ns/1ps

module tb_y_work_packer;
    localparam integer NAZ = 8;
    localparam integer NEL = 4;
    localparam integer Q = 3;
    localparam integer COL_WIDTH = 3;
    localparam integer LAYER_WIDTH = 2;
    localparam integer SAMPLE_WIDTH = 16;
    localparam integer LOCAL_COL_WIDTH = 2;

    reg clk;
    reg rst_n;
    reg [Q*COL_WIDTH-1:0] selected_cols_flat;
    reg [COL_WIDTH-1:0] column_index;
    reg [LAYER_WIDTH-1:0] layer_index;
    reg sample_valid;
    reg signed [SAMPLE_WIDTH-1:0] sample_i;
    reg signed [SAMPLE_WIDTH-1:0] sample_q;
    wire [LOCAL_COL_WIDTH-1:0] local_col_index;
    wire [LAYER_WIDTH-1:0] out_layer_index;
    wire signed [SAMPLE_WIDTH-1:0] out_sample_i;
    wire signed [SAMPLE_WIDTH-1:0] out_sample_q;
    wire out_valid;

    integer errors;

    y_work_packer #(
        .NAZ(NAZ),
        .NEL(NEL),
        .Q(Q),
        .COL_WIDTH(COL_WIDTH),
        .LAYER_WIDTH(LAYER_WIDTH),
        .SAMPLE_WIDTH(SAMPLE_WIDTH),
        .LOCAL_COL_WIDTH(LOCAL_COL_WIDTH)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .selected_cols_flat(selected_cols_flat),
        .column_index(column_index),
        .layer_index(layer_index),
        .sample_valid(sample_valid),
        .sample_i(sample_i),
        .sample_q(sample_q),
        .local_col_index(local_col_index),
        .out_layer_index(out_layer_index),
        .out_sample_i(out_sample_i),
        .out_sample_q(out_sample_q),
        .out_valid(out_valid)
    );

    always #5 clk = ~clk;

    task drive_and_check;
        input integer col;
        input integer layer;
        input integer si;
        input integer sq;
        input integer exp_valid;
        input integer exp_local;
        begin
            @(negedge clk);
            column_index = col[COL_WIDTH-1:0];
            layer_index = layer[LAYER_WIDTH-1:0];
            sample_i = si;
            sample_q = sq;
            sample_valid = 1'b1;
            @(posedge clk);
            #1;
            if (out_valid !== exp_valid[0]) begin
                $display("ERROR col=%0d out_valid=%0d expected=%0d", col, out_valid, exp_valid);
                errors = errors + 1;
            end
            if (exp_valid && (local_col_index !== exp_local[LOCAL_COL_WIDTH-1:0] ||
                              out_layer_index !== layer[LAYER_WIDTH-1:0] ||
                              out_sample_i !== si ||
                              out_sample_q !== sq)) begin
                $display("ERROR col=%0d local=%0d expected=%0d", col, local_col_index, exp_local);
                errors = errors + 1;
            end
        end
    endtask

    initial begin
        clk = 1'b0;
        rst_n = 1'b0;
        selected_cols_flat = {3'd5, 3'd3, 3'd1};
        column_index = 0;
        layer_index = 0;
        sample_valid = 0;
        sample_i = 0;
        sample_q = 0;
        errors = 0;

        repeat (2) @(posedge clk);
        rst_n = 1'b1;

        drive_and_check(1, 0, 11, -11, 1, 0);
        drive_and_check(2, 1, 22, -22, 0, 0);
        drive_and_check(3, 2, 33, -33, 1, 1);
        drive_and_check(5, 3, 55, -55, 1, 2);

        @(negedge clk);
        sample_valid = 1'b0;
        @(posedge clk);

        if (errors == 0) begin
            $display("PASS tb_y_work_packer");
        end else begin
            $display("FAIL tb_y_work_packer errors=%0d", errors);
            $finish(1);
        end
        $finish;
    end
endmodule
