`timescale 1ns/1ps

module tb_shared_center_column_selector;
    localparam integer NAZ = 192;
    localparam integer Q = 65;
    localparam integer COL_WIDTH = 8;

    reg [COL_WIDTH-1:0] center_col;
    wire [Q*COL_WIDTH-1:0] selected_cols_flat;
    integer errors;

    shared_center_column_selector #(
        .NAZ(NAZ),
        .Q(Q),
        .COL_WIDTH(COL_WIDTH)
    ) dut (
        .center_col(center_col),
        .selected_cols_flat(selected_cols_flat)
    );

    function integer wrap_col;
        input integer value;
        begin
            wrap_col = value;
            while (wrap_col < 0) wrap_col = wrap_col + NAZ;
            while (wrap_col >= NAZ) wrap_col = wrap_col - NAZ;
        end
    endfunction

    function integer get_col;
        input integer idx;
        begin
            get_col = selected_cols_flat[idx*COL_WIDTH +: COL_WIDTH];
        end
    endfunction

    task check_center;
        input integer c;
        integer i;
        integer expected;
        begin
            center_col = c[COL_WIDTH-1:0];
            #1;
            for (i = 0; i < Q; i = i + 1) begin
                expected = wrap_col(c + i - (Q / 2));
                if (get_col(i) !== expected) begin
                    $display("ERROR center=%0d i=%0d got=%0d expected=%0d", c, i, get_col(i), expected);
                    errors = errors + 1;
                end
            end
        end
    endtask

    initial begin
        errors = 0;
        check_center(0);
        check_center(1);
        check_center(96);
        check_center(191);

        if (errors == 0) begin
            $display("PASS tb_shared_center_column_selector");
        end else begin
            $display("FAIL tb_shared_center_column_selector errors=%0d", errors);
            $finish(1);
        end
        $finish;
    end
endmodule
