`timescale 1ns/1ps

module tb_dbf_z24_quantizer_pipe_equiv;

    localparam integer ACC_BITS = 48;
    localparam integer Z_BITS = 24;
    localparam integer SHIFT_BITS = 20;
    localparam integer PIPE_LATENCY = 4;
    localparam integer RANDOM_COUNT = 1000;
    localparam integer TIMEOUT_CYCLES = 10000;

    localparam signed [ACC_BITS-1:0] ACC_MAX = {1'b0, {(ACC_BITS-1){1'b1}}};
    localparam signed [ACC_BITS-1:0] ACC_MIN = {1'b1, {(ACC_BITS-1){1'b0}}};
    localparam signed [ACC_BITS-1:0] POS_CLIP_EDGE =
        (48'sd8388608 * 48'sd1048576) - 48'sd524288;
    localparam signed [ACC_BITS-1:0] NEG_CLIP_EDGE =
        -((48'sd8388609 * 48'sd1048576) - 48'sd524288);

    reg clk = 1'b0;
    reg rst = 1'b1;
    reg in_valid = 1'b0;
    reg signed [ACC_BITS-1:0] acc_in = {ACC_BITS{1'b0}};

    wire signed [Z_BITS-1:0] z_ref;
    wire clip_ref;
    wire overflow_ref;
    wire out_valid_pipe;
    wire signed [Z_BITS-1:0] z_pipe;
    wire clip_pipe;
    wire overflow_pipe;

    reg [PIPE_LATENCY:0] exp_valid;
    reg signed [Z_BITS-1:0] exp_z [0:PIPE_LATENCY];
    reg exp_clip [0:PIPE_LATENCY];
    reg exp_overflow [0:PIPE_LATENCY];

    integer summary_csv;
    integer cycle_count;
    integer input_count;
    integer compare_count;
    integer out_valid_mismatch_count;
    integer z_mismatch_count;
    integer clip_mismatch_count;
    integer overflow_mismatch_count;
    integer boundary_case_count;
    integer random_case_count;
    integer valid_gap_count;
    integer timeout_flag;
    integer i;
    integer stage;
    integer rand_idx;
    reg [63:0] prng;

    always #5 clk = ~clk;

    dbf_z24_quantizer #(
        .ACC_BITS(ACC_BITS),
        .Z_BITS(Z_BITS),
        .SHIFT_BITS(SHIFT_BITS)
    ) u_ref (
        .acc_in(acc_in),
        .z_out(z_ref),
        .clip_flag(clip_ref),
        .overflow_flag(overflow_ref)
    );

    dbf_z24_quantizer_pipe #(
        .ACC_BITS(ACC_BITS),
        .Z_BITS(Z_BITS),
        .SHIFT_BITS(SHIFT_BITS)
    ) u_pipe (
        .clk(clk),
        .rst(rst),
        .in_valid(in_valid),
        .acc_in(acc_in),
        .out_valid(out_valid_pipe),
        .z_out(z_pipe),
        .clip_flag(clip_pipe),
        .overflow_flag(overflow_pipe)
    );

    always @(posedge clk) begin
        if (rst) begin
            exp_valid <= {PIPE_LATENCY+1{1'b0}};
        end else begin
            exp_valid[0] <= in_valid;
            exp_z[0] <= z_ref;
            exp_clip[0] <= clip_ref;
            exp_overflow[0] <= overflow_ref;
            for (stage = 1; stage <= PIPE_LATENCY; stage = stage + 1) begin
                exp_valid[stage] <= exp_valid[stage-1];
                exp_z[stage] <= exp_z[stage-1];
                exp_clip[stage] <= exp_clip[stage-1];
                exp_overflow[stage] <= exp_overflow[stage-1];
            end
        end
    end

    always @(negedge clk) begin
        if (!rst) begin
            if (out_valid_pipe !== exp_valid[PIPE_LATENCY]) begin
                out_valid_mismatch_count = out_valid_mismatch_count + 1;
            end
            if (exp_valid[PIPE_LATENCY]) begin
                compare_count = compare_count + 1;
                if (z_pipe !== exp_z[PIPE_LATENCY]) begin
                    z_mismatch_count = z_mismatch_count + 1;
                end
                if (clip_pipe !== exp_clip[PIPE_LATENCY]) begin
                    clip_mismatch_count = clip_mismatch_count + 1;
                end
                if (overflow_pipe !== exp_overflow[PIPE_LATENCY]) begin
                    overflow_mismatch_count = overflow_mismatch_count + 1;
                end
            end
        end
    end

    initial begin
        cycle_count = 0;
        forever begin
            @(posedge clk);
            cycle_count = cycle_count + 1;
            if (cycle_count > TIMEOUT_CYCLES) begin
                timeout_flag = 1;
                write_summary();
                $display("FAIL: quantizer pipe equivalence timeout");
                $finish;
            end
        end
    end

    initial begin
        init_flags();
        summary_csv = $fopen("results_step14_dbf_ip_soc_integration/hardening/step14_2b_quantizer_equiv_summary.csv", "w");
        if (summary_csv == 0) begin
            $display("FAIL: cannot open quantizer equivalence summary");
            $finish;
        end

        repeat (6) @(posedge clk);
        rst = 1'b0;

        drive_valid(48'sd0);
        drive_valid(48'sd1);
        drive_valid(-48'sd1);
        drive_valid(48'sd524287);
        drive_valid(-48'sd524287);
        drive_valid(48'sd524288);
        drive_valid(-48'sd524288);
        drive_valid(48'sd524289);
        drive_valid(-48'sd524289);
        drive_valid(POS_CLIP_EDGE - 48'sd1);
        drive_valid(POS_CLIP_EDGE);
        drive_valid(POS_CLIP_EDGE + 48'sd1);
        drive_valid(NEG_CLIP_EDGE + 48'sd1);
        drive_valid(NEG_CLIP_EDGE);
        drive_valid(NEG_CLIP_EDGE - 48'sd1);
        drive_valid(ACC_MAX);
        drive_valid(ACC_MIN);
        boundary_case_count = input_count;

        drive_gap();
        drive_gap();
        drive_valid(48'sd123456789);
        drive_gap();
        drive_valid(-48'sd987654321);
        drive_valid(48'sd11258999068426);

        prng = 64'h1a2b_3c4d_5566_7788;
        for (rand_idx = 0; rand_idx < RANDOM_COUNT; rand_idx = rand_idx + 1) begin
            prng = (prng * 64'd6364136223846793005) + 64'd1442695040888963407;
            if ((rand_idx % 17) == 0) begin
                drive_gap();
            end
            drive_valid(prng[47:0]);
            random_case_count = random_case_count + 1;
        end

        drive_gap();
        drive_gap();
        drive_gap();
        drive_gap();
        drive_gap();

        write_summary();
        if (quantizer_pipe_equivalence_pass()) begin
            $display("PASS: Step14.2b quantizer pipeline equivalence");
        end else begin
            $display("FAIL: Step14.2b quantizer pipeline equivalence");
        end
        $finish;
    end

    task init_flags;
        begin
            exp_valid = {PIPE_LATENCY+1{1'b0}};
            input_count = 0;
            compare_count = 0;
            out_valid_mismatch_count = 0;
            z_mismatch_count = 0;
            clip_mismatch_count = 0;
            overflow_mismatch_count = 0;
            boundary_case_count = 0;
            random_case_count = 0;
            valid_gap_count = 0;
            timeout_flag = 0;
        end
    endtask

    task drive_valid;
        input signed [ACC_BITS-1:0] value;
        begin
            @(negedge clk);
            acc_in = value;
            in_valid = 1'b1;
            input_count = input_count + 1;
            @(posedge clk);
        end
    endtask

    task drive_gap;
        begin
            @(negedge clk);
            acc_in = {ACC_BITS{1'b0}};
            in_valid = 1'b0;
            valid_gap_count = valid_gap_count + 1;
            @(posedge clk);
        end
    endtask

    function integer quantizer_pipe_equivalence_pass;
        begin
            quantizer_pipe_equivalence_pass =
                (input_count == compare_count) &&
                (out_valid_mismatch_count == 0) &&
                (z_mismatch_count == 0) &&
                (clip_mismatch_count == 0) &&
                (overflow_mismatch_count == 0) &&
                (boundary_case_count >= 17) &&
                (random_case_count == RANDOM_COUNT) &&
                (valid_gap_count > 0) &&
                (timeout_flag == 0);
        end
    endfunction

    task write_metric;
        input [8*96-1:0] name;
        input integer flag;
        begin
            $fwrite(summary_csv, "%0s,%0s\n", name, flag ? "true" : "false");
        end
    endtask

    task write_summary;
        begin
            $fwrite(summary_csv, "metric,value\n");
            $fwrite(summary_csv, "input_count,%0d\n", input_count);
            $fwrite(summary_csv, "compare_count,%0d\n", compare_count);
            $fwrite(summary_csv, "boundary_case_count,%0d\n", boundary_case_count);
            $fwrite(summary_csv, "random_case_count,%0d\n", random_case_count);
            $fwrite(summary_csv, "valid_gap_count,%0d\n", valid_gap_count);
            $fwrite(summary_csv, "out_valid_mismatch_count,%0d\n", out_valid_mismatch_count);
            $fwrite(summary_csv, "z_mismatch_count,%0d\n", z_mismatch_count);
            $fwrite(summary_csv, "clip_mismatch_count,%0d\n", clip_mismatch_count);
            $fwrite(summary_csv, "overflow_mismatch_count,%0d\n", overflow_mismatch_count);
            write_metric("back_to_back_valid_checked", input_count > RANDOM_COUNT);
            write_metric("valid_gaps_checked", valid_gap_count > 0);
            write_metric("deterministic_random_checked", random_case_count == RANDOM_COUNT);
            write_metric("timeout_flag", timeout_flag);
            write_metric("quantizer_pipe_equivalence_pass", quantizer_pipe_equivalence_pass());
            $fwrite(summary_csv, "formal_result_claimed,false\n");
            $fwrite(summary_csv, "dma_validation_flag,false\n");
            $fwrite(summary_csv, "ps_validation_flag,false\n");
            $fwrite(summary_csv, "board_validation_flag,false\n");
            $fclose(summary_csv);
        end
    endtask

endmodule
