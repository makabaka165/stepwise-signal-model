`timescale 1ns/1ps

// Step14.2a AXI4-Stream datapath using the integration-specific pipelined DBF core.
module dbf_axis_datapath_pipe #(
    parameter integer N_ELEMS = 2080,
    parameter integer B_BEAMS = 7,
    parameter integer W_BITS = 18,
    parameter integer Y_BITS = 16,
    parameter integer ACC_BITS = 48,
    parameter integer Z_BITS = 24,
    parameter integer SHIFT_BITS = 20,
    parameter integer ADDR_BITS = 12
) (
    input  wire                         aclk,
    input  wire                         aresetn,

    input  wire [31:0]                  s_axis_y_tdata,
    input  wire [3:0]                   s_axis_y_tkeep,
    input  wire                         s_axis_y_tvalid,
    output wire                         s_axis_y_tready,
    input  wire                         s_axis_y_tlast,

    output wire                         w_req_valid,
    output wire [ADDR_BITS-1:0]         w_req_index,
    input  wire                         w_rsp_valid,
    input  wire signed [B_BEAMS*W_BITS-1:0] w_re_bus,
    input  wire signed [B_BEAMS*W_BITS-1:0] w_im_bus,

    output wire [63:0]                  m_axis_z_tdata,
    output wire [7:0]                   m_axis_z_tkeep,
    output wire                         m_axis_z_tvalid,
    input  wire                         m_axis_z_tready,
    output wire                         m_axis_z_tlast,

    output wire                         status_busy,
    output reg  [31:0]                  status_frame_count,
    output reg                          status_protocol_error,
    output reg                          status_early_tlast,
    output reg                          status_missing_tlast,
    output reg                          status_bad_tkeep,
    output reg                          status_clip_seen,
    output reg                          status_overflow_seen,
    output wire [ADDR_BITS-1:0]         debug_element_index,
    output wire [ADDR_BITS-1:0]         debug_w_req_index,
    output wire                         debug_sample_accept
);

    localparam [1:0] ST_RX    = 2'd0;
    localparam [1:0] ST_DRAIN = 2'd1;
    localparam [1:0] ST_TX    = 2'd2;

    wire rst;
    reg [1:0] state;
    reg [ADDR_BITS-1:0] element_index;
    wire expected_last;
    wire sample_accept;

    reg pipe_y_valid;
    reg pipe_expected_last;
    reg signed [Y_BITS-1:0] pipe_y_re;
    reg signed [Y_BITS-1:0] pipe_y_im;

    wire core_in_valid;
    wire core_in_last;
    wire core_out_valid;
    wire [B_BEAMS-1:0] lane_out_valid;
    wire signed [B_BEAMS*ACC_BITS-1:0] acc_re_bus;
    wire signed [B_BEAMS*ACC_BITS-1:0] acc_im_bus;
    wire signed [B_BEAMS*Z_BITS-1:0] z_re_bus;
    wire signed [B_BEAMS*Z_BITS-1:0] z_im_bus;
    wire [B_BEAMS-1:0] clip_re_bus;
    wire [B_BEAMS-1:0] clip_im_bus;
    wire [B_BEAMS-1:0] overflow_re_bus;
    wire [B_BEAMS-1:0] overflow_im_bus;

    reg serializer_load_valid;
    wire serializer_busy;
    wire serializer_done_pulse;
    wire [2:0] serializer_beam_id;

    assign rst = !aresetn;
    assign expected_last = (element_index == (N_ELEMS - 1));
    assign s_axis_y_tready = aresetn && (state == ST_RX);
    assign sample_accept = s_axis_y_tvalid && s_axis_y_tready;
    assign w_req_valid = sample_accept;
    assign w_req_index = element_index;
    assign core_in_valid = pipe_y_valid && w_rsp_valid;
    assign core_in_last = pipe_expected_last;
    assign status_busy = (state != ST_RX) || serializer_busy;
    assign debug_element_index = element_index;
    assign debug_w_req_index = w_req_index;
    assign debug_sample_accept = sample_accept;

    dbf_core_z24_bparallel_pipe #(
        .B_BEAMS(B_BEAMS),
        .W_BITS(W_BITS),
        .Y_BITS(Y_BITS),
        .ACC_BITS(ACC_BITS),
        .Z_BITS(Z_BITS),
        .SHIFT_BITS(SHIFT_BITS)
    ) u_core (
        .clk(aclk),
        .rst(rst),
        .in_valid(core_in_valid),
        .in_last(core_in_last),
        .w_re_bus(w_re_bus),
        .w_im_bus(w_im_bus),
        .y_re(pipe_y_re),
        .y_im(pipe_y_im),
        .out_valid(core_out_valid),
        .lane_out_valid(lane_out_valid),
        .acc_re_bus(acc_re_bus),
        .acc_im_bus(acc_im_bus),
        .z_re_bus(z_re_bus),
        .z_im_bus(z_im_bus),
        .clip_re_bus(clip_re_bus),
        .clip_im_bus(clip_im_bus),
        .overflow_re_bus(overflow_re_bus),
        .overflow_im_bus(overflow_im_bus)
    );

    dbf_axis_z_serializer #(
        .B_BEAMS(B_BEAMS),
        .Z_BITS(Z_BITS)
    ) u_serializer (
        .clk(aclk),
        .rst(rst),
        .load_valid(serializer_load_valid),
        .z_re_bus(z_re_bus),
        .z_im_bus(z_im_bus),
        .clip_re_bus(clip_re_bus),
        .clip_im_bus(clip_im_bus),
        .overflow_re_bus(overflow_re_bus),
        .overflow_im_bus(overflow_im_bus),
        .m_axis_z_tdata(m_axis_z_tdata),
        .m_axis_z_tkeep(m_axis_z_tkeep),
        .m_axis_z_tvalid(m_axis_z_tvalid),
        .m_axis_z_tready(m_axis_z_tready),
        .m_axis_z_tlast(m_axis_z_tlast),
        .busy(serializer_busy),
        .done_pulse(serializer_done_pulse),
        .current_beam_id(serializer_beam_id)
    );

    always @(posedge aclk) begin
        if (rst) begin
            state <= ST_RX;
            element_index <= {ADDR_BITS{1'b0}};
            pipe_y_valid <= 1'b0;
            pipe_expected_last <= 1'b0;
            pipe_y_re <= {Y_BITS{1'b0}};
            pipe_y_im <= {Y_BITS{1'b0}};
            serializer_load_valid <= 1'b0;
            status_frame_count <= 32'd0;
            status_protocol_error <= 1'b0;
            status_early_tlast <= 1'b0;
            status_missing_tlast <= 1'b0;
            status_bad_tkeep <= 1'b0;
            status_clip_seen <= 1'b0;
            status_overflow_seen <= 1'b0;
        end else begin
            serializer_load_valid <= 1'b0;
            pipe_y_valid <= sample_accept;

            if (sample_accept) begin
                pipe_y_re <= s_axis_y_tdata[15:0];
                pipe_y_im <= s_axis_y_tdata[31:16];
                pipe_expected_last <= expected_last;

                if (s_axis_y_tkeep != 4'hF) begin
                    status_bad_tkeep <= 1'b1;
                end
                if (s_axis_y_tlast && !expected_last) begin
                    status_early_tlast <= 1'b1;
                end
                if (!s_axis_y_tlast && expected_last) begin
                    status_missing_tlast <= 1'b1;
                end

                if (expected_last) begin
                    element_index <= {ADDR_BITS{1'b0}};
                    state <= ST_DRAIN;
                end else begin
                    element_index <= element_index + {{(ADDR_BITS-1){1'b0}}, 1'b1};
                end
            end

            if (status_early_tlast || status_missing_tlast || status_bad_tkeep ||
                    (sample_accept && ((s_axis_y_tkeep != 4'hF) ||
                    (s_axis_y_tlast && !expected_last) || (!s_axis_y_tlast && expected_last)))) begin
                status_protocol_error <= 1'b1;
            end

            case (state)
                ST_RX: begin
                    if (sample_accept && expected_last) begin
                        state <= ST_DRAIN;
                    end
                end
                ST_DRAIN: begin
                    if (core_out_valid) begin
                        serializer_load_valid <= 1'b1;
                        if (|clip_re_bus || |clip_im_bus) begin
                            status_clip_seen <= 1'b1;
                        end
                        if (|overflow_re_bus || |overflow_im_bus) begin
                            status_overflow_seen <= 1'b1;
                        end
                        state <= ST_TX;
                    end
                end
                ST_TX: begin
                    if (serializer_done_pulse) begin
                        status_frame_count <= status_frame_count + 32'd1;
                        element_index <= {ADDR_BITS{1'b0}};
                        state <= ST_RX;
                    end
                end
                default: begin
                    state <= ST_RX;
                end
            endcase
        end
    end

endmodule
