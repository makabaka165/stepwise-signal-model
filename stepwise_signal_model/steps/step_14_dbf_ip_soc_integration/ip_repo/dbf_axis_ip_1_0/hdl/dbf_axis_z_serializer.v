`timescale 1ns/1ps

// Serialize one B=7 Step13 Z result frame onto AXI4-Stream.
module dbf_axis_z_serializer #(
    parameter integer B_BEAMS = 7,
    parameter integer Z_BITS = 24
) (
    input  wire                         clk,
    input  wire                         rst,
    input  wire                         load_valid,
    input  wire signed [B_BEAMS*Z_BITS-1:0] z_re_bus,
    input  wire signed [B_BEAMS*Z_BITS-1:0] z_im_bus,
    input  wire [B_BEAMS-1:0]           clip_re_bus,
    input  wire [B_BEAMS-1:0]           clip_im_bus,
    input  wire [B_BEAMS-1:0]           overflow_re_bus,
    input  wire [B_BEAMS-1:0]           overflow_im_bus,
    output reg  [63:0]                  m_axis_z_tdata,
    output wire [7:0]                   m_axis_z_tkeep,
    output reg                          m_axis_z_tvalid,
    input  wire                         m_axis_z_tready,
    output wire                         m_axis_z_tlast,
    output wire                         busy,
    output reg                          done_pulse,
    output reg  [2:0]                   current_beam_id
);

    reg signed [B_BEAMS*Z_BITS-1:0] z_re_hold;
    reg signed [B_BEAMS*Z_BITS-1:0] z_im_hold;
    reg [B_BEAMS-1:0] clip_re_hold;
    reg [B_BEAMS-1:0] clip_im_hold;
    reg [B_BEAMS-1:0] overflow_re_hold;
    reg [B_BEAMS-1:0] overflow_im_hold;

    wire fire;
    wire last_beam;
    wire [63:0] packed_current;

    assign fire = m_axis_z_tvalid && m_axis_z_tready;
    assign last_beam = (current_beam_id == 3'd6);
    assign busy = m_axis_z_tvalid;
    assign m_axis_z_tkeep = 8'hFF;
    assign m_axis_z_tlast = last_beam;

    assign packed_current = {
        9'd0,
        current_beam_id,
        overflow_im_hold[current_beam_id],
        overflow_re_hold[current_beam_id],
        clip_im_hold[current_beam_id],
        clip_re_hold[current_beam_id],
        z_im_hold[current_beam_id*Z_BITS +: Z_BITS],
        z_re_hold[current_beam_id*Z_BITS +: Z_BITS]
    };

    always @(posedge clk) begin
        if (rst) begin
            z_re_hold       <= {(B_BEAMS*Z_BITS){1'b0}};
            z_im_hold       <= {(B_BEAMS*Z_BITS){1'b0}};
            clip_re_hold    <= {B_BEAMS{1'b0}};
            clip_im_hold    <= {B_BEAMS{1'b0}};
            overflow_re_hold <= {B_BEAMS{1'b0}};
            overflow_im_hold <= {B_BEAMS{1'b0}};
            m_axis_z_tdata  <= 64'd0;
            m_axis_z_tvalid <= 1'b0;
            done_pulse      <= 1'b0;
            current_beam_id <= 3'd0;
        end else begin
            done_pulse <= 1'b0;

            if (!m_axis_z_tvalid && load_valid) begin
                z_re_hold        <= z_re_bus;
                z_im_hold        <= z_im_bus;
                clip_re_hold     <= clip_re_bus;
                clip_im_hold     <= clip_im_bus;
                overflow_re_hold <= overflow_re_bus;
                overflow_im_hold <= overflow_im_bus;
                current_beam_id  <= 3'd0;
                m_axis_z_tdata   <= {
                    9'd0,
                    3'd0,
                    overflow_im_bus[0],
                    overflow_re_bus[0],
                    clip_im_bus[0],
                    clip_re_bus[0],
                    z_im_bus[0*Z_BITS +: Z_BITS],
                    z_re_bus[0*Z_BITS +: Z_BITS]
                };
                m_axis_z_tvalid <= 1'b1;
            end else if (m_axis_z_tvalid) begin
                if (load_valid) begin
                    // synthesis translate_off
                    $display("WARNING: dbf_axis_z_serializer load_valid while busy");
                    // synthesis translate_on
                end
                if (fire) begin
                    if (last_beam) begin
                        m_axis_z_tvalid <= 1'b0;
                        done_pulse <= 1'b1;
                    end else begin
                        current_beam_id <= current_beam_id + 3'd1;
                        m_axis_z_tdata <= {
                            9'd0,
                            current_beam_id + 3'd1,
                            overflow_im_hold[current_beam_id + 3'd1],
                            overflow_re_hold[current_beam_id + 3'd1],
                            clip_im_hold[current_beam_id + 3'd1],
                            clip_re_hold[current_beam_id + 3'd1],
                            z_im_hold[(current_beam_id + 3'd1)*Z_BITS +: Z_BITS],
                            z_re_hold[(current_beam_id + 3'd1)*Z_BITS +: Z_BITS]
                        };
                    end
                end else begin
                    m_axis_z_tdata <= packed_current;
                end
            end
        end
    end

endmodule
