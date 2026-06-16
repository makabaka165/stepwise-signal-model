`timescale 1ns/1ps

module tb_dbf_core_accum;
    `include "step13_dbf_rtl_golden_vectors.vh"

    reg clk;
    reg rst;
    reg in_valid;
    reg in_last;
    reg signed [STEP13_GOLDEN_W_BITS-1:0] w_re;
    reg signed [STEP13_GOLDEN_W_BITS-1:0] w_im;
    reg signed [STEP13_GOLDEN_Y_BITS-1:0] y_re;
    reg signed [STEP13_GOLDEN_Y_BITS-1:0] y_im;
    wire out_valid;
    wire signed [STEP13_GOLDEN_ACC_BITS-1:0] acc_re;
    wire signed [STEP13_GOLDEN_ACC_BITS-1:0] acc_im;

    integer errors;
    integer timeout_cycles;
    integer csv_fd;
    integer b;
    integer l;
    integer n;
    integer w_idx;
    integer y_idx;
    integer acc_idx;

    dbf_core_accum #(
        .W_BITS(STEP13_GOLDEN_W_BITS),
        .Y_BITS(STEP13_GOLDEN_Y_BITS),
        .ACC_BITS(STEP13_GOLDEN_ACC_BITS),
        .B_BEAMS(STEP13_GOLDEN_B)
    ) dut (
        .clk(clk),
        .rst(rst),
        .in_valid(in_valid),
        .in_last(in_last),
        .w_re(w_re),
        .w_im(w_im),
        .y_re(y_re),
        .y_im(y_im),
        .out_valid(out_valid),
        .acc_re(acc_re),
        .acc_im(acc_im)
    );

    always #5 clk = ~clk;

    initial begin
        timeout_cycles = 0;
        forever begin
            @(posedge clk);
            timeout_cycles = timeout_cycles + 1;
            if (timeout_cycles > 200000) begin
                $display("FAIL: tb_dbf_core_accum timeout");
                $finish;
            end
        end
    end

    task run_pair;
        input integer tb_b;
        input integer tb_l;
        begin
            for (n = 0; n < STEP13_GOLDEN_N; n = n + 1) begin
                w_idx = tb_b * STEP13_GOLDEN_N + n;
                y_idx = tb_l * STEP13_GOLDEN_N + n;
                w_re = step13_golden_w_re[w_idx];
                w_im = step13_golden_w_im[w_idx];
                y_re = step13_golden_y_re[y_idx];
                y_im = step13_golden_y_im[y_idx];
                in_valid = 1'b1;
                in_last = (n == STEP13_GOLDEN_N - 1);
                @(posedge clk);
                #1;
            end
            in_valid = 1'b0;
            in_last = 1'b0;
            acc_idx = tb_l * STEP13_GOLDEN_B + tb_b;
            $fdisplay(csv_fd, "%0d,%0d,%0d,%0d", tb_b, tb_l, acc_re, acc_im);
            if (out_valid !== 1'b1) begin
                $display("FAIL: missing out_valid b=%0d l=%0d", tb_b, tb_l);
                errors = errors + 1;
            end else if (acc_re !== step13_golden_acc_re[acc_idx] ||
                         acc_im !== step13_golden_acc_im[acc_idx]) begin
                $display("FAIL: mismatch b=%0d l=%0d got=(%0d,%0d) exp=(%0d,%0d)",
                    tb_b, tb_l, acc_re, acc_im,
                    step13_golden_acc_re[acc_idx], step13_golden_acc_im[acc_idx]);
                errors = errors + 1;
            end
            @(posedge clk);
            #1;
        end
    endtask

    initial begin
        clk = 1'b0;
        rst = 1'b1;
        in_valid = 1'b0;
        in_last = 1'b0;
        w_re = {STEP13_GOLDEN_W_BITS{1'b0}};
        w_im = {STEP13_GOLDEN_W_BITS{1'b0}};
        y_re = {STEP13_GOLDEN_Y_BITS{1'b0}};
        y_im = {STEP13_GOLDEN_Y_BITS{1'b0}};
        errors = 0;

        csv_fd = $fopen("results_step13_fpga_soc_dbf_boundary/rtl_sim/dbf_core_accum_output.csv", "w");
        if (csv_fd == 0) begin
            $display("FAIL: cannot open rtl_sim output CSV");
            $finish;
        end
        $fdisplay(csv_fd, "b_index,l_index,acc_re,acc_im");

        repeat (5) @(posedge clk);
        rst = 1'b0;
        @(posedge clk);
        #1;

        for (l = 0; l < STEP13_GOLDEN_L; l = l + 1) begin
            for (b = 0; b < STEP13_GOLDEN_B; b = b + 1) begin
                run_pair(b, l);
            end
        end

        $fclose(csv_fd);

        if (errors == 0) begin
            $display("PASS: tb_dbf_core_accum checked B=%0d L=%0d N=%0d",
                STEP13_GOLDEN_B, STEP13_GOLDEN_L, STEP13_GOLDEN_N);
            $finish;
        end

        $display("FAIL: tb_dbf_core_accum errors=%0d", errors);
        $finish;
    end
endmodule

