`timescale 1ns/1ps

module tb_dbf_reference_bd;

    localparam integer N_ELEMS = 2080;
    localparam integer B_BEAMS = 7;
    localparam integer TOTAL_Y = N_ELEMS * 2;
    localparam integer TOTAL_Z = B_BEAMS * 2;
    localparam integer CASE_B_FRAMES = 4;
    localparam integer CASE_B_Z = CASE_B_FRAMES * B_BEAMS;
    localparam integer TIMEOUT_CYCLES = 5000000;

    reg aclk = 1'b0;
    reg aresetn = 1'b0;

    reg [31:0] S_AXIS_Y_tdata = 32'd0;
    reg [3:0]  S_AXIS_Y_tkeep = 4'hF;
    reg        S_AXIS_Y_tlast = 1'b0;
    wire       S_AXIS_Y_tready;
    reg        S_AXIS_Y_tvalid = 1'b0;

    wire [63:0] M_AXIS_Z_tdata;
    wire [7:0]  M_AXIS_Z_tkeep;
    wire        M_AXIS_Z_tlast;
    reg         M_AXIS_Z_tready = 1'b0;
    wire        M_AXIS_Z_tvalid;

    wire        dbf_status_busy;
    wire [31:0] dbf_status_frame_count;
    wire        dbf_status_protocol_error;
    wire        dbf_status_early_tlast;
    wire        dbf_status_missing_tlast;
    wire        dbf_status_bad_tkeep;
    wire        dbf_status_clip_seen;
    wire        dbf_status_overflow_seen;

    reg [31:0] y_mem [0:TOTAL_Y-1];
    reg [63:0] z_expected_mem [0:TOTAL_Z-1];

    integer case_a_csv;
    integer case_b_csv;
    integer summary_csv;
    integer cycle_count;
    integer timeout_flag;
    integer case_a_actual_rows;
    integer case_b_actual_rows;
    integer tdata_mismatch_count;
    integer tkeep_mismatch_count;
    integer tlast_mismatch_count;
    integer duplicate_count;
    integer missing_count;
    integer beam_order_mismatch_count;
    integer case_a_backpressure_events;
    integer case_a_backpressure_stability_fail_count;
    integer case_a_gap_count;

    integer case_a_normal_frame_pass;
    integer case_a_input_gap_pass;
    integer case_a_output_backpressure_pass;
    integer case_a_backpressure_stability_pass;
    integer case_a_two_frame_pass;
    integer case_a_beam_order_pass;
    integer case_a_status_pass;
    integer case_b_four_frame_pass;
    integer case_b_input_backpressure_propagation_seen;
    integer case_b_fifo_stress_pass;
    integer case_b_beam_order_pass;
    integer reference_bd_tb_pass_flag;

    reg [63:0] stable_data;
    reg [7:0]  stable_keep;
    reg        stable_last;
    reg        stable_valid;

    reg [8*512-1:0] y_mem_path;
    reg [8*512-1:0] z_expected_mem_path;

    always #2.5 aclk = ~aclk;

    dbf_reference_bd_wrapper dut (
        .M_AXIS_Z_tdata(M_AXIS_Z_tdata),
        .M_AXIS_Z_tkeep(M_AXIS_Z_tkeep),
        .M_AXIS_Z_tlast(M_AXIS_Z_tlast),
        .M_AXIS_Z_tready(M_AXIS_Z_tready),
        .M_AXIS_Z_tvalid(M_AXIS_Z_tvalid),
        .S_AXIS_Y_tdata(S_AXIS_Y_tdata),
        .S_AXIS_Y_tkeep(S_AXIS_Y_tkeep),
        .S_AXIS_Y_tlast(S_AXIS_Y_tlast),
        .S_AXIS_Y_tready(S_AXIS_Y_tready),
        .S_AXIS_Y_tvalid(S_AXIS_Y_tvalid),
        .aclk(aclk),
        .aresetn(aresetn),
        .dbf_status_bad_tkeep(dbf_status_bad_tkeep),
        .dbf_status_busy(dbf_status_busy),
        .dbf_status_clip_seen(dbf_status_clip_seen),
        .dbf_status_early_tlast(dbf_status_early_tlast),
        .dbf_status_frame_count(dbf_status_frame_count),
        .dbf_status_missing_tlast(dbf_status_missing_tlast),
        .dbf_status_overflow_seen(dbf_status_overflow_seen),
        .dbf_status_protocol_error(dbf_status_protocol_error)
    );

    initial begin
        if (!$value$plusargs("Y_MEM=%s", y_mem_path)) begin
            y_mem_path = "step14_1_y_axis_tdata.mem";
        end
        if (!$value$plusargs("Z_EXPECTED_MEM=%s", z_expected_mem_path)) begin
            z_expected_mem_path = "step14_1_z_axis_expected.mem";
        end
        $readmemh(y_mem_path, y_mem);
        $readmemh(z_expected_mem_path, z_expected_mem);
    end

    initial begin
        cycle_count = 0;
        forever begin
            @(posedge aclk);
            cycle_count = cycle_count + 1;
            if (cycle_count > TIMEOUT_CYCLES) begin
                timeout_flag = 1;
                write_summary();
                $display("FAIL: Step14.3a reference BD timeout");
                $finish;
            end
        end
    end

    initial begin
        init_flags();
        case_a_csv = $fopen("step14_3a_reference_bd_output.csv", "w");
        case_b_csv = $fopen("step14_3a_reference_bd_stress_output.csv", "w");
        summary_csv = $fopen("step14_3a_reference_bd_tb_summary.csv", "w");
        if (case_a_csv == 0 || case_b_csv == 0 || summary_csv == 0) begin
            $display("FAIL: cannot open Step14.3a reference BD CSV files");
            $finish;
        end
        $fwrite(case_a_csv, "frame_index,beam_id,tdata_hex,z_re,z_im,clip_re,clip_im,overflow_re,overflow_im,tlast\n");
        $fwrite(case_b_csv, "frame_index,beam_id,tdata_hex,z_re,z_im,clip_re,clip_im,overflow_re,overflow_im,tlast\n");

        reset_dut();
        fork
            send_case_a_frames();
            collect_case_a_outputs();
        join
        repeat (8) @(posedge aclk);
        finalize_case_a();

        reset_dut();
        fork
            send_case_b_frames();
            release_case_b_output_after_input_backpressure();
            collect_case_b_outputs();
        join
        repeat (8) @(posedge aclk);
        finalize_case_b();

        reference_bd_tb_pass_flag =
            case_a_normal_frame_pass &&
            case_a_input_gap_pass &&
            case_a_output_backpressure_pass &&
            case_a_backpressure_stability_pass &&
            case_a_two_frame_pass &&
            case_a_beam_order_pass &&
            case_a_status_pass &&
            case_b_four_frame_pass &&
            case_b_input_backpressure_propagation_seen &&
            case_b_fifo_stress_pass &&
            case_b_beam_order_pass &&
            (tdata_mismatch_count == 0) &&
            (tkeep_mismatch_count == 0) &&
            (tlast_mismatch_count == 0) &&
            (duplicate_count == 0) &&
            (missing_count == 0) &&
            (timeout_flag == 0);

        write_summary();
        if (reference_bd_tb_pass_flag) begin
            $display("PASS: Step14.3a reference BD AXIS regression");
        end else begin
            $display("FAIL: Step14.3a reference BD AXIS regression");
        end
        $finish;
    end

    task init_flags;
        begin
            timeout_flag = 0;
            case_a_actual_rows = 0;
            case_b_actual_rows = 0;
            tdata_mismatch_count = 0;
            tkeep_mismatch_count = 0;
            tlast_mismatch_count = 0;
            duplicate_count = 0;
            missing_count = 0;
            beam_order_mismatch_count = 0;
            case_a_backpressure_events = 0;
            case_a_backpressure_stability_fail_count = 0;
            case_a_gap_count = 0;
            case_a_normal_frame_pass = 0;
            case_a_input_gap_pass = 0;
            case_a_output_backpressure_pass = 0;
            case_a_backpressure_stability_pass = 0;
            case_a_two_frame_pass = 0;
            case_a_beam_order_pass = 0;
            case_a_status_pass = 0;
            case_b_four_frame_pass = 0;
            case_b_input_backpressure_propagation_seen = 0;
            case_b_fifo_stress_pass = 0;
            case_b_beam_order_pass = 0;
            reference_bd_tb_pass_flag = 0;
        end
    endtask

    task reset_dut;
        begin
            @(negedge aclk);
            aresetn = 1'b0;
            S_AXIS_Y_tdata = 32'd0;
            S_AXIS_Y_tkeep = 4'hF;
            S_AXIS_Y_tlast = 1'b0;
            S_AXIS_Y_tvalid = 1'b0;
            M_AXIS_Z_tready = 1'b0;
            repeat (16) @(posedge aclk);
            @(negedge aclk);
            aresetn = 1'b1;
            repeat (8) @(posedge aclk);
        end
    endtask

    task send_one_sample;
        input integer source_frame;
        input integer element_index;
        integer mem_index;
        integer accepted;
        begin
            mem_index = source_frame * N_ELEMS + element_index;
            @(negedge aclk);
            S_AXIS_Y_tdata = y_mem[mem_index];
            S_AXIS_Y_tkeep = 4'hF;
            S_AXIS_Y_tlast = (element_index == (N_ELEMS-1));
            S_AXIS_Y_tvalid = 1'b1;
            accepted = 0;
            while (!accepted) begin
                @(posedge aclk);
                if (S_AXIS_Y_tvalid && S_AXIS_Y_tready) begin
                    accepted = 1;
                end
            end
        end
    endtask

    task send_frame;
        input integer source_frame;
        input integer gap_enable;
        integer n;
        integer accepted_count;
        begin
            accepted_count = 0;
            for (n = 0; n < N_ELEMS; n = n + 1) begin
                send_one_sample(source_frame, n);
                accepted_count = accepted_count + 1;
                if (gap_enable && (accepted_count % 257 == 0) && n != (N_ELEMS-1)) begin
                    @(negedge aclk);
                    S_AXIS_Y_tvalid = 1'b0;
                    S_AXIS_Y_tlast = 1'b0;
                    S_AXIS_Y_tkeep = 4'hF;
                    case_a_gap_count = case_a_gap_count + 1;
                    @(posedge aclk);
                end
            end
            @(negedge aclk);
            S_AXIS_Y_tvalid = 1'b0;
            S_AXIS_Y_tlast = 1'b0;
            S_AXIS_Y_tdata = 32'd0;
            S_AXIS_Y_tkeep = 4'hF;
        end
    endtask

    task send_case_a_frames;
        begin
            send_frame(0, 0);
            send_frame(1, 1);
        end
    endtask

    task send_case_b_frames;
        integer f;
        begin
            for (f = 0; f < CASE_B_FRAMES; f = f + 1) begin
                send_frame(f % 2, 0);
            end
        end
    endtask

    task release_case_b_output_after_input_backpressure;
        begin
            M_AXIS_Z_tready = 1'b0;
            while (!case_b_input_backpressure_propagation_seen) begin
                @(posedge aclk);
                if (S_AXIS_Y_tvalid && !S_AXIS_Y_tready) begin
                    case_b_input_backpressure_propagation_seen = 1;
                end
            end
            repeat (16) @(posedge aclk);
            @(negedge aclk);
            M_AXIS_Z_tready = 1'b1;
        end
    endtask

    task collect_case_a_outputs;
        integer row;
        integer frame_index;
        integer beam_id;
        integer expected_index;
        begin
            @(negedge aclk);
            M_AXIS_Z_tready = 1'b1;
            for (row = 0; row < TOTAL_Z; row = row + 1) begin
                wait_for_output_handshake();
                frame_index = row / B_BEAMS;
                beam_id = row % B_BEAMS;
                expected_index = frame_index * B_BEAMS + beam_id;
                check_and_log_output(case_a_csv, frame_index, beam_id, expected_index, 0);
                if (row == 1 || row == 4) begin
                    apply_case_a_output_backpressure();
                end
                if (row == 8 || row == 11) begin
                    apply_case_a_output_backpressure();
                end
            end
        end
    endtask

    task collect_case_b_outputs;
        integer row;
        integer frame_index;
        integer beam_id;
        integer expected_index;
        begin
            for (row = 0; row < CASE_B_Z; row = row + 1) begin
                wait_for_output_handshake();
                frame_index = row / B_BEAMS;
                beam_id = row % B_BEAMS;
                expected_index = (frame_index % 2) * B_BEAMS + beam_id;
                check_and_log_output(case_b_csv, frame_index, beam_id, expected_index, 1);
            end
        end
    endtask

    task wait_for_output_handshake;
        integer got_it;
        begin
            got_it = 0;
            while (!got_it) begin
                @(posedge aclk);
                if (M_AXIS_Z_tvalid && M_AXIS_Z_tready) begin
                    got_it = 1;
                end
            end
        end
    endtask

    task apply_case_a_output_backpressure;
        integer k;
        begin
            @(negedge aclk);
            M_AXIS_Z_tready = 1'b0;
            stable_data = M_AXIS_Z_tdata;
            stable_keep = M_AXIS_Z_tkeep;
            stable_last = M_AXIS_Z_tlast;
            stable_valid = M_AXIS_Z_tvalid;
            case_a_backpressure_events = case_a_backpressure_events + 1;
            for (k = 0; k < 3; k = k + 1) begin
                @(posedge aclk);
                if (M_AXIS_Z_tvalid !== stable_valid ||
                        M_AXIS_Z_tdata !== stable_data ||
                        M_AXIS_Z_tkeep !== stable_keep ||
                        M_AXIS_Z_tlast !== stable_last) begin
                    case_a_backpressure_stability_fail_count =
                        case_a_backpressure_stability_fail_count + 1;
                end
            end
            @(negedge aclk);
            M_AXIS_Z_tready = 1'b1;
        end
    endtask

    task check_and_log_output;
        input integer csv;
        input integer frame_index;
        input integer beam_id;
        input integer expected_index;
        input integer is_case_b;
        reg signed [23:0] z_re;
        reg signed [23:0] z_im;
        reg clip_re;
        reg clip_im;
        reg overflow_re;
        reg overflow_im;
        reg [2:0] packed_beam_id;
        begin
            z_re = M_AXIS_Z_tdata[23:0];
            z_im = M_AXIS_Z_tdata[47:24];
            clip_re = M_AXIS_Z_tdata[48];
            clip_im = M_AXIS_Z_tdata[49];
            overflow_re = M_AXIS_Z_tdata[50];
            overflow_im = M_AXIS_Z_tdata[51];
            packed_beam_id = M_AXIS_Z_tdata[54:52];
            if (M_AXIS_Z_tdata !== z_expected_mem[expected_index]) begin
                tdata_mismatch_count = tdata_mismatch_count + 1;
            end
            if (M_AXIS_Z_tkeep !== 8'hFF) begin
                tkeep_mismatch_count = tkeep_mismatch_count + 1;
            end
            if (M_AXIS_Z_tlast !== (beam_id == 6)) begin
                tlast_mismatch_count = tlast_mismatch_count + 1;
            end
            if (packed_beam_id !== beam_id[2:0]) begin
                beam_order_mismatch_count = beam_order_mismatch_count + 1;
            end
            $fwrite(csv, "%0d,%0d,%016h,%0d,%0d,%0d,%0d,%0d,%0d,%0d\n",
                frame_index, beam_id, M_AXIS_Z_tdata, z_re, z_im, clip_re, clip_im,
                overflow_re, overflow_im, M_AXIS_Z_tlast);
            if (is_case_b) begin
                case_b_actual_rows = case_b_actual_rows + 1;
            end else begin
                case_a_actual_rows = case_a_actual_rows + 1;
            end
        end
    endtask

    task finalize_case_a;
        begin
            case_a_normal_frame_pass = (case_a_actual_rows == TOTAL_Z);
            case_a_input_gap_pass = (case_a_gap_count > 0);
            case_a_output_backpressure_pass = (case_a_backpressure_events == 4);
            case_a_backpressure_stability_pass = (case_a_backpressure_stability_fail_count == 0);
            case_a_two_frame_pass = (dbf_status_frame_count == 32'd2);
            case_a_beam_order_pass = (beam_order_mismatch_count == 0);
            case_a_status_pass = !dbf_status_protocol_error && !dbf_status_early_tlast &&
                !dbf_status_missing_tlast && !dbf_status_bad_tkeep &&
                (dbf_status_frame_count == 32'd2);
            if (case_a_actual_rows != TOTAL_Z) begin
                missing_count = missing_count + (TOTAL_Z - case_a_actual_rows);
            end
        end
    endtask

    task finalize_case_b;
        begin
            case_b_four_frame_pass = (dbf_status_frame_count == CASE_B_FRAMES);
            case_b_fifo_stress_pass = (case_b_actual_rows == CASE_B_Z);
            case_b_beam_order_pass = (beam_order_mismatch_count == 0);
            if (case_b_actual_rows != CASE_B_Z) begin
                missing_count = missing_count + (CASE_B_Z - case_b_actual_rows);
            end
        end
    endtask

    task write_metric_bool;
        input [8*128-1:0] name;
        input integer flag;
        begin
            $fwrite(summary_csv, "%0s,%0s\n", name, flag ? "true" : "false");
        end
    endtask

    task write_summary;
        begin
            $fwrite(summary_csv, "metric,value\n");
            write_metric_bool("case_a_normal_frame_pass", case_a_normal_frame_pass);
            write_metric_bool("case_a_input_gap_pass", case_a_input_gap_pass);
            write_metric_bool("case_a_output_backpressure_pass", case_a_output_backpressure_pass);
            write_metric_bool("case_a_backpressure_stability_pass", case_a_backpressure_stability_pass);
            write_metric_bool("case_a_two_frame_pass", case_a_two_frame_pass);
            write_metric_bool("case_a_beam_order_pass", case_a_beam_order_pass);
            write_metric_bool("case_a_status_pass", case_a_status_pass);
            $fwrite(summary_csv, "case_a_expected_rows,14\n");
            $fwrite(summary_csv, "case_a_actual_rows,%0d\n", case_a_actual_rows);
            write_metric_bool("case_b_four_frame_pass", case_b_four_frame_pass);
            write_metric_bool("case_b_input_backpressure_propagation_seen", case_b_input_backpressure_propagation_seen);
            write_metric_bool("case_b_fifo_stress_pass", case_b_fifo_stress_pass);
            write_metric_bool("case_b_beam_order_pass", case_b_beam_order_pass);
            $fwrite(summary_csv, "case_b_expected_rows,28\n");
            $fwrite(summary_csv, "case_b_actual_rows,%0d\n", case_b_actual_rows);
            $fwrite(summary_csv, "tdata_mismatch_count,%0d\n", tdata_mismatch_count);
            $fwrite(summary_csv, "tkeep_mismatch_count,%0d\n", tkeep_mismatch_count);
            $fwrite(summary_csv, "tlast_mismatch_count,%0d\n", tlast_mismatch_count);
            $fwrite(summary_csv, "duplicate_count,%0d\n", duplicate_count);
            $fwrite(summary_csv, "missing_count,%0d\n", missing_count);
            write_metric_bool("timeout_flag", timeout_flag);
            write_metric_bool("reference_bd_tb_pass_flag", reference_bd_tb_pass_flag);
            $fwrite(summary_csv, "formal_result_claimed,false\n");
            $fwrite(summary_csv, "dma_validation_flag,false\n");
            $fwrite(summary_csv, "ps_validation_flag,false\n");
            $fwrite(summary_csv, "board_validation_flag,false\n");
            $fclose(case_a_csv);
            $fclose(case_b_csv);
            $fclose(summary_csv);
        end
    endtask

endmodule
