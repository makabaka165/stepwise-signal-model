`timescale 1ns/1ps

// Step14 replaceable W provider ROM model.
// Fixed B=7 lane packing: beam 0 is bus[0*W_BITS +: W_BITS].
module dbf_w_provider_rom #(
    parameter integer N_ELEMS = 2080,
    parameter integer ADDR_BITS = 12,
    parameter integer W_BITS = 18,
    parameter W_RE_B0_FILE = "",
    parameter W_IM_B0_FILE = "",
    parameter W_RE_B1_FILE = "",
    parameter W_IM_B1_FILE = "",
    parameter W_RE_B2_FILE = "",
    parameter W_IM_B2_FILE = "",
    parameter W_RE_B3_FILE = "",
    parameter W_IM_B3_FILE = "",
    parameter W_RE_B4_FILE = "",
    parameter W_IM_B4_FILE = "",
    parameter W_RE_B5_FILE = "",
    parameter W_IM_B5_FILE = "",
    parameter W_RE_B6_FILE = "",
    parameter W_IM_B6_FILE = ""
) (
    input  wire                         clk,
    input  wire                         rst,
    input  wire                         req_valid,
    input  wire [ADDR_BITS-1:0]         req_index,
    output reg                          rsp_valid,
    output reg signed [7*W_BITS-1:0]    w_re_bus,
    output reg signed [7*W_BITS-1:0]    w_im_bus
);

    wire [W_BITS-1:0] w_re_b0_dout;
    wire [W_BITS-1:0] w_im_b0_dout;
    wire [W_BITS-1:0] w_re_b1_dout;
    wire [W_BITS-1:0] w_im_b1_dout;
    wire [W_BITS-1:0] w_re_b2_dout;
    wire [W_BITS-1:0] w_im_b2_dout;
    wire [W_BITS-1:0] w_re_b3_dout;
    wire [W_BITS-1:0] w_im_b3_dout;
    wire [W_BITS-1:0] w_re_b4_dout;
    wire [W_BITS-1:0] w_im_b4_dout;
    wire [W_BITS-1:0] w_re_b5_dout;
    wire [W_BITS-1:0] w_im_b5_dout;
    wire [W_BITS-1:0] w_re_b6_dout;
    wire [W_BITS-1:0] w_im_b6_dout;

    reg rsp_index_in_range;
    wire req_index_in_range;

    assign req_index_in_range = (req_index < N_ELEMS);

    dbf_w_provider_sprom #(
        .N_ELEMS(N_ELEMS),
        .ADDR_BITS(ADDR_BITS),
        .W_BITS(W_BITS),
        .INIT_FILE(W_RE_B0_FILE)
    ) u_w_re_b0 (
        .clk(clk),
        .ena(req_valid && req_index_in_range),
        .addr(req_index),
        .dout(w_re_b0_dout)
    );

    dbf_w_provider_sprom #(
        .N_ELEMS(N_ELEMS),
        .ADDR_BITS(ADDR_BITS),
        .W_BITS(W_BITS),
        .INIT_FILE(W_IM_B0_FILE)
    ) u_w_im_b0 (
        .clk(clk),
        .ena(req_valid && req_index_in_range),
        .addr(req_index),
        .dout(w_im_b0_dout)
    );

    dbf_w_provider_sprom #(
        .N_ELEMS(N_ELEMS),
        .ADDR_BITS(ADDR_BITS),
        .W_BITS(W_BITS),
        .INIT_FILE(W_RE_B1_FILE)
    ) u_w_re_b1 (
        .clk(clk),
        .ena(req_valid && req_index_in_range),
        .addr(req_index),
        .dout(w_re_b1_dout)
    );

    dbf_w_provider_sprom #(
        .N_ELEMS(N_ELEMS),
        .ADDR_BITS(ADDR_BITS),
        .W_BITS(W_BITS),
        .INIT_FILE(W_IM_B1_FILE)
    ) u_w_im_b1 (
        .clk(clk),
        .ena(req_valid && req_index_in_range),
        .addr(req_index),
        .dout(w_im_b1_dout)
    );

    dbf_w_provider_sprom #(
        .N_ELEMS(N_ELEMS),
        .ADDR_BITS(ADDR_BITS),
        .W_BITS(W_BITS),
        .INIT_FILE(W_RE_B2_FILE)
    ) u_w_re_b2 (
        .clk(clk),
        .ena(req_valid && req_index_in_range),
        .addr(req_index),
        .dout(w_re_b2_dout)
    );

    dbf_w_provider_sprom #(
        .N_ELEMS(N_ELEMS),
        .ADDR_BITS(ADDR_BITS),
        .W_BITS(W_BITS),
        .INIT_FILE(W_IM_B2_FILE)
    ) u_w_im_b2 (
        .clk(clk),
        .ena(req_valid && req_index_in_range),
        .addr(req_index),
        .dout(w_im_b2_dout)
    );

    dbf_w_provider_sprom #(
        .N_ELEMS(N_ELEMS),
        .ADDR_BITS(ADDR_BITS),
        .W_BITS(W_BITS),
        .INIT_FILE(W_RE_B3_FILE)
    ) u_w_re_b3 (
        .clk(clk),
        .ena(req_valid && req_index_in_range),
        .addr(req_index),
        .dout(w_re_b3_dout)
    );

    dbf_w_provider_sprom #(
        .N_ELEMS(N_ELEMS),
        .ADDR_BITS(ADDR_BITS),
        .W_BITS(W_BITS),
        .INIT_FILE(W_IM_B3_FILE)
    ) u_w_im_b3 (
        .clk(clk),
        .ena(req_valid && req_index_in_range),
        .addr(req_index),
        .dout(w_im_b3_dout)
    );

    dbf_w_provider_sprom #(
        .N_ELEMS(N_ELEMS),
        .ADDR_BITS(ADDR_BITS),
        .W_BITS(W_BITS),
        .INIT_FILE(W_RE_B4_FILE)
    ) u_w_re_b4 (
        .clk(clk),
        .ena(req_valid && req_index_in_range),
        .addr(req_index),
        .dout(w_re_b4_dout)
    );

    dbf_w_provider_sprom #(
        .N_ELEMS(N_ELEMS),
        .ADDR_BITS(ADDR_BITS),
        .W_BITS(W_BITS),
        .INIT_FILE(W_IM_B4_FILE)
    ) u_w_im_b4 (
        .clk(clk),
        .ena(req_valid && req_index_in_range),
        .addr(req_index),
        .dout(w_im_b4_dout)
    );

    dbf_w_provider_sprom #(
        .N_ELEMS(N_ELEMS),
        .ADDR_BITS(ADDR_BITS),
        .W_BITS(W_BITS),
        .INIT_FILE(W_RE_B5_FILE)
    ) u_w_re_b5 (
        .clk(clk),
        .ena(req_valid && req_index_in_range),
        .addr(req_index),
        .dout(w_re_b5_dout)
    );

    dbf_w_provider_sprom #(
        .N_ELEMS(N_ELEMS),
        .ADDR_BITS(ADDR_BITS),
        .W_BITS(W_BITS),
        .INIT_FILE(W_IM_B5_FILE)
    ) u_w_im_b5 (
        .clk(clk),
        .ena(req_valid && req_index_in_range),
        .addr(req_index),
        .dout(w_im_b5_dout)
    );

    dbf_w_provider_sprom #(
        .N_ELEMS(N_ELEMS),
        .ADDR_BITS(ADDR_BITS),
        .W_BITS(W_BITS),
        .INIT_FILE(W_RE_B6_FILE)
    ) u_w_re_b6 (
        .clk(clk),
        .ena(req_valid && req_index_in_range),
        .addr(req_index),
        .dout(w_re_b6_dout)
    );

    dbf_w_provider_sprom #(
        .N_ELEMS(N_ELEMS),
        .ADDR_BITS(ADDR_BITS),
        .W_BITS(W_BITS),
        .INIT_FILE(W_IM_B6_FILE)
    ) u_w_im_b6 (
        .clk(clk),
        .ena(req_valid && req_index_in_range),
        .addr(req_index),
        .dout(w_im_b6_dout)
    );

    always @(posedge clk) begin
        if (rst) begin
            rsp_valid <= 1'b0;
            rsp_index_in_range <= 1'b0;
        end else begin
            rsp_valid <= req_valid;
            rsp_index_in_range <= req_valid && req_index_in_range;
            if (req_valid && !req_index_in_range) begin
                // synthesis translate_off
                $display("WARNING: dbf_w_provider_rom out-of-range req_index=%0d", req_index);
                // synthesis translate_on
            end
        end
    end

    always @* begin
        if (rsp_valid && rsp_index_in_range) begin
            w_re_bus[0*W_BITS +: W_BITS] = w_re_b0_dout;
            w_im_bus[0*W_BITS +: W_BITS] = w_im_b0_dout;
            w_re_bus[1*W_BITS +: W_BITS] = w_re_b1_dout;
            w_im_bus[1*W_BITS +: W_BITS] = w_im_b1_dout;
            w_re_bus[2*W_BITS +: W_BITS] = w_re_b2_dout;
            w_im_bus[2*W_BITS +: W_BITS] = w_im_b2_dout;
            w_re_bus[3*W_BITS +: W_BITS] = w_re_b3_dout;
            w_im_bus[3*W_BITS +: W_BITS] = w_im_b3_dout;
            w_re_bus[4*W_BITS +: W_BITS] = w_re_b4_dout;
            w_im_bus[4*W_BITS +: W_BITS] = w_im_b4_dout;
            w_re_bus[5*W_BITS +: W_BITS] = w_re_b5_dout;
            w_im_bus[5*W_BITS +: W_BITS] = w_im_b5_dout;
            w_re_bus[6*W_BITS +: W_BITS] = w_re_b6_dout;
            w_im_bus[6*W_BITS +: W_BITS] = w_im_b6_dout;
        end else begin
            w_re_bus = {(7*W_BITS){1'b0}};
            w_im_bus = {(7*W_BITS){1'b0}};
        end
    end

endmodule

module dbf_w_provider_sprom #(
    parameter integer N_ELEMS = 2080,
    parameter integer ADDR_BITS = 12,
    parameter integer W_BITS = 18,
    parameter INIT_FILE = ""
) (
    input  wire                 clk,
    input  wire                 ena,
    input  wire [ADDR_BITS-1:0] addr,
    output wire [W_BITS-1:0]    dout
);

    localparam integer XPM_DEPTH = (1 << ADDR_BITS);
    localparam integer XPM_MEMORY_SIZE = XPM_DEPTH * W_BITS;

    xpm_memory_sprom #(
        .ADDR_WIDTH_A(ADDR_BITS),
        .AUTO_SLEEP_TIME(0),
        .CASCADE_HEIGHT(0),
        .ECC_MODE("no_ecc"),
        .MEMORY_INIT_FILE(INIT_FILE),
        .MEMORY_INIT_PARAM(""),
        .MEMORY_OPTIMIZATION("false"),
        .MEMORY_PRIMITIVE("block"),
        .MEMORY_SIZE(XPM_MEMORY_SIZE),
        .MESSAGE_CONTROL(0),
        .READ_DATA_WIDTH_A(W_BITS),
        .READ_LATENCY_A(1),
        .READ_RESET_VALUE_A("0"),
        .RST_MODE_A("SYNC"),
        .SIM_ASSERT_CHK(0),
        .USE_MEM_INIT(1),
        .USE_MEM_INIT_MMI(0),
        .WAKEUP_TIME("disable_sleep")
    ) u_xpm_sprom (
        .sleep(1'b0),
        .clka(clk),
        .rsta(1'b0),
        .ena(ena),
        .regcea(1'b1),
        .addra(addr),
        .injectsbiterra(1'b0),
        .injectdbiterra(1'b0),
        .douta(dout),
        .sbiterra(),
        .dbiterra()
    );

endmodule
