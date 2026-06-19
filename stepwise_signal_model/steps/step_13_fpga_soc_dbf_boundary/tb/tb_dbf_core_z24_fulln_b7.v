`timescale 1ns/1ps

module tb_dbf_core_z24_fulln_b7;
    `include "step13_4_fulln_vectors.vh"

    reg clk;
    reg rst;
    reg in_valid;
    reg in_last;
    reg signed [STEP13_4_FULLN_B*STEP13_4_FULLN_W_BITS-1:0] w_re_bus;
    reg signed [STEP13_4_FULLN_B*STEP13_4_FULLN_W_BITS-1:0] w_im_bus;
    reg signed [STEP13_4_FULLN_Y_BITS-1:0] y_re;
    reg signed [STEP13_4_FULLN_Y_BITS-1:0] y_im;
    wire out_valid;
    wire [STEP13_4_FULLN_B-1:0] lane_out_valid;
    wire signed [STEP13_4_FULLN_B*STEP13_4_FULLN_ACC_BITS-1:0] acc_re_bus;
    wire signed [STEP13_4_FULLN_B*STEP13_4_FULLN_ACC_BITS-1:0] acc_im_bus;
    wire signed [STEP13_4_FULLN_B*STEP13_4_FULLN_Z_BITS-1:0] z_re_bus;
    wire signed [STEP13_4_FULLN_B*STEP13_4_FULLN_Z_BITS-1:0] z_im_bus;
    wire [STEP13_4_FULLN_B-1:0] clip_re_bus;
    wire [STEP13_4_FULLN_B-1:0] clip_im_bus;
    wire [STEP13_4_FULLN_B-1:0] overflow_re_bus;
    wire [STEP13_4_FULLN_B-1:0] overflow_im_bus;

    reg signed [STEP13_4_FULLN_W_BITS-1:0] w_re_mem [0:STEP13_4_FULLN_N*STEP13_4_FULLN_B-1];
    reg signed [STEP13_4_FULLN_W_BITS-1:0] w_im_mem [0:STEP13_4_FULLN_N*STEP13_4_FULLN_B-1];
    reg signed [STEP13_4_FULLN_Y_BITS-1:0] y_re_mem [0:STEP13_4_FULLN_N*STEP13_4_FULLN_L-1];
    reg signed [STEP13_4_FULLN_Y_BITS-1:0] y_im_mem [0:STEP13_4_FULLN_N*STEP13_4_FULLN_L-1];
    reg signed [STEP13_4_FULLN_ACC_BITS-1:0] exp_acc_re_mem [0:STEP13_4_FULLN_B*STEP13_4_FULLN_L-1];
    reg signed [STEP13_4_FULLN_ACC_BITS-1:0] exp_acc_im_mem [0:STEP13_4_FULLN_B*STEP13_4_FULLN_L-1];
    reg signed [STEP13_4_FULLN_Z_BITS-1:0] exp_z_re_mem [0:STEP13_4_FULLN_B*STEP13_4_FULLN_L-1];
    reg signed [STEP13_4_FULLN_Z_BITS-1:0] exp_z_im_mem [0:STEP13_4_FULLN_B*STEP13_4_FULLN_L-1];
    reg exp_clip_re_mem [0:STEP13_4_FULLN_B*STEP13_4_FULLN_L-1];
    reg exp_clip_im_mem [0:STEP13_4_FULLN_B*STEP13_4_FULLN_L-1];
    reg exp_overflow_re_mem [0:STEP13_4_FULLN_B*STEP13_4_FULLN_L-1];
    reg exp_overflow_im_mem [0:STEP13_4_FULLN_B*STEP13_4_FULLN_L-1];

    integer errors;
    integer timeout_cycles;
    integer csv_fd;
    integer frame_idx;
    integer n;
    integer b;
    integer w_idx;
    integer y_idx;
    integer exp_idx;
    integer unexpected_out_valid_count;
    reg signed [STEP13_4_FULLN_ACC_BITS-1:0] got_acc_re;
    reg signed [STEP13_4_FULLN_ACC_BITS-1:0] got_acc_im;
    reg signed [STEP13_4_FULLN_Z_BITS-1:0] got_z_re;
    reg signed [STEP13_4_FULLN_Z_BITS-1:0] got_z_im;

    dbf_core_z24_bparallel #(
        .B_BEAMS(STEP13_4_FULLN_B),
        .W_BITS(STEP13_4_FULLN_W_BITS),
        .Y_BITS(STEP13_4_FULLN_Y_BITS),
        .ACC_BITS(STEP13_4_FULLN_ACC_BITS),
        .Z_BITS(STEP13_4_FULLN_Z_BITS),
        .SHIFT_BITS(STEP13_4_FULLN_Z_SHIFT_BITS)
    ) dut (
        .clk(clk),
        .rst(rst),
        .in_valid(in_valid),
        .in_last(in_last),
        .w_re_bus(w_re_bus),
        .w_im_bus(w_im_bus),
        .y_re(y_re),
        .y_im(y_im),
        .out_valid(out_valid),
        .lane_out_valid(lane_out_valid),
        .acc_re_bus(acc_re_bus),
        .acc_im_bus(acc_im_bus),
        .z_re_bus(z_re_bus),
        .z_im_bus(z_im_bus),
        .clip_re_bus(clip_re_bus),
        .clip_im_bus(clip_im_bus),
        .overflow_re_bus(overflow_re_bus),
        .overflow_im_bus(overflow_im_bus)
    );

    always #5 clk = ~clk;

    initial begin
        $readmemh(`STEP13_4_FULLN_W_RE_MEM, w_re_mem);
        $readmemh(`STEP13_4_FULLN_W_IM_MEM, w_im_mem);
        $readmemh(`STEP13_4_FULLN_Y_RE_MEM, y_re_mem);
        $readmemh(`STEP13_4_FULLN_Y_IM_MEM, y_im_mem);
        $readmemh(`STEP13_4_FULLN_ACC_RE_MEM, exp_acc_re_mem);
        $readmemh(`STEP13_4_FULLN_ACC_IM_MEM, exp_acc_im_mem);
        $readmemh(`STEP13_4_FULLN_Z_RE_MEM, exp_z_re_mem);
        $readmemh(`STEP13_4_FULLN_Z_IM_MEM, exp_z_im_mem);
        $readmemh(`STEP13_4_FULLN_CLIP_RE_MEM, exp_clip_re_mem);
        $readmemh(`STEP13_4_FULLN_CLIP_IM_MEM, exp_clip_im_mem);
        $readmemh(`STEP13_4_FULLN_OVERFLOW_RE_MEM, exp_overflow_re_mem);
        $readmemh(`STEP13_4_FULLN_OVERFLOW_IM_MEM, exp_overflow_im_mem);
    end

    initial begin
        timeout_cycles = 0;
        forever begin
            @(posedge clk);
            timeout_cycles = timeout_cycles + 1;
            if (timeout_cycles > 200000) begin
                $display("FAIL: tb_dbf_core_z24_fulln_b7 timeout");
                $finish;
            end
        end
    end

    task apply_reset;
        begin
            rst = 1'b1;
            in_valid = 1'b0;
            in_last = 1'b0;
            w_re_bus = {STEP13_4_FULLN_B*STEP13_4_FULLN_W_BITS{1'b0}};
            w_im_bus = {STEP13_4_FULLN_B*STEP13_4_FULLN_W_BITS{1'b0}};
            y_re = {STEP13_4_FULLN_Y_BITS{1'b0}};
            y_im = {STEP13_4_FULLN_Y_BITS{1'b0}};
            repeat (5) @(posedge clk);
            rst = 1'b0;
            @(posedge clk);
            #1;
        end
    endtask

    task drive_element;
        input integer tb_frame;
        input integer tb_n;
        begin
            for (b = 0; b < STEP13_4_FULLN_B; b = b + 1) begin
                w_idx = b * STEP13_4_FULLN_N + tb_n;
                w_re_bus[b*STEP13_4_FULLN_W_BITS +: STEP13_4_FULLN_W_BITS] = w_re_mem[w_idx];
                w_im_bus[b*STEP13_4_FULLN_W_BITS +: STEP13_4_FULLN_W_BITS] = w_im_mem[w_idx];
            end
            y_idx = tb_frame * STEP13_4_FULLN_N + tb_n;
            y_re = y_re_mem[y_idx];
            y_im = y_im_mem[y_idx];
            in_valid = 1'b1;
            in_last = (tb_n == STEP13_4_FULLN_N - 1);
            @(posedge clk);
            #1;
        end
    endtask

    task check_frame;
        input integer tb_frame;
        begin
            if (out_valid !== 1'b1) begin
                $display("FAIL: missing out_valid frame=%0d", tb_frame);
                errors = errors + 1;
            end
            for (b = 0; b < STEP13_4_FULLN_B; b = b + 1) begin
                exp_idx = tb_frame * STEP13_4_FULLN_B + b;
                got_acc_re = acc_re_bus[b*STEP13_4_FULLN_ACC_BITS +: STEP13_4_FULLN_ACC_BITS];
                got_acc_im = acc_im_bus[b*STEP13_4_FULLN_ACC_BITS +: STEP13_4_FULLN_ACC_BITS];
                got_z_re = z_re_bus[b*STEP13_4_FULLN_Z_BITS +: STEP13_4_FULLN_Z_BITS];
                got_z_im = z_im_bus[b*STEP13_4_FULLN_Z_BITS +: STEP13_4_FULLN_Z_BITS];
                $fdisplay(csv_fd, "%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d",
                    tb_frame, b,
                    got_acc_re,
                    got_acc_im,
                    got_z_re,
                    got_z_im,
                    clip_re_bus[b], clip_im_bus[b], overflow_re_bus[b], overflow_im_bus[b]);
                if (lane_out_valid[b] !== 1'b1 ||
                    got_acc_re !== exp_acc_re_mem[exp_idx] ||
                    got_acc_im !== exp_acc_im_mem[exp_idx] ||
                    got_z_re !== exp_z_re_mem[exp_idx] ||
                    got_z_im !== exp_z_im_mem[exp_idx] ||
                    clip_re_bus[b] !== exp_clip_re_mem[exp_idx] ||
                    clip_im_bus[b] !== exp_clip_im_mem[exp_idx] ||
                    overflow_re_bus[b] !== exp_overflow_re_mem[exp_idx] ||
                    overflow_im_bus[b] !== exp_overflow_im_mem[exp_idx]) begin
                    $display("FAIL: frame=%0d beam=%0d mismatch", tb_frame, b);
                    errors = errors + 1;
                end
            end
        end
    endtask

    task run_frame;
        input integer tb_frame;
        input integer use_gaps;
        begin
            n = 0;
            while (n < STEP13_4_FULLN_N) begin
                drive_element(tb_frame, n);
                n = n + 1;
                if (use_gaps && n < STEP13_4_FULLN_N && (n % 257) == 0) begin
                    in_valid = 1'b0;
                    in_last = 1'b0;
                    @(posedge clk);
                    #1;
                    if (out_valid === 1'b1) begin
                        unexpected_out_valid_count = unexpected_out_valid_count + 1;
                    end
                end
            end
            in_valid = 1'b0;
            in_last = 1'b0;
            check_frame(tb_frame);
            @(posedge clk);
            #1;
        end
    endtask

    initial begin
        clk = 1'b0;
        rst = 1'b1;
        in_valid = 1'b0;
        in_last = 1'b0;
        errors = 0;
        unexpected_out_valid_count = 0;

        csv_fd = $fopen("results_step13_fpga_soc_dbf_boundary/rtl_fulln_sim/dbf_core_z24_fulln_output.csv", "w");
        if (csv_fd == 0) begin
            $display("FAIL: cannot open full-N output CSV");
            $finish;
        end
        $fdisplay(csv_fd, "frame_index,b_index,acc_re,acc_im,z_re,z_im,clip_re,clip_im,overflow_re,overflow_im");

        apply_reset();
        run_frame(0, 0);
        apply_reset();
        run_frame(1, 1);

        $fclose(csv_fd);
        if (errors == 0 && unexpected_out_valid_count == 0) begin
            $display("PASS: tb_dbf_core_z24_fulln_b7 N=%0d B=%0d L=%0d SHIFT=%0d",
                STEP13_4_FULLN_N, STEP13_4_FULLN_B, STEP13_4_FULLN_L,
                STEP13_4_FULLN_Z_SHIFT_BITS);
            $finish;
        end
        $display("FAIL: tb_dbf_core_z24_fulln_b7 errors=%0d unexpected_out_valid=%0d",
            errors, unexpected_out_valid_count);
        $finish;
    end
endmodule
