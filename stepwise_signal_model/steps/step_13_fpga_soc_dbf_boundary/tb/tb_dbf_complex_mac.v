`timescale 1ns/1ps

module tb_dbf_complex_mac;
    localparam integer W_BITS = 8;
    localparam integer Y_BITS = 8;
    localparam integer P_BITS = W_BITS + Y_BITS + 1;

    reg signed [W_BITS-1:0] w_re;
    reg signed [W_BITS-1:0] w_im;
    reg signed [Y_BITS-1:0] y_re;
    reg signed [Y_BITS-1:0] y_im;
    wire signed [P_BITS-1:0] p_re;
    wire signed [P_BITS-1:0] p_im;

    integer errors;

    dbf_complex_mac #(
        .W_BITS(W_BITS),
        .Y_BITS(Y_BITS),
        .P_BITS(P_BITS)
    ) dut (
        .w_re(w_re),
        .w_im(w_im),
        .y_re(y_re),
        .y_im(y_im),
        .p_re(p_re),
        .p_im(p_im)
    );

    task check_case;
        input signed [W_BITS-1:0] tw_re;
        input signed [W_BITS-1:0] tw_im;
        input signed [Y_BITS-1:0] ty_re;
        input signed [Y_BITS-1:0] ty_im;
        input integer exp_re;
        input integer exp_im;
        begin
            w_re = tw_re;
            w_im = tw_im;
            y_re = ty_re;
            y_im = ty_im;
            #1;
            if (p_re !== exp_re || p_im !== exp_im) begin
                $display("FAIL: w=(%0d,%0d) y=(%0d,%0d) got=(%0d,%0d) exp=(%0d,%0d)",
                    tw_re, tw_im, ty_re, ty_im, p_re, p_im, exp_re, exp_im);
                errors = errors + 1;
            end
        end
    endtask

    initial begin
        errors = 0;

        check_case(8'sd3,   8'sd4,   8'sd5,   8'sd6,    39,  -2);
        check_case(-8'sd3,  8'sd4,   8'sd5,  -8'sd6,  -39, -2);
        check_case(8'sd7,  -8'sd2,  -8'sd3,  8'sd5,   -31, 29);
        check_case(-8'sd8, -8'sd9,   8'sd2,   8'sd3,   -43, -6);
        check_case(8'sd0,   8'sd5,  -8'sd7,  8'sd2,    10, 35);

        if (errors == 0) begin
            $display("PASS: tb_dbf_complex_mac");
            $finish;
        end

        $display("FAIL: tb_dbf_complex_mac errors=%0d", errors);
        $finish;
    end
endmodule
