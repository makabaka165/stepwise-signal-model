`timescale 1ns/1ps

module tb_dbf_w_provider_rom_opt_boundary;

    localparam integer N_ELEMS = 2080;
    localparam integer ADDR_BITS = 12;
    localparam integer W_BITS = 18;
    localparam integer MAIN_DEPTH = 2048;
    localparam integer TAIL_DEPTH = 32;
    localparam integer TIMEOUT_CYCLES = 2000;

    reg clk = 1'b0;
    reg rst = 1'b1;
    reg req_valid = 1'b0;
    reg [ADDR_BITS-1:0] req_index = {ADDR_BITS{1'b0}};
    wire rsp_valid;
    wire signed [7*W_BITS-1:0] w_re_bus;
    wire signed [7*W_BITS-1:0] w_im_bus;

    reg signed [W_BITS-1:0] re_main [0:6][0:MAIN_DEPTH-1];
    reg signed [W_BITS-1:0] im_main [0:6][0:MAIN_DEPTH-1];
    reg signed [W_BITS-1:0] re_tail [0:6][0:TAIL_DEPTH-1];
    reg signed [W_BITS-1:0] im_tail [0:6][0:TAIL_DEPTH-1];

    integer summary_csv;
    integer cycle_count;
    integer response_count;
    integer invalid_response_count;
    integer one_cycle_fail_count;
    integer data_mismatch_count;
    integer request_gap_pass;
    integer back_to_back_main_tail_pass;
    integer timeout_flag;
    integer prev_req_valid;
    integer prev_in_range;
    integer prev_addr;

    always #5 clk = ~clk;

    dbf_w_provider_rom_opt #(
        .N_ELEMS(N_ELEMS),
        .ADDR_BITS(ADDR_BITS),
        .W_BITS(W_BITS),
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
        .clk(clk),
        .rst(rst),
        .req_valid(req_valid),
        .req_index(req_index),
        .rsp_valid(rsp_valid),
        .w_re_bus(w_re_bus),
        .w_im_bus(w_im_bus)
    );

    initial begin
        $readmemh("results_step14_dbf_ip_soc_integration/axis_vectors/w_split/step14_1_w_re_b0_main.mem", re_main[0]);
        $readmemh("results_step14_dbf_ip_soc_integration/axis_vectors/w_split/step14_1_w_im_b0_main.mem", im_main[0]);
        $readmemh("results_step14_dbf_ip_soc_integration/axis_vectors/w_split/step14_1_w_re_b0_tail.mem", re_tail[0]);
        $readmemh("results_step14_dbf_ip_soc_integration/axis_vectors/w_split/step14_1_w_im_b0_tail.mem", im_tail[0]);
        $readmemh("results_step14_dbf_ip_soc_integration/axis_vectors/w_split/step14_1_w_re_b1_main.mem", re_main[1]);
        $readmemh("results_step14_dbf_ip_soc_integration/axis_vectors/w_split/step14_1_w_im_b1_main.mem", im_main[1]);
        $readmemh("results_step14_dbf_ip_soc_integration/axis_vectors/w_split/step14_1_w_re_b1_tail.mem", re_tail[1]);
        $readmemh("results_step14_dbf_ip_soc_integration/axis_vectors/w_split/step14_1_w_im_b1_tail.mem", im_tail[1]);
        $readmemh("results_step14_dbf_ip_soc_integration/axis_vectors/w_split/step14_1_w_re_b2_main.mem", re_main[2]);
        $readmemh("results_step14_dbf_ip_soc_integration/axis_vectors/w_split/step14_1_w_im_b2_main.mem", im_main[2]);
        $readmemh("results_step14_dbf_ip_soc_integration/axis_vectors/w_split/step14_1_w_re_b2_tail.mem", re_tail[2]);
        $readmemh("results_step14_dbf_ip_soc_integration/axis_vectors/w_split/step14_1_w_im_b2_tail.mem", im_tail[2]);
        $readmemh("results_step14_dbf_ip_soc_integration/axis_vectors/w_split/step14_1_w_re_b3_main.mem", re_main[3]);
        $readmemh("results_step14_dbf_ip_soc_integration/axis_vectors/w_split/step14_1_w_im_b3_main.mem", im_main[3]);
        $readmemh("results_step14_dbf_ip_soc_integration/axis_vectors/w_split/step14_1_w_re_b3_tail.mem", re_tail[3]);
        $readmemh("results_step14_dbf_ip_soc_integration/axis_vectors/w_split/step14_1_w_im_b3_tail.mem", im_tail[3]);
        $readmemh("results_step14_dbf_ip_soc_integration/axis_vectors/w_split/step14_1_w_re_b4_main.mem", re_main[4]);
        $readmemh("results_step14_dbf_ip_soc_integration/axis_vectors/w_split/step14_1_w_im_b4_main.mem", im_main[4]);
        $readmemh("results_step14_dbf_ip_soc_integration/axis_vectors/w_split/step14_1_w_re_b4_tail.mem", re_tail[4]);
        $readmemh("results_step14_dbf_ip_soc_integration/axis_vectors/w_split/step14_1_w_im_b4_tail.mem", im_tail[4]);
        $readmemh("results_step14_dbf_ip_soc_integration/axis_vectors/w_split/step14_1_w_re_b5_main.mem", re_main[5]);
        $readmemh("results_step14_dbf_ip_soc_integration/axis_vectors/w_split/step14_1_w_im_b5_main.mem", im_main[5]);
        $readmemh("results_step14_dbf_ip_soc_integration/axis_vectors/w_split/step14_1_w_re_b5_tail.mem", re_tail[5]);
        $readmemh("results_step14_dbf_ip_soc_integration/axis_vectors/w_split/step14_1_w_im_b5_tail.mem", im_tail[5]);
        $readmemh("results_step14_dbf_ip_soc_integration/axis_vectors/w_split/step14_1_w_re_b6_main.mem", re_main[6]);
        $readmemh("results_step14_dbf_ip_soc_integration/axis_vectors/w_split/step14_1_w_im_b6_main.mem", im_main[6]);
        $readmemh("results_step14_dbf_ip_soc_integration/axis_vectors/w_split/step14_1_w_re_b6_tail.mem", re_tail[6]);
        $readmemh("results_step14_dbf_ip_soc_integration/axis_vectors/w_split/step14_1_w_im_b6_tail.mem", im_tail[6]);
    end

    initial begin
        cycle_count = 0;
        forever begin
            @(posedge clk);
            cycle_count = cycle_count + 1;
            if (cycle_count > TIMEOUT_CYCLES) begin
                timeout_flag = 1;
                write_summary();
                $display("FAIL: W provider boundary timeout");
                $finish;
            end
        end
    end

    initial begin
        init_flags();
        summary_csv = $fopen("results_step14_dbf_ip_soc_integration/hardening/step14_2b_w_provider_boundary_summary.csv", "w");
        if (summary_csv == 0) begin
            $display("FAIL: cannot open W provider boundary summary");
            $finish;
        end

        repeat (4) @(posedge clk);
        rst = 1'b0;
        tick_request(1'b1, 12'd0);
        tick_request(1'b1, 12'd2047);
        tick_request(1'b1, 12'd2048);
        tick_request(1'b1, 12'd2079);
        tick_request(1'b1, 12'd2080);
        tick_request(1'b0, 12'd0);
        request_gap_pass = (rsp_valid === 1'b0);
        tick_request(1'b1, 12'd2047);
        tick_request(1'b1, 12'd2048);
        tick_request(1'b0, 12'd0);
        back_to_back_main_tail_pass = (one_cycle_fail_count == 0 && data_mismatch_count == 0);
        tick_request(1'b0, 12'd0);

        write_summary();
        if (w_provider_boundary_pass()) begin
            $display("PASS: Step14.2b W provider boundary regression");
        end else begin
            $display("FAIL: Step14.2b W provider boundary regression");
        end
        $finish;
    end

    task init_flags;
        begin
            response_count = 0;
            invalid_response_count = 0;
            one_cycle_fail_count = 0;
            data_mismatch_count = 0;
            request_gap_pass = 0;
            back_to_back_main_tail_pass = 0;
            timeout_flag = 0;
            prev_req_valid = 0;
            prev_in_range = 0;
            prev_addr = 0;
        end
    endtask

    task tick_request;
        input valid;
        input [ADDR_BITS-1:0] addr;
        begin
            @(negedge clk);
            check_response();
            req_valid = valid;
            req_index = addr;
            prev_req_valid = valid;
            prev_in_range = valid && (addr < N_ELEMS);
            prev_addr = addr;
            @(posedge clk);
        end
    endtask

    task check_response;
        begin
            if (rsp_valid !== prev_in_range[0]) begin
                one_cycle_fail_count = one_cycle_fail_count + 1;
            end
            if (prev_req_valid && !prev_in_range && rsp_valid) begin
                invalid_response_count = invalid_response_count + 1;
            end
            if (prev_in_range) begin
                response_count = response_count + 1;
                check_data(prev_addr);
            end else if (rsp_valid === 1'b0) begin
                if (w_re_bus !== {7*W_BITS{1'b0}} || w_im_bus !== {7*W_BITS{1'b0}}) begin
                    data_mismatch_count = data_mismatch_count + 1;
                end
            end
        end
    endtask

    task check_data;
        input integer addr;
        integer beam;
        reg signed [W_BITS-1:0] exp_re;
        reg signed [W_BITS-1:0] exp_im;
        begin
            for (beam = 0; beam < 7; beam = beam + 1) begin
                if (addr < MAIN_DEPTH) begin
                    exp_re = re_main[beam][addr];
                    exp_im = im_main[beam][addr];
                end else begin
                    exp_re = re_tail[beam][addr - MAIN_DEPTH];
                    exp_im = im_tail[beam][addr - MAIN_DEPTH];
                end
                if (w_re_bus[beam*W_BITS +: W_BITS] !== exp_re ||
                        w_im_bus[beam*W_BITS +: W_BITS] !== exp_im) begin
                    data_mismatch_count = data_mismatch_count + 1;
                end
            end
        end
    endtask

    function integer w_provider_boundary_pass;
        begin
            w_provider_boundary_pass = (response_count == 6) &&
                (invalid_response_count == 0) &&
                (one_cycle_fail_count == 0) &&
                (data_mismatch_count == 0) &&
                request_gap_pass &&
                back_to_back_main_tail_pass &&
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
            $fwrite(summary_csv, "valid_response_count,%0d\n", response_count);
            $fwrite(summary_csv, "invalid_response_count,%0d\n", invalid_response_count);
            $fwrite(summary_csv, "one_cycle_fail_count,%0d\n", one_cycle_fail_count);
            $fwrite(summary_csv, "data_mismatch_count,%0d\n", data_mismatch_count);
            write_metric("addr_0_checked", response_count >= 1);
            write_metric("addr_2047_checked", response_count >= 2);
            write_metric("addr_2048_checked", response_count >= 3);
            write_metric("addr_2079_checked", response_count >= 4);
            write_metric("addr_2080_invalid_checked", invalid_response_count == 0);
            write_metric("request_gap_pass", request_gap_pass);
            write_metric("back_to_back_main_tail_pass", back_to_back_main_tail_pass);
            write_metric("timeout_flag", timeout_flag);
            write_metric("w_provider_boundary_pass", w_provider_boundary_pass());
            $fwrite(summary_csv, "formal_result_claimed,false\n");
            $fwrite(summary_csv, "dma_validation_flag,false\n");
            $fwrite(summary_csv, "ps_validation_flag,false\n");
            $fwrite(summary_csv, "board_validation_flag,false\n");
            $fclose(summary_csv);
        end
    endtask

endmodule
