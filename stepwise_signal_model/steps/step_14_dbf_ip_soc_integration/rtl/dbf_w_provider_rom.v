`timescale 1ns/1ps

// Step14.1 replaceable W provider ROM model.
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

    reg signed [W_BITS-1:0] w_re_b0 [0:N_ELEMS-1];
    reg signed [W_BITS-1:0] w_im_b0 [0:N_ELEMS-1];
    reg signed [W_BITS-1:0] w_re_b1 [0:N_ELEMS-1];
    reg signed [W_BITS-1:0] w_im_b1 [0:N_ELEMS-1];
    reg signed [W_BITS-1:0] w_re_b2 [0:N_ELEMS-1];
    reg signed [W_BITS-1:0] w_im_b2 [0:N_ELEMS-1];
    reg signed [W_BITS-1:0] w_re_b3 [0:N_ELEMS-1];
    reg signed [W_BITS-1:0] w_im_b3 [0:N_ELEMS-1];
    reg signed [W_BITS-1:0] w_re_b4 [0:N_ELEMS-1];
    reg signed [W_BITS-1:0] w_im_b4 [0:N_ELEMS-1];
    reg signed [W_BITS-1:0] w_re_b5 [0:N_ELEMS-1];
    reg signed [W_BITS-1:0] w_im_b5 [0:N_ELEMS-1];
    reg signed [W_BITS-1:0] w_re_b6 [0:N_ELEMS-1];
    reg signed [W_BITS-1:0] w_im_b6 [0:N_ELEMS-1];

    initial begin
        if (W_RE_B0_FILE != "") $readmemh(W_RE_B0_FILE, w_re_b0);
        if (W_IM_B0_FILE != "") $readmemh(W_IM_B0_FILE, w_im_b0);
        if (W_RE_B1_FILE != "") $readmemh(W_RE_B1_FILE, w_re_b1);
        if (W_IM_B1_FILE != "") $readmemh(W_IM_B1_FILE, w_im_b1);
        if (W_RE_B2_FILE != "") $readmemh(W_RE_B2_FILE, w_re_b2);
        if (W_IM_B2_FILE != "") $readmemh(W_IM_B2_FILE, w_im_b2);
        if (W_RE_B3_FILE != "") $readmemh(W_RE_B3_FILE, w_re_b3);
        if (W_IM_B3_FILE != "") $readmemh(W_IM_B3_FILE, w_im_b3);
        if (W_RE_B4_FILE != "") $readmemh(W_RE_B4_FILE, w_re_b4);
        if (W_IM_B4_FILE != "") $readmemh(W_IM_B4_FILE, w_im_b4);
        if (W_RE_B5_FILE != "") $readmemh(W_RE_B5_FILE, w_re_b5);
        if (W_IM_B5_FILE != "") $readmemh(W_IM_B5_FILE, w_im_b5);
        if (W_RE_B6_FILE != "") $readmemh(W_RE_B6_FILE, w_re_b6);
        if (W_IM_B6_FILE != "") $readmemh(W_IM_B6_FILE, w_im_b6);
    end

    always @(posedge clk) begin
        if (rst) begin
            rsp_valid <= 1'b0;
            w_re_bus  <= {(7*W_BITS){1'b0}};
            w_im_bus  <= {(7*W_BITS){1'b0}};
        end else begin
            rsp_valid <= req_valid;
            if (req_valid) begin
                if (req_index < N_ELEMS) begin
                    w_re_bus[0*W_BITS +: W_BITS] <= w_re_b0[req_index];
                    w_im_bus[0*W_BITS +: W_BITS] <= w_im_b0[req_index];
                    w_re_bus[1*W_BITS +: W_BITS] <= w_re_b1[req_index];
                    w_im_bus[1*W_BITS +: W_BITS] <= w_im_b1[req_index];
                    w_re_bus[2*W_BITS +: W_BITS] <= w_re_b2[req_index];
                    w_im_bus[2*W_BITS +: W_BITS] <= w_im_b2[req_index];
                    w_re_bus[3*W_BITS +: W_BITS] <= w_re_b3[req_index];
                    w_im_bus[3*W_BITS +: W_BITS] <= w_im_b3[req_index];
                    w_re_bus[4*W_BITS +: W_BITS] <= w_re_b4[req_index];
                    w_im_bus[4*W_BITS +: W_BITS] <= w_im_b4[req_index];
                    w_re_bus[5*W_BITS +: W_BITS] <= w_re_b5[req_index];
                    w_im_bus[5*W_BITS +: W_BITS] <= w_im_b5[req_index];
                    w_re_bus[6*W_BITS +: W_BITS] <= w_re_b6[req_index];
                    w_im_bus[6*W_BITS +: W_BITS] <= w_im_b6[req_index];
                end else begin
                    w_re_bus <= {(7*W_BITS){1'b0}};
                    w_im_bus <= {(7*W_BITS){1'b0}};
                    // synthesis translate_off
                    $display("WARNING: dbf_w_provider_rom out-of-range req_index=%0d", req_index);
                    // synthesis translate_on
                end
            end
        end
    end

endmodule
