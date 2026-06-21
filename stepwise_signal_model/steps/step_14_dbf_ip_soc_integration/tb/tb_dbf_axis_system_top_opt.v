`timescale 1ns/1ps

module tb_dbf_axis_system_top_opt;

    localparam integer N_ELEMS = 2080;
    localparam integer B_BEAMS = 7;
    localparam integer TOTAL_Y = N_ELEMS * 2;
    localparam integer TOTAL_Z = B_BEAMS * 2;
    localparam integer TIMEOUT_CYCLES = 2000000;

    reg aclk = 1'b0;
    reg aresetn = 1'b0;

    reg [31:0] s_axis_y_tdata = 32'd0;
    reg [3:0]  s_axis_y_tkeep = 4'hF;
    reg        s_axis_y_tvalid = 1'b0;
    wire       s_axis_y_tready;
    reg        s_axis_y_tlast = 1'b0;

    wire [63:0] m_axis_z_tdata;
    wire [7:0]  m_axis_z_tkeep;
    wire        m_axis_z_tvalid;
    reg         m_axis_z_tready = 1'b0;
    wire        m_axis_z_tlast;

    wire        status_busy;
    wire [31:0] status_frame_count;
    wire        status_protocol_error;
    wire        status_early_tlast;
    wire        status_missing_tlast;
    wire        status_bad_tkeep;
    wire        status_clip_seen;
    wire        status_overflow_seen;
    wire [11:0] debug_element_index;
    wire [11:0] debug_w_req_index;
    wire        debug_sample_accept;

    reg [31:0] y_mem [0:TOTAL_Y-1];
    reg [63:0] z_expected_mem [0:TOTAL_Z-1];

    integer output_csv;
    integer summary_csv;
    integer actual_output_rows;
    integer cycle_count;
    integer backpressure_stability_fail_count;
    integer beam_order_fail_count;
    integer expected_mismatch_count;
    integer tkeep_fail_count;
    integer tlast_fail_count;
    integer timeout_flag;
    integer busy_low_after_reset_fail_count;
    integer busy_high_from_first_y_accept_fail_count;
    integer busy_high_during_drain_fail_count;
    integer busy_high_during_output_backpressure_fail_count;
    integer busy_low_after_final_z_accept_fail_count;

    reg optimized_raw_normal_frame_pass;
    reg optimized_raw_input_gap_pass;
    reg optimized_raw_backpressure_pass;
    reg optimized_raw_two_frame_pass;
    reg optimized_raw_beam_order_pass;
    reg optimized_raw_status_pass;
    reg busy_low_after_reset;
    reg busy_high_from_first_y_accept;
    reg busy_high_during_drain;
    reg busy_high_during_output_backpressure;
    reg busy_low_after_final_z_accept;
    reg status_busy_semantics_pass;
    reg optimized_raw_top_xsim_pass_flag;

    reg [63:0] stable_data;
    reg [7:0]  stable_keep;
    reg        stable_last;

    always #5 aclk = ~aclk;

    dbf_axis_system_top_opt #(
        .N_ELEMS(N_ELEMS),
        .B_BEAMS(B_BEAMS),
        .W_BITS(18),
        .Y_BITS(16),
        .ACC_BITS(48),
        .Z_BITS(24),
        .SHIFT_BITS(20),
        .ADDR_BITS(12),
        .W_RE_B0_MAIN_FILE("results_step14_dbf_ip_soc_integration/axis_vectors/w_split/step14_1_w_re_b0_main.mem"),
        .W_RE_B0_TAIL_FILE("results_step14_dbf_ip_soc_integration/axis_vectors/w_split/step14_1_w_re_b0_tail.mem"),
        .W_IM_B0_MAIN_FILE("results_step14_dbf_ip_soc_integration/axis_vectors/w_split/step14_1_w_im_b0_main.mem"),
        .W_IM_B0_TAIL_FILE("results_step14_dbf_ip_soc_integration/axis_vectors/w_split/step14_1_w_im_b0_tail.mem"),
        .W_RE_B1_MAIN_FILE("results_step14_dbf_ip_soc_integration/axis_vectors/w_split/step14_1_w_re_b1_main.mem"),
        .W_RE_B1_TAIL_FILE("results_step14_dbf_ip_soc_integration/axis_vectors/w_split/step14_1_w_re_b1_tail.mem"),
        .W_IM_B1_MAIN_FILE("results_step14_dbf_ip_soc_integration/axis_vectors/w_split/step14_1_w_im_b1_main.mem"),
        .W_IM_B1_TAIL_FILE("results_step14_dbf_ip_soc_integration/axis_vectors/w_split/step14_1_w_im_b1_tail.mem"),
        .W_RE_B2_MAIN_FILE("results_step14_dbf_ip_soc_integration/axis_vectors/w_split/step14_1_w_re_b2_main.mem"),
        .W_RE_B2_TAIL_FILE("results_step14_dbf_ip_soc_integration/axis_vectors/w_split/step14_1_w_re_b2_tail.mem"),
        .W_IM_B2_MAIN_FILE("results_step14_dbf_ip_soc_integration/axis_vectors/w_split/step14_1_w_im_b2_main.mem"),
        .W_IM_B2_TAIL_FILE("results_step14_dbf_ip_soc_integration/axis_vectors/w_split/step14_1_w_im_b2_tail.mem"),
        .W_RE_B3_MAIN_FILE("results_step14_dbf_ip_soc_integration/axis_vectors/w_split/step14_1_w_re_b3_main.mem"),
        .W_RE_B3_TAIL_FILE("results_step14_dbf_ip_soc_integration/axis_vectors/w_split/step14_1_w_re_b3_tail.mem"),
        .W_IM_B3_MAIN_FILE("results_step14_dbf_ip_soc_integration/axis_vectors/w_split/step14_1_w_im_b3_main.mem"),
        .W_IM_B3_TAIL_FILE("results_step14_dbf_ip_soc_integration/axis_vectors/w_split/step14_1_w_im_b3_tail.mem"),
        .W_RE_B4_MAIN_FILE("results_step14_dbf_ip_soc_integration/axis_vectors/w_split/step14_1_w_re_b4_main.mem"),
        .W_RE_B4_TAIL_FILE("results_step14_dbf_ip_soc_integration/axis_vectors/w_split/step14_1_w_re_b4_tail.mem"),
        .W_IM_B4_MAIN_FILE("results_step14_dbf_ip_soc_integration/axis_vectors/w_split/step14_1_w_im_b4_main.mem"),
        .W_IM_B4_TAIL_FILE("results_step14_dbf_ip_soc_integration/axis_vectors/w_split/step14_1_w_im_b4_tail.mem"),
        .W_RE_B5_MAIN_FILE("results_step14_dbf_ip_soc_integration/axis_vectors/w_split/step14_1_w_re_b5_main.mem"),
        .W_RE_B5_TAIL_FILE("results_step14_dbf_ip_soc_integration/axis_vectors/w_split/step14_1_w_re_b5_tail.mem"),
        .W_IM_B5_MAIN_FILE("results_step14_dbf_ip_soc_integration/axis_vectors/w_split/step14_1_w_im_b5_main.mem"),
        .W_IM_B5_TAIL_FILE("results_step14_dbf_ip_soc_integration/axis_vectors/w_split/step14_1_w_im_b5_tail.mem"),
        .W_RE_B6_MAIN_FILE("results_step14_dbf_ip_soc_integration/axis_vectors/w_split/step14_1_w_re_b6_main.mem"),
        .W_RE_B6_TAIL_FILE("results_step14_dbf_ip_soc_integration/axis_vectors/w_split/step14_1_w_re_b6_tail.mem"),
        .W_IM_B6_MAIN_FILE("results_step14_dbf_ip_soc_integration/axis_vectors/w_split/step14_1_w_im_b6_main.mem"),
        .W_IM_B6_TAIL_FILE("results_step14_dbf_ip_soc_integration/axis_vectors/w_split/step14_1_w_im_b6_tail.mem")
    ) dut (
        .aclk(aclk),
        .aresetn(aresetn),
        .s_axis_y_tdata(s_axis_y_tdata),
        .s_axis_y_tkeep(s_axis_y_tkeep),
        .s_axis_y_tvalid(s_axis_y_tvalid),
        .s_axis_y_tready(s_axis_y_tready),
        .s_axis_y_tlast(s_axis_y_tlast),
        .m_axis_z_tdata(m_axis_z_tdata),
        .m_axis_z_tkeep(m_axis_z_tkeep),
        .m_axis_z_tvalid(m_axis_z_tvalid),
        .m_axis_z_tready(m_axis_z_tready),
        .m_axis_z_tlast(m_axis_z_tlast),
        .status_busy(status_busy),
        .status_frame_count(status_frame_count),
        .status_protocol_error(status_protocol_error),
        .status_early_tlast(status_early_tlast),
        .status_missing_tlast(status_missing_tlast),
        .status_bad_tkeep(status_bad_tkeep),
        .status_clip_seen(status_clip_seen),
        .status_overflow_seen(status_overflow_seen),
        .debug_element_index(debug_element_index),
        .debug_w_req_index(debug_w_req_index),
        .debug_sample_accept(debug_sample_accept)
    );

    initial begin
        $readmemh("results_step14_dbf_ip_soc_integration/axis_vectors/step14_1_y_axis_tdata.mem", y_mem);
        $readmemh("results_step14_dbf_ip_soc_integration/axis_vectors/step14_1_z_axis_expected.mem", z_expected_mem);
    end

    initial begin
        cycle_count = 0;
        forever begin
            @(posedge aclk);
            cycle_count = cycle_count + 1;
            if (cycle_count > TIMEOUT_CYCLES) begin
                timeout_flag = 1;
                $display("FAIL: Step14.2a optimized raw top timeout");
                write_summary();
                $finish;
            end
        end
    end

    initial begin
        init_flags();
        output_csv = $fopen("results_step14_dbf_ip_soc_integration/axis_opt_sim/step14_2a_opt_axis_output.csv", "w");
        summary_csv = $fopen("results_step14_dbf_ip_soc_integration/axis_opt_sim/step14_2a_opt_axis_tb_summary.csv", "w");
        if (output_csv == 0 || summary_csv == 0) begin
            $display("FAIL: cannot open Step14.2a optimized raw top CSV files");
            $finish;
        end
        $fwrite(output_csv, "frame_index,beam_id,tdata_hex,z_re,z_im,clip_re,clip_im,overflow_re,overflow_im,tlast\n");

        reset_dut();
        run_frame0();
        run_frame1();
        repeat (2) @(posedge aclk);

        optimized_raw_normal_frame_pass = (expected_mismatch_count == 0 && tkeep_fail_count == 0 &&
            tlast_fail_count == 0 && beam_order_fail_count == 0 && actual_output_rows == 14);
        optimized_raw_backpressure_pass = (backpressure_stability_fail_count == 0);
        optimized_raw_two_frame_pass = (status_frame_count == 32'd2);
        optimized_raw_beam_order_pass = (beam_order_fail_count == 0);
        optimized_raw_status_pass = !status_protocol_error && !status_early_tlast &&
            !status_missing_tlast && !status_bad_tkeep && !status_clip_seen &&
            !status_overflow_seen && (status_frame_count == 32'd2);
        update_busy_flags();

        optimized_raw_top_xsim_pass_flag = optimized_raw_normal_frame_pass &&
            optimized_raw_input_gap_pass && optimized_raw_backpressure_pass &&
            optimized_raw_two_frame_pass && optimized_raw_beam_order_pass &&
            optimized_raw_status_pass && status_busy_semantics_pass && (timeout_flag == 0);

        write_summary();
        if (optimized_raw_top_xsim_pass_flag) begin
            $display("PASS: Step14.2a optimized raw top AXIS regression");
        end else begin
            $display("FAIL: Step14.2a optimized raw top AXIS regression");
        end
        $finish;
    end

    task init_flags;
        begin
            actual_output_rows = 0;
            backpressure_stability_fail_count = 0;
            beam_order_fail_count = 0;
            expected_mismatch_count = 0;
            tkeep_fail_count = 0;
            tlast_fail_count = 0;
            timeout_flag = 0;
            busy_low_after_reset_fail_count = 0;
            busy_high_from_first_y_accept_fail_count = 0;
            busy_high_during_drain_fail_count = 0;
            busy_high_during_output_backpressure_fail_count = 0;
            busy_low_after_final_z_accept_fail_count = 0;
            optimized_raw_normal_frame_pass = 0;
            optimized_raw_input_gap_pass = 1;
            optimized_raw_backpressure_pass = 0;
            optimized_raw_two_frame_pass = 0;
            optimized_raw_beam_order_pass = 0;
            optimized_raw_status_pass = 0;
            busy_low_after_reset = 0;
            busy_high_from_first_y_accept = 0;
            busy_high_during_drain = 0;
            busy_high_during_output_backpressure = 0;
            busy_low_after_final_z_accept = 0;
            status_busy_semantics_pass = 0;
            optimized_raw_top_xsim_pass_flag = 0;
        end
    endtask

    task reset_dut;
        begin
            s_axis_y_tdata = 32'd0;
            s_axis_y_tkeep = 4'hF;
            s_axis_y_tvalid = 1'b0;
            s_axis_y_tlast = 1'b0;
            m_axis_z_tready = 1'b0;
            aresetn = 1'b0;
            repeat (8) @(posedge aclk);
            if (status_busy !== 1'b0) begin
                busy_low_after_reset_fail_count = busy_low_after_reset_fail_count + 1;
            end
            @(negedge aclk);
            aresetn = 1'b1;
            repeat (2) @(posedge aclk);
            if (status_busy !== 1'b0) begin
                busy_low_after_reset_fail_count = busy_low_after_reset_fail_count + 1;
            end
        end
    endtask

    task send_one_sample;
        input integer mem_index;
        input integer element_index;
        integer accepted;
        begin
            @(negedge aclk);
            s_axis_y_tdata = y_mem[mem_index];
            s_axis_y_tkeep = 4'hF;
            s_axis_y_tlast = (element_index == (N_ELEMS-1));
            s_axis_y_tvalid = 1'b1;
            accepted = 0;
            while (!accepted) begin
                @(posedge aclk);
                if (s_axis_y_tready) begin
                    accepted = 1;
                end
            end
            #1;
            if (status_busy !== 1'b1) begin
                busy_high_from_first_y_accept_fail_count = busy_high_from_first_y_accept_fail_count + 1;
            end
        end
    endtask

    task send_frame;
        input integer frame_index;
        input integer gap_enable;
        integer n;
        integer accepted_count;
        reg [11:0] gap_element_index_before;
        reg [11:0] gap_w_req_index_before;
        begin
            accepted_count = 0;
            for (n = 0; n < N_ELEMS; n = n + 1) begin
                send_one_sample(frame_index*N_ELEMS + n, n);
                accepted_count = accepted_count + 1;
                if (gap_enable && (accepted_count % 257 == 0) && n != (N_ELEMS-1)) begin
                    @(negedge aclk);
                    s_axis_y_tvalid = 1'b0;
                    s_axis_y_tlast = 1'b0;
                    s_axis_y_tkeep = 4'hF;
                    gap_element_index_before = debug_element_index;
                    gap_w_req_index_before = debug_w_req_index;
                    @(posedge aclk);
                    if (debug_sample_accept !== 1'b0 ||
                            debug_element_index !== gap_element_index_before ||
                            debug_w_req_index !== gap_w_req_index_before) begin
                        optimized_raw_input_gap_pass = 1'b0;
                    end
                end
            end
            @(negedge aclk);
            s_axis_y_tvalid = 1'b0;
            s_axis_y_tlast = 1'b0;
            s_axis_y_tkeep = 4'hF;
            s_axis_y_tdata = 32'd0;
        end
    endtask

    task run_frame0;
        begin
            @(negedge aclk);
            m_axis_z_tready = 1'b1;
            send_frame(0, 0);
            collect_outputs(0, 0, 0);
        end
    endtask

    task run_frame1;
        begin
            send_frame(1, 1);
            collect_outputs(1, 7, 1);
        end
    endtask

    task collect_outputs;
        input integer frame_index;
        input integer expected_base;
        input integer enable_backpressure;
        integer beam;
        integer stall_count;
        begin
            beam = 0;
            @(negedge aclk);
            m_axis_z_tready = 1'b1;
            while (beam < B_BEAMS) begin
                @(posedge aclk);
                if (!m_axis_z_tvalid && status_busy !== 1'b1) begin
                    busy_high_during_drain_fail_count = busy_high_during_drain_fail_count + 1;
                end
                if (m_axis_z_tvalid && m_axis_z_tready) begin
                    check_and_log_output(frame_index, beam, expected_base + beam);
                    beam = beam + 1;
                    if (enable_backpressure && (beam == 2 || beam == 5)) begin
                        @(negedge aclk);
                        m_axis_z_tready = 1'b0;
                        stable_data = m_axis_z_tdata;
                        stable_keep = m_axis_z_tkeep;
                        stable_last = m_axis_z_tlast;
                        for (stall_count = 0; stall_count < 3; stall_count = stall_count + 1) begin
                            @(posedge aclk);
                            if (status_busy !== 1'b1) begin
                                busy_high_during_output_backpressure_fail_count =
                                    busy_high_during_output_backpressure_fail_count + 1;
                            end
                            if (m_axis_z_tvalid !== 1'b1 || m_axis_z_tdata !== stable_data ||
                                    m_axis_z_tkeep !== stable_keep ||
                                    m_axis_z_tlast !== stable_last) begin
                                backpressure_stability_fail_count = backpressure_stability_fail_count + 1;
                            end
                        end
                        @(negedge aclk);
                        m_axis_z_tready = 1'b1;
                    end
                    if (beam == B_BEAMS) begin
                        @(negedge aclk);
                        if (status_busy !== 1'b0) begin
                            busy_low_after_final_z_accept_fail_count =
                                busy_low_after_final_z_accept_fail_count + 1;
                        end
                    end
                end
            end
        end
    endtask

    task check_and_log_output;
        input integer frame_index;
        input integer beam;
        input integer expected_index;
        reg signed [23:0] z_re;
        reg signed [23:0] z_im;
        reg clip_re;
        reg clip_im;
        reg overflow_re;
        reg overflow_im;
        reg [2:0] beam_id;
        begin
            z_re = m_axis_z_tdata[23:0];
            z_im = m_axis_z_tdata[47:24];
            clip_re = m_axis_z_tdata[48];
            clip_im = m_axis_z_tdata[49];
            overflow_re = m_axis_z_tdata[50];
            overflow_im = m_axis_z_tdata[51];
            beam_id = m_axis_z_tdata[54:52];
            if (m_axis_z_tdata !== z_expected_mem[expected_index]) begin
                expected_mismatch_count = expected_mismatch_count + 1;
            end
            if (beam_id !== beam[2:0]) begin
                beam_order_fail_count = beam_order_fail_count + 1;
            end
            if (m_axis_z_tkeep !== 8'hFF) begin
                tkeep_fail_count = tkeep_fail_count + 1;
            end
            if (m_axis_z_tlast !== (beam == 6)) begin
                tlast_fail_count = tlast_fail_count + 1;
            end
            $fwrite(output_csv, "%0d,%0d,%016h,%0d,%0d,%0d,%0d,%0d,%0d,%0d\n",
                frame_index, beam, m_axis_z_tdata, z_re, z_im, clip_re, clip_im,
                overflow_re, overflow_im, m_axis_z_tlast);
            actual_output_rows = actual_output_rows + 1;
        end
    endtask

    task write_metric;
        input [8*96-1:0] name;
        input integer flag;
        begin
            $fwrite(summary_csv, "%0s,%0s\n", name, flag ? "true" : "false");
        end
    endtask

    task update_busy_flags;
        begin
            busy_low_after_reset = (busy_low_after_reset_fail_count == 0);
            busy_high_from_first_y_accept = (busy_high_from_first_y_accept_fail_count == 0);
            busy_high_during_drain = (busy_high_during_drain_fail_count == 0);
            busy_high_during_output_backpressure =
                (busy_high_during_output_backpressure_fail_count == 0);
            busy_low_after_final_z_accept = (busy_low_after_final_z_accept_fail_count == 0);
            status_busy_semantics_pass = busy_low_after_reset &&
                busy_high_from_first_y_accept && busy_high_during_drain &&
                busy_high_during_output_backpressure && busy_low_after_final_z_accept;
        end
    endtask

    task write_summary;
        begin
            update_busy_flags();
            $fwrite(summary_csv, "metric,value\n");
            write_metric("optimized_raw_normal_frame_pass", optimized_raw_normal_frame_pass);
            write_metric("optimized_raw_input_gap_pass", optimized_raw_input_gap_pass);
            write_metric("optimized_raw_backpressure_pass", optimized_raw_backpressure_pass);
            write_metric("optimized_raw_two_frame_pass", optimized_raw_two_frame_pass);
            write_metric("optimized_raw_beam_order_pass", optimized_raw_beam_order_pass);
            write_metric("optimized_raw_status_pass", optimized_raw_status_pass);
            write_metric("busy_low_after_reset", busy_low_after_reset);
            write_metric("busy_high_from_first_y_accept", busy_high_from_first_y_accept);
            write_metric("busy_high_during_drain", busy_high_during_drain);
            write_metric("busy_high_during_output_backpressure", busy_high_during_output_backpressure);
            write_metric("busy_low_after_final_z_accept", busy_low_after_final_z_accept);
            write_metric("status_busy_semantics_pass", status_busy_semantics_pass);
            $fwrite(summary_csv, "expected_output_rows,14\n");
            $fwrite(summary_csv, "actual_output_rows,%0d\n", actual_output_rows);
            write_metric("timeout_flag", timeout_flag);
            write_metric("optimized_raw_top_xsim_pass_flag", optimized_raw_top_xsim_pass_flag);
            $fwrite(summary_csv, "formal_result_claimed,false\n");
            $fclose(output_csv);
            $fclose(summary_csv);
        end
    endtask

endmodule
