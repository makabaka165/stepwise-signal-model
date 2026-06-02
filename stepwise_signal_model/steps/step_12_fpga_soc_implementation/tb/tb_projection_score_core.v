`timescale 1ns/1ps

module tb_projection_score_core;
    localparam integer SAMPLE_WIDTH = 16;
    localparam integer ACC_WIDTH = 48;

    reg clk;
    reg rst_n;
    reg clear;
    reg sample_valid;
    reg signed [SAMPLE_WIDTH-1:0] y_i;
    reg signed [SAMPLE_WIDTH-1:0] y_q;
    reg signed [SAMPLE_WIDTH-1:0] steering_i;
    reg signed [SAMPLE_WIDTH-1:0] steering_q;
    wire signed [ACC_WIDTH-1:0] score_i;
    wire signed [ACC_WIDTH-1:0] score_q;
    wire score_valid;

    integer errors;

    projection_score_core #(
        .SAMPLE_WIDTH(SAMPLE_WIDTH),
        .ACC_WIDTH(ACC_WIDTH)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .clear(clear),
        .sample_valid(sample_valid),
        .y_i(y_i),
        .y_q(y_q),
        .steering_i(steering_i),
        .steering_q(steering_q),
        .score_i(score_i),
        .score_q(score_q),
        .score_valid(score_valid)
    );

    always #5 clk = ~clk;

    task push_sample;
        input integer yi;
        input integer yq;
        input integer si;
        input integer sq;
        begin
            @(negedge clk);
            y_i = yi;
            y_q = yq;
            steering_i = si;
            steering_q = sq;
            sample_valid = 1'b1;
            @(posedge clk);
            #1;
        end
    endtask

    initial begin
        clk = 0;
        rst_n = 0;
        clear = 0;
        sample_valid = 0;
        y_i = 0;
        y_q = 0;
        steering_i = 0;
        steering_q = 0;
        errors = 0;

        repeat (2) @(posedge clk);
        rst_n = 1;

        push_sample(1, 2, 3, 4);
        push_sample(2, -1, 5, 1);
        push_sample(-3, 1, 2, -2);

        @(negedge clk);
        sample_valid = 0;
        @(posedge clk);
        #1;

        // Accumulates y * conj(steering):
        // (1+2j)*(3-4j)=11+2j
        // (2-1j)*(5-1j)=9-7j
        // (-3+1j)*(2+2j)=-8-4j
        // total = 12-9j
        if (score_i !== 12 || score_q !== -9) begin
            $display("ERROR score_i=%0d score_q=%0d expected_i=12 expected_q=-9", score_i, score_q);
            errors = errors + 1;
        end

        if (errors == 0) begin
            $display("PASS tb_projection_score_core");
        end else begin
            $display("FAIL tb_projection_score_core errors=%0d", errors);
            $finish(1);
        end
        $finish;
    end
endmodule
