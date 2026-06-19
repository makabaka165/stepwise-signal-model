`timescale 1ns/1ps

module tb_dbf_core_z24;
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
    wire signed [STEP13_GOLDEN_Z_BITS-1:0] z_re;
    wire signed [STEP13_GOLDEN_Z_BITS-1:0] z_im;
    wire clip_re;
    wire clip_im;
    wire overflow_re;
    wire overflow_im;

    integer errors;
    integer timeout_cycles;
    integer csv_fd;
    integer b;
    integer l;
    integer n;
    integer w_idx;
    integer y_idx;
    integer z_idx;

    dbf_core_accum #(
        .W_BITS(STEP13_GOLDEN_W_BITS),
        .Y_BITS(STEP13_GOLDEN_Y_BITS),
        .ACC_BITS(STEP13_GOLDEN_ACC_BITS),
        .B_BEAMS(STEP13_GOLDEN_B)
    ) u_accum (
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

    dbf_z24_quantizer #(
        .ACC_BITS(STEP13_GOLDEN_ACC_BITS),
        .Z_BITS(STEP13_GOLDEN_Z_BITS),
        .SHIFT_BITS(STEP13_GOLDEN_Z_SHIFT_BITS)
    ) u_quant_re (
        .acc_in(acc_re),
        .z_out(z_re),
        .clip_flag(clip_re),
        .overflow_flag(overflow_re)
    );

    dbf_z24_quantizer #(
        .ACC_BITS(STEP13_GOLDEN_ACC_BITS),
        .Z_BITS(STEP13_GOLDEN_Z_BITS),
        .SHIFT_BITS(STEP13_GOLDEN_Z_SHIFT_BITS)
    ) u_quant_im (
        .acc_in(acc_im),
        .z_out(z_im),
        .clip_flag(clip_im),
        .overflow_flag(overflow_im)
    );

    always #5 clk = ~clk;

    initial begin
        timeout_cycles = 0;
        forever begin
            @(posedge clk);
            timeout_cycles = timeout_cycles + 1;
            if (timeout_cycles > 200000) begin
                $display("FAIL: tb_dbf_core_z24 timeout");
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
            z_idx = tb_l * STEP13_GOLDEN_B + tb_b;
            $fdisplay(csv_fd, "%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d",
                tb_b, tb_l, z_re, z_im, clip_re, clip_im, overflow_re, overflow_im);
            if (out_valid !== 1'b1) begin
                $display("FAIL: missing out_valid b=%0d l=%0d", tb_b, tb_l);
                errors = errors + 1;
            end else if (acc_re !== step13_golden_acc_re[z_idx] ||
                         acc_im !== step13_golden_acc_im[z_idx] ||
                         z_re !== step13_golden_z_re[z_idx] ||
                         z_im !== step13_golden_z_im[z_idx] ||
                         clip_re !== step13_golden_clip_re[z_idx] ||
                         clip_im !== step13_golden_clip_im[z_idx] ||
                         overflow_re !== step13_golden_overflow_re[z_idx] ||
                         overflow_im !== step13_golden_overflow_im[z_idx]) begin
                $display("FAIL: z24 mismatch b=%0d l=%0d got_acc=(%0d,%0d) exp_acc=(%0d,%0d) got_z=(%0d,%0d,%0d,%0d,%0d,%0d) exp_z=(%0d,%0d,%0d,%0d,%0d,%0d)",
                    tb_b, tb_l, acc_re, acc_im,
                    step13_golden_acc_re[z_idx], step13_golden_acc_im[z_idx],
                    z_re, z_im, clip_re, clip_im, overflow_re, overflow_im,
                    step13_golden_z_re[z_idx], step13_golden_z_im[z_idx],
                    step13_golden_clip_re[z_idx], step13_golden_clip_im[z_idx],
                    step13_golden_overflow_re[z_idx], step13_golden_overflow_im[z_idx]);
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

        csv_fd = $fopen("results_step13_fpga_soc_dbf_boundary/rtl_sim/dbf_core_z24_output.csv", "w");
        if (csv_fd == 0) begin
            $display("FAIL: cannot open z24 rtl_sim output CSV");
            $finish;
        end
        $fdisplay(csv_fd, "b_index,l_index,z_re,z_im,clip_re,clip_im,overflow_re,overflow_im");

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
            $display("PASS: tb_dbf_core_z24 checked B=%0d L=%0d N=%0d SHIFT=%0d",
                STEP13_GOLDEN_B, STEP13_GOLDEN_L, STEP13_GOLDEN_N,
                STEP13_GOLDEN_Z_SHIFT_BITS);
            $finish;
        end

        $display("FAIL: tb_dbf_core_z24 errors=%0d", errors);
        $finish;
    end
endmodule
