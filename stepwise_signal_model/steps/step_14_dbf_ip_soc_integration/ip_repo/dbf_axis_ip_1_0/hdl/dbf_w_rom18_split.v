`timescale 1ns/1ps

// Step14.2a 2080x18 ROM split into 2048 block entries and 32 LUT tail entries.
module dbf_w_rom18_split #(
    parameter integer W_BITS = 18,
    parameter integer MAIN_DEPTH = 2048,
    parameter integer TAIL_DEPTH = 32,
    parameter integer ADDR_BITS = 12,
    parameter MAIN_FILE = "",
    parameter TAIL_FILE = ""
) (
    input  wire                     clk,
    input  wire                     rst,
    input  wire                     rd_en,
    input  wire [ADDR_BITS-1:0]     addr,
    output wire signed [W_BITS-1:0] rd_data
);

    (* rom_style = "distributed" *) reg signed [W_BITS-1:0] tail_mem [0:TAIL_DEPTH-1];

    localparam [ADDR_BITS-1:0] MAIN_DEPTH_ADDR = MAIN_DEPTH;
    localparam integer MAIN_ADDR_BITS = 11;
    localparam integer MAIN_MEMORY_SIZE = MAIN_DEPTH * W_BITS;

    wire use_tail;
    wire [ADDR_BITS-1:0] tail_addr_wide;
    wire [4:0] tail_addr;
    wire [W_BITS-1:0] main_dout;
    reg signed [W_BITS-1:0] tail_dout;
    reg use_tail_q;

    assign use_tail = (addr >= MAIN_DEPTH_ADDR);
    assign tail_addr_wide = addr - MAIN_DEPTH_ADDR;
    assign tail_addr = tail_addr_wide[4:0];
    assign rd_data = use_tail_q ? tail_dout : main_dout;

    initial begin
        if (TAIL_FILE != "") begin
            $readmemh(TAIL_FILE, tail_mem);
        end
    end

    xpm_memory_sprom #(
        .ADDR_WIDTH_A(MAIN_ADDR_BITS),
        .AUTO_SLEEP_TIME(0),
        .CASCADE_HEIGHT(0),
        .ECC_MODE("no_ecc"),
        .MEMORY_INIT_FILE(MAIN_FILE),
        .MEMORY_INIT_PARAM(""),
        .MEMORY_OPTIMIZATION("false"),
        .MEMORY_PRIMITIVE("block"),
        .MEMORY_SIZE(MAIN_MEMORY_SIZE),
        .MESSAGE_CONTROL(0),
        .READ_DATA_WIDTH_A(W_BITS),
        .READ_LATENCY_A(1),
        .READ_RESET_VALUE_A("0"),
        .RST_MODE_A("SYNC"),
        .SIM_ASSERT_CHK(0),
        .USE_MEM_INIT(1),
        .USE_MEM_INIT_MMI(0),
        .WAKEUP_TIME("disable_sleep")
    ) u_main_sprom (
        .sleep(1'b0),
        .clka(clk),
        .rsta(rst),
        .ena(rd_en && !use_tail),
        .regcea(1'b1),
        .addra(addr[MAIN_ADDR_BITS-1:0]),
        .injectsbiterra(1'b0),
        .injectdbiterra(1'b0),
        .douta(main_dout),
        .sbiterra(),
        .dbiterra()
    );

    always @(posedge clk) begin
        if (rst) begin
            tail_dout <= {W_BITS{1'b0}};
            use_tail_q <= 1'b0;
        end else if (rd_en) begin
            use_tail_q <= use_tail && (tail_addr_wide < TAIL_DEPTH);
            if (use_tail && (tail_addr_wide < TAIL_DEPTH)) begin
                tail_dout <= tail_mem[tail_addr];
            end else begin
                tail_dout <= {W_BITS{1'b0}};
            end
        end
    end

endmodule
