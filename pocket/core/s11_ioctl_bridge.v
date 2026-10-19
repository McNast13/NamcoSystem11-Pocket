// GPL-2.0-or-later. APF bridge data-slot writes -> the MiSTer hps_io "ioctl" download stream the System 11 core already consumes.
//
// The System 11 core (SYSTEM11.sv) loads its ROMs, C76 BIOS, config and EEPROM from ioctl_download/index/addr/dout/wr (16-bit
// words, WIDE mode) and paces the host with ioctl_wait. This module reproduces that stream from the Pocket bridge so the core's
// own, already-verified download logic is reused unchanged. The bridge cannot be stalled: a dual-clock FIFO absorbs bursts and
// ld_overflow latches if it ever fills.
//
//   bridge_addr[31:28] == 0, bridge_addr[27:24] = window (see s11_loader.v / docs/LOADER.md), bridge_addr[23:2] = word offset
//   window -> ioctl_index: 0->0 program, 1->1 config, 2->2 fixed ROM, 3->3 banked ROM, 4->3 (+16 MB), 6->6 SPROG, 7->7 wave,
//                          8->8 C76 BIOS, 9->9 EEPROM; other windows are dropped
//   Each 32-bit word becomes two ioctl_wr pulses (low half at addr, high half at addr+2), then the bridge waits for ioctl_wait
//   to fall. ioctl_download goes low for GAP clocks between files (index changes) and after IDLE_END clocks without data.
`default_nettype none
module s11_ioctl_bridge #(
    parameter AW = 10,
    parameter integer GAP = 24,
    parameter integer IDLE_END = 4096
) (
    input  wire        clk_74a,
    input  wire        bridge_wr,
    input  wire [31:0] bridge_addr,
    input  wire [31:0] bridge_wr_data,

    input  wire        clk,                 // core clock (clk_1x); same domain as ioctl_wait
    input  wire        rst,
    output reg         ioctl_download,
    output reg         ioctl_wr,
    output reg  [7:0]  ioctl_index,
    output reg  [26:0] ioctl_addr,
    output reg  [15:0] ioctl_dout,
    input  wire        ioctl_wait,

    output wire        ld_busy,
    output wire        ld_overflow
);
    // ---------------------------------------------------------------- write side (clk_74a)
    reg prev_wr = 1'b0;
    always @(posedge clk_74a) prev_wr <= bridge_wr;
    wire hit = bridge_wr & ~prev_wr & (bridge_addr[31:28] == 4'h0);

    reg  [AW:0] wptr_bin = 0, wptr_gray = 0;
    reg  [AW:0] rptr_bin = 0, rptr_gray = 0;
    reg  [AW:0] rptr_gray_w1 = 0, rptr_gray_w2 = 0;
    wire [AW:0] wptr_next = wptr_bin + 1'b1;
    function [AW:0] g2b(input [AW:0] g);
        integer i;
        begin
            g2b[AW] = g[AW];
            for (i = AW - 1; i >= 0; i = i - 1) g2b[i] = g2b[i+1] ^ g[i];
        end
    endfunction
    wire [AW:0] rptr_bin_w = g2b(rptr_gray_w2);
    wire full = (wptr_bin[AW-1:0] == rptr_bin_w[AW-1:0]) && (wptr_bin[AW] != rptr_bin_w[AW]);

    (* ramstyle = "M10K" *) reg [57:0] ram [0:(1<<AW)-1];
    reg overflow_r = 1'b0;
    assign ld_overflow = overflow_r;

    always @(posedge clk_74a) begin
        rptr_gray_w1 <= rptr_gray;
        rptr_gray_w2 <= rptr_gray_w1;
        if (hit) begin
            if (full) overflow_r <= 1'b1;
            else begin
                ram[wptr_bin[AW-1:0]] <= {bridge_addr[27:24], bridge_addr[23:2], bridge_wr_data};
                wptr_bin  <= wptr_next;
                wptr_gray <= wptr_next ^ (wptr_next >> 1);
            end
        end
    end

    // ---------------------------------------------------------------- read side (clk)
    reg [AW:0] wptr_gray_r1 = 0, wptr_gray_r2 = 0;
    always @(posedge clk) begin
        wptr_gray_r1 <= wptr_gray;
        wptr_gray_r2 <= wptr_gray_r1;
    end
    wire empty = (rptr_gray == wptr_gray_r2);

    localparam S_IDLE = 4'd0, S_RD = 4'd1, S_DEC = 4'd2, S_GAPW = 4'd3, S_LO = 4'd4, S_HI = 4'd5, S_SETTLE = 4'd6, S_WAIT = 4'd7;
    reg [3:0]  state = S_IDLE;
    reg [57:0] q;
    reg [15:0] gap_cnt = 0;
    reg [15:0] idle_cnt = 0;
    reg [7:0]  pend_index;
    reg [26:0] pend_addr;
    reg [15:0] hi_half;
    reg        valid_win;

    wire [3:0]  win = q[57:54];
    wire [23:0] boff = {q[53:32], 2'b00};
    wire [31:0] wdat = q[31:0];

    assign ld_busy = ioctl_download | ~empty | (state != S_IDLE);

    always @(posedge clk) begin
        ioctl_wr <= 1'b0;
        if (rst) begin
            state <= S_IDLE; ioctl_download <= 1'b0; rptr_bin <= 0; rptr_gray <= 0; idle_cnt <= 0; ioctl_index <= 8'hFF;
        end else begin
            case (state)
                S_IDLE: begin
                    if (!empty) begin
                        q <= ram[rptr_bin[AW-1:0]];
                        rptr_bin  <= rptr_bin + 1'b1;
                        rptr_gray <= (rptr_bin + 1'b1) ^ ((rptr_bin + 1'b1) >> 1);
                        idle_cnt <= 0;
                        state <= S_RD;
                    end else if (ioctl_download) begin
                        idle_cnt <= idle_cnt + 1'b1;
                        if (idle_cnt == IDLE_END) begin ioctl_download <= 1'b0; ioctl_index <= 8'hFF; idle_cnt <= 0; end
                    end
                end
                S_RD: state <= S_DEC;                               // q valid
                S_DEC: begin
                    valid_win = 1'b1;
                    case (win)
                        4'd0: begin pend_index <= 8'd0; pend_addr <= {3'b0, boff};            end
                        4'd1: begin pend_index <= 8'd1; pend_addr <= {3'b0, boff};            end
                        4'd2: begin pend_index <= 8'd2; pend_addr <= {3'b0, boff};            end
                        4'd3: begin pend_index <= 8'd3; pend_addr <= {3'b0, boff};            end
                        4'd4: begin pend_index <= 8'd3; pend_addr <= 27'h1000000 + {3'b0, boff}; end
                        4'd6: begin pend_index <= 8'd6; pend_addr <= {3'b0, boff};            end
                        4'd7: begin pend_index <= 8'd7; pend_addr <= {3'b0, boff};            end
                        4'd8: begin pend_index <= 8'd8; pend_addr <= {3'b0, boff};            end
                        4'd9: begin pend_index <= 8'd9; pend_addr <= {3'b0, boff};            end
                        default: valid_win = 1'b0;
                    endcase
                    if (!valid_win) state <= S_IDLE;
                    else if (ioctl_download && ioctl_index == (win == 4'd4 ? 8'd3 : {4'd0, win})) state <= S_LO;
                    else begin
                        // new file: drop ioctl_download for GAP clocks (as hps_io does between files), then raise it with the new index
                        ioctl_download <= 1'b0; gap_cnt <= 0; state <= S_GAPW;
                    end
                end
                S_GAPW: begin
                    gap_cnt <= gap_cnt + 1'b1;
                    if (gap_cnt == GAP) begin
                        ioctl_index <= pend_index; ioctl_download <= 1'b1; gap_cnt <= 0; state <= S_SETTLE;
                    end
                end
                S_SETTLE: begin                                      // let the core's registered *_download flags follow the index
                    gap_cnt <= gap_cnt + 1'b1;
                    if (gap_cnt == 8) state <= S_LO;
                end
                S_LO: begin
                    ioctl_addr <= pend_addr; ioctl_dout <= wdat[15:0]; ioctl_wr <= 1'b1; hi_half <= wdat[31:16]; state <= S_HI;
                end
                S_HI: begin
                    ioctl_addr <= pend_addr + 27'd2; ioctl_dout <= hi_half; ioctl_wr <= 1'b1; gap_cnt <= 0; state <= S_WAIT;
                end
                S_WAIT: begin                                        // the core raises ioctl_wait one clk after the word's last half
                    gap_cnt <= gap_cnt + 1'b1;
                    if (gap_cnt >= 3 && !ioctl_wait) state <= S_IDLE;
                end
                default: state <= S_IDLE;
            endcase
        end
    end
endmodule
`default_nettype wire
