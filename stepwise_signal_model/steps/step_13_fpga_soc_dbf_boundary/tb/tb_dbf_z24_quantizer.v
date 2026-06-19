`timescale 1ns/1ps

module tb_dbf_z24_quantizer;
    localparam integer ACC_BITS = 16;
    localparam integer Z_BITS = 8;
    localparam integer SHIFT_BITS = 3;

    reg signed [ACC_BITS-1:0] acc_in;
    wire signed [Z_BITS-1:0] z_out;
    wire clip_flag;
    wire overflow_flag;

    integer errors;

    dbf_z24_quantizer #(
        .ACC_BITS(ACC_BITS),
        .Z_BITS(Z_BITS),
        .SHIFT_BITS(SHIFT_BITS)
    ) dut (
        .acc_in(acc_in),
        .z_out(z_out),
        .clip_flag(clip_flag),
        .overflow_flag(overflow_flag)
    );

    task check_case;
        input signed [ACC_BITS-1:0] t_acc;
        input signed [Z_BITS-1:0] exp_z;
        input exp_clip;
        begin
            acc_in = t_acc;
            #1;
            if (z_out !== exp_z || clip_flag !== exp_clip || overflow_flag !== exp_clip) begin
                $display("FAIL: acc=%0d got z=%0d clip=%0d overflow=%0d exp z=%0d clip=%0d",
                    t_acc, z_out, clip_flag, overflow_flag, exp_z, exp_clip);
                errors = errors + 1;
            end
        end
    endtask

    initial begin
        errors = 0;

        check_case(16'sd0,      8'sd0,    1'b0);
        check_case(16'sd3,      8'sd0,    1'b0);
        check_case(16'sd4,      8'sd1,    1'b0);
        check_case(16'sd11,     8'sd1,    1'b0);
        check_case(16'sd12,     8'sd2,    1'b0);
        check_case(-16'sd3,    -8'sd0,    1'b0);
        check_case(-16'sd4,    -8'sd1,    1'b0);
        check_case(-16'sd11,   -8'sd1,    1'b0);
        check_case(-16'sd12,   -8'sd2,    1'b0);
        check_case(16'sd1016,   8'sd127,  1'b0);
        check_case(16'sd1020,   8'sd127,  1'b1);
        check_case(-16'sd1024, -8'sd128,  1'b0);
        check_case(-16'sd1028, -8'sd128,  1'b1);

        if (errors == 0) begin
            $display("PASS: tb_dbf_z24_quantizer");
            $finish;
        end

        $display("FAIL: tb_dbf_z24_quantizer errors=%0d", errors);
        $finish;
    end
endmodule
