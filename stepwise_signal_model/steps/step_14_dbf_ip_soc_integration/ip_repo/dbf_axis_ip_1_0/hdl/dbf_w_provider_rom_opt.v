`timescale 1ns/1ps

// Step14.2a optimized W provider: 14 split ROMs, one-cycle request/response.
module dbf_w_provider_rom_opt #(
    parameter integer N_ELEMS = 2080,
    parameter integer ADDR_BITS = 12,
    parameter integer W_BITS = 18,
    parameter W_RE_B0_MAIN_FILE = "",
    parameter W_RE_B0_TAIL_FILE = "",
    parameter W_IM_B0_MAIN_FILE = "",
    parameter W_IM_B0_TAIL_FILE = "",
    parameter W_RE_B1_MAIN_FILE = "",
    parameter W_RE_B1_TAIL_FILE = "",
    parameter W_IM_B1_MAIN_FILE = "",
    parameter W_IM_B1_TAIL_FILE = "",
    parameter W_RE_B2_MAIN_FILE = "",
    parameter W_RE_B2_TAIL_FILE = "",
    parameter W_IM_B2_MAIN_FILE = "",
    parameter W_IM_B2_TAIL_FILE = "",
    parameter W_RE_B3_MAIN_FILE = "",
    parameter W_RE_B3_TAIL_FILE = "",
    parameter W_IM_B3_MAIN_FILE = "",
    parameter W_IM_B3_TAIL_FILE = "",
    parameter W_RE_B4_MAIN_FILE = "",
    parameter W_RE_B4_TAIL_FILE = "",
    parameter W_IM_B4_MAIN_FILE = "",
    parameter W_IM_B4_TAIL_FILE = "",
    parameter W_RE_B5_MAIN_FILE = "",
    parameter W_RE_B5_TAIL_FILE = "",
    parameter W_IM_B5_MAIN_FILE = "",
    parameter W_IM_B5_TAIL_FILE = "",
    parameter W_RE_B6_MAIN_FILE = "",
    parameter W_RE_B6_TAIL_FILE = "",
    parameter W_IM_B6_MAIN_FILE = "",
    parameter W_IM_B6_TAIL_FILE = ""
) (
    input  wire                       clk,
    input  wire                       rst,
    input  wire                       req_valid,
    input  wire [ADDR_BITS-1:0]       req_index,
    output reg                        rsp_valid,
    output wire signed [7*W_BITS-1:0] w_re_bus,
    output wire signed [7*W_BITS-1:0] w_im_bus
);

    wire in_range;
    wire signed [W_BITS-1:0] w_re0;
    wire signed [W_BITS-1:0] w_im0;
    wire signed [W_BITS-1:0] w_re1;
    wire signed [W_BITS-1:0] w_im1;
    wire signed [W_BITS-1:0] w_re2;
    wire signed [W_BITS-1:0] w_im2;
    wire signed [W_BITS-1:0] w_re3;
    wire signed [W_BITS-1:0] w_im3;
    wire signed [W_BITS-1:0] w_re4;
    wire signed [W_BITS-1:0] w_im4;
    wire signed [W_BITS-1:0] w_re5;
    wire signed [W_BITS-1:0] w_im5;
    wire signed [W_BITS-1:0] w_re6;
    wire signed [W_BITS-1:0] w_im6;
    localparam [ADDR_BITS-1:0] N_ELEMS_ADDR = N_ELEMS;

    assign in_range = (req_index < N_ELEMS_ADDR);

    always @(posedge clk) begin
        if (rst) begin
            rsp_valid <= 1'b0;
        end else begin
            rsp_valid <= req_valid;
        end
    end

    dbf_w_rom18_split #(.W_BITS(W_BITS), .ADDR_BITS(ADDR_BITS), .MAIN_FILE(W_RE_B0_MAIN_FILE), .TAIL_FILE(W_RE_B0_TAIL_FILE)) u_re0 (.clk(clk), .rst(rst), .rd_en(req_valid), .addr(req_index), .rd_data(w_re0));
    dbf_w_rom18_split #(.W_BITS(W_BITS), .ADDR_BITS(ADDR_BITS), .MAIN_FILE(W_IM_B0_MAIN_FILE), .TAIL_FILE(W_IM_B0_TAIL_FILE)) u_im0 (.clk(clk), .rst(rst), .rd_en(req_valid), .addr(req_index), .rd_data(w_im0));
    dbf_w_rom18_split #(.W_BITS(W_BITS), .ADDR_BITS(ADDR_BITS), .MAIN_FILE(W_RE_B1_MAIN_FILE), .TAIL_FILE(W_RE_B1_TAIL_FILE)) u_re1 (.clk(clk), .rst(rst), .rd_en(req_valid), .addr(req_index), .rd_data(w_re1));
    dbf_w_rom18_split #(.W_BITS(W_BITS), .ADDR_BITS(ADDR_BITS), .MAIN_FILE(W_IM_B1_MAIN_FILE), .TAIL_FILE(W_IM_B1_TAIL_FILE)) u_im1 (.clk(clk), .rst(rst), .rd_en(req_valid), .addr(req_index), .rd_data(w_im1));
    dbf_w_rom18_split #(.W_BITS(W_BITS), .ADDR_BITS(ADDR_BITS), .MAIN_FILE(W_RE_B2_MAIN_FILE), .TAIL_FILE(W_RE_B2_TAIL_FILE)) u_re2 (.clk(clk), .rst(rst), .rd_en(req_valid), .addr(req_index), .rd_data(w_re2));
    dbf_w_rom18_split #(.W_BITS(W_BITS), .ADDR_BITS(ADDR_BITS), .MAIN_FILE(W_IM_B2_MAIN_FILE), .TAIL_FILE(W_IM_B2_TAIL_FILE)) u_im2 (.clk(clk), .rst(rst), .rd_en(req_valid), .addr(req_index), .rd_data(w_im2));
    dbf_w_rom18_split #(.W_BITS(W_BITS), .ADDR_BITS(ADDR_BITS), .MAIN_FILE(W_RE_B3_MAIN_FILE), .TAIL_FILE(W_RE_B3_TAIL_FILE)) u_re3 (.clk(clk), .rst(rst), .rd_en(req_valid), .addr(req_index), .rd_data(w_re3));
    dbf_w_rom18_split #(.W_BITS(W_BITS), .ADDR_BITS(ADDR_BITS), .MAIN_FILE(W_IM_B3_MAIN_FILE), .TAIL_FILE(W_IM_B3_TAIL_FILE)) u_im3 (.clk(clk), .rst(rst), .rd_en(req_valid), .addr(req_index), .rd_data(w_im3));
    dbf_w_rom18_split #(.W_BITS(W_BITS), .ADDR_BITS(ADDR_BITS), .MAIN_FILE(W_RE_B4_MAIN_FILE), .TAIL_FILE(W_RE_B4_TAIL_FILE)) u_re4 (.clk(clk), .rst(rst), .rd_en(req_valid), .addr(req_index), .rd_data(w_re4));
    dbf_w_rom18_split #(.W_BITS(W_BITS), .ADDR_BITS(ADDR_BITS), .MAIN_FILE(W_IM_B4_MAIN_FILE), .TAIL_FILE(W_IM_B4_TAIL_FILE)) u_im4 (.clk(clk), .rst(rst), .rd_en(req_valid), .addr(req_index), .rd_data(w_im4));
    dbf_w_rom18_split #(.W_BITS(W_BITS), .ADDR_BITS(ADDR_BITS), .MAIN_FILE(W_RE_B5_MAIN_FILE), .TAIL_FILE(W_RE_B5_TAIL_FILE)) u_re5 (.clk(clk), .rst(rst), .rd_en(req_valid), .addr(req_index), .rd_data(w_re5));
    dbf_w_rom18_split #(.W_BITS(W_BITS), .ADDR_BITS(ADDR_BITS), .MAIN_FILE(W_IM_B5_MAIN_FILE), .TAIL_FILE(W_IM_B5_TAIL_FILE)) u_im5 (.clk(clk), .rst(rst), .rd_en(req_valid), .addr(req_index), .rd_data(w_im5));
    dbf_w_rom18_split #(.W_BITS(W_BITS), .ADDR_BITS(ADDR_BITS), .MAIN_FILE(W_RE_B6_MAIN_FILE), .TAIL_FILE(W_RE_B6_TAIL_FILE)) u_re6 (.clk(clk), .rst(rst), .rd_en(req_valid), .addr(req_index), .rd_data(w_re6));
    dbf_w_rom18_split #(.W_BITS(W_BITS), .ADDR_BITS(ADDR_BITS), .MAIN_FILE(W_IM_B6_MAIN_FILE), .TAIL_FILE(W_IM_B6_TAIL_FILE)) u_im6 (.clk(clk), .rst(rst), .rd_en(req_valid), .addr(req_index), .rd_data(w_im6));

    assign w_re_bus[0*W_BITS +: W_BITS] = in_range ? w_re0 : {W_BITS{1'b0}};
    assign w_im_bus[0*W_BITS +: W_BITS] = in_range ? w_im0 : {W_BITS{1'b0}};
    assign w_re_bus[1*W_BITS +: W_BITS] = in_range ? w_re1 : {W_BITS{1'b0}};
    assign w_im_bus[1*W_BITS +: W_BITS] = in_range ? w_im1 : {W_BITS{1'b0}};
    assign w_re_bus[2*W_BITS +: W_BITS] = in_range ? w_re2 : {W_BITS{1'b0}};
    assign w_im_bus[2*W_BITS +: W_BITS] = in_range ? w_im2 : {W_BITS{1'b0}};
    assign w_re_bus[3*W_BITS +: W_BITS] = in_range ? w_re3 : {W_BITS{1'b0}};
    assign w_im_bus[3*W_BITS +: W_BITS] = in_range ? w_im3 : {W_BITS{1'b0}};
    assign w_re_bus[4*W_BITS +: W_BITS] = in_range ? w_re4 : {W_BITS{1'b0}};
    assign w_im_bus[4*W_BITS +: W_BITS] = in_range ? w_im4 : {W_BITS{1'b0}};
    assign w_re_bus[5*W_BITS +: W_BITS] = in_range ? w_re5 : {W_BITS{1'b0}};
    assign w_im_bus[5*W_BITS +: W_BITS] = in_range ? w_im5 : {W_BITS{1'b0}};
    assign w_re_bus[6*W_BITS +: W_BITS] = in_range ? w_re6 : {W_BITS{1'b0}};
    assign w_im_bus[6*W_BITS +: W_BITS] = in_range ? w_im6 : {W_BITS{1'b0}};

endmodule
