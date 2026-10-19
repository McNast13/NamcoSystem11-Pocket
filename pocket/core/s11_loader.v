// GPL-2.0-or-later. Namco System 11 data-slot loader for the Analogue Pocket.
//
// Takes the APF bridge write stream (clk_74a, 32-bit words, bridge_endian_little = 1 so byte 0 of a file is bits [7:0])
// through a dual-clock FIFO into the core clock, and demultiplexes it by data-slot window into the places the System 11
// core keeps its ROM-side state (the same destinations the MiSTer core fills from hps_io ioctl):
//
//   bridge_addr[31:28] = 0 and bridge_addr[27:24] = window:
//     0  program (4 MB MIPS program, MRA index 0)        -> mem  BIOS_START      | off[21:0]
//     1  config  (platform id, KEYCUS id, gun flag)      -> cfg_*
//     2  fixed ROM (<= 2.5 MB, MRA index 2)              -> mem  FIXEDROM_START  + off[22:0]
//     3  banked ROM, first 16 MB (MRA index 3)           -> mem  BANKEDROM_START + off[23:0]
//     4  banked ROM, second 16 MB (for 32 MB games)      -> mem  BANKEDROM_START + 16 MB + off[23:0]
//     6  C76 SPROG (256 KB)                              -> mem  SPROG_START     | off[17:0]
//     7  C352 wave ROM (<= 4 MB)                         -> mem  WAVE_START      + off[21:0]
//     8  C76 internal BIOS (16 KB)                       -> c76_* byte writes
//     9  EEPROM image (4 KB)                             -> ee_* 32-bit word writes
//   anything else is ignored (core_bridge_cmd, interact, ... live elsewhere on the bridge).
//
// The APF bridge cannot be stalled. The FIFO absorbs bursts; ld_overflow latches if it ever fills (should not happen
// as long as mem_ready keeps up with the host, ~one word per several clk_74a). mem_* is valid/ready: mem_valid stays
// high with stable mem_addr/mem_data until mem_ready is seen high.
`default_nettype none
module s11_loader #(
    parameter AW = 10,                                  // FIFO depth 2**AW words (1024 x 58 bit = 8 M10K; absorbs the C76 byte-serialiser backlog)
    parameter [26:0] BIOS_START      = 27'h0400000,
    parameter [26:0] FIXEDROM_START  = 27'h0480000,
    parameter [26:0] BANKEDROM_START = 27'h0800000,
    parameter [26:0] SPROG_START     = 27'h2800000,
    parameter [26:0] WAVE_START      = 27'h2840000
) (
    // bridge side
    input  wire        clk_74a,
    input  wire        bridge_wr,
    input  wire [31:0] bridge_addr,
    input  wire [31:0] bridge_wr_data,

    // core side
    input  wire        clk,
    input  wire        rst,                             // synchronous to clk; clears the FIFO read side and outputs

    output reg         mem_valid,
    output reg  [26:0] mem_addr,                        // byte address, 4-aligned
    output reg  [31:0] mem_data,
    input  wire        mem_ready,

    output reg         c76_wr,                          // one byte per clk
    output reg  [13:0] c76_addr,
    output reg  [7:0]  c76_data,

    output reg         ee_wr,                           // one 32-bit word
    output reg  [9:0]  ee_addr,
    output reg  [31:0] ee_data,

    output reg  [7:0]  cfg_platform,
    output reg  [7:0]  cfg_keycus,
    output reg         cfg_gun,

    output wire        ld_busy,                         // FIFO not empty or a word is being delivered
    output wire        ld_overflow                      // sticky: a bridge write found the FIFO full
);

    // ------------------------------------------------------------------ write side (clk_74a)
    reg prev_wr = 1'b0;
    always @(posedge clk_74a) prev_wr <= bridge_wr;
    wire hit = bridge_wr & ~prev_wr & (bridge_addr[31:28] == 4'h0);

    reg  [AW:0] wptr_bin = 0, wptr_gray = 0;
    reg  [AW:0] rptr_bin = 0, rptr_gray = 0;
    reg  [AW:0] rptr_gray_w1 = 0, rptr_gray_w2 = 0;
    wire [AW:0] wptr_next = wptr_bin + 1'b1;
    // gray -> bin of the synchronised read pointer for the full test
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

    // ------------------------------------------------------------------ read side (clk)
    reg  [AW:0] wptr_gray_r1 = 0, wptr_gray_r2 = 0;
    always @(posedge clk) begin
        wptr_gray_r1 <= wptr_gray;
        wptr_gray_r2 <= wptr_gray_r1;
    end
    wire empty = (rptr_gray == wptr_gray_r2);

    // two-stage pipeline: stage A reads the FIFO RAM into q, stage B decodes q into the output registers.
    // One word per clk when the destination keeps up (mem_ready); C76 bytes take four clks per word.
    reg [57:0] q;
    reg        qv = 1'b0;
    reg [2:0]  c76_cnt = 3'd0;
    reg [31:0] c76_word;
    reg [13:0] c76_base;

    wire [3:0]  win  = q[57:54];
    wire [21:0] woff = q[53:32];                       // byte offset >> 2 within the 16 MB window
    wire [23:0] boff = {woff, 2'b00};
    wire [31:0] wdat = q[31:0];

    wire is_mem  = (win == 4'd0) | (win == 4'd2) | (win == 4'd3) | (win == 4'd4) | (win == 4'd6) | (win == 4'd7);
    wire is_c76  = (win == 4'd8);
    wire mem_free = ~mem_valid | mem_ready;
    wire b_take  = qv & (is_mem ? mem_free : is_c76 ? (c76_cnt <= 3'd1) : 1'b1);

    assign ld_busy = ~empty | qv | mem_valid | (c76_cnt != 3'd0);

    always @(posedge clk) begin
        c76_wr <= 1'b0;
        ee_wr  <= 1'b0;
        if (rst) begin
            qv <= 1'b0; mem_valid <= 1'b0; c76_cnt <= 3'd0;
            rptr_bin <= 0; rptr_gray <= 0;
            cfg_platform <= 8'h00; cfg_keycus <= 8'h00; cfg_gun <= 1'b0;
        end else begin
            if (mem_valid & mem_ready) mem_valid <= 1'b0;

            // C76 byte serializer
            if (c76_cnt != 3'd0) begin
                c76_wr   <= 1'b1;
                c76_addr <= c76_base;
                c76_data <= c76_word[7:0];
                c76_word <= {8'h00, c76_word[31:8]};
                c76_base <= c76_base + 1'b1;
                c76_cnt  <= c76_cnt - 1'b1;
            end

            // stage B: decode
            if (b_take) begin
                case (win)
                    4'd0: begin mem_addr <= BIOS_START      | {5'b0, boff[21:0]};                 mem_data <= wdat; mem_valid <= 1'b1; end
                    4'd2: begin mem_addr <= FIXEDROM_START  + {4'b0, boff[22:0]};                 mem_data <= wdat; mem_valid <= 1'b1; end
                    4'd3: begin mem_addr <= BANKEDROM_START + {3'b0, boff};                       mem_data <= wdat; mem_valid <= 1'b1; end
                    4'd4: begin mem_addr <= BANKEDROM_START + 27'h1000000 + {3'b0, boff};         mem_data <= wdat; mem_valid <= 1'b1; end
                    4'd6: begin mem_addr <= SPROG_START     | {9'b0, boff[17:0]};                 mem_data <= wdat; mem_valid <= 1'b1; end
                    4'd7: begin mem_addr <= WAVE_START      + {5'b0, boff[21:0]};                 mem_data <= wdat; mem_valid <= 1'b1; end
                    4'd1: if (boff == 24'd0) begin
                              cfg_platform <= wdat[7:0]; cfg_keycus <= wdat[15:8]; cfg_gun <= wdat[16];
                          end
                    4'd8: begin c76_word <= wdat; c76_base <= boff[13:0]; c76_cnt <= 3'd4; end
                    4'd9: begin ee_addr <= boff[11:2]; ee_data <= wdat; ee_wr <= 1'b1; end
                    default: ;
                endcase
            end

            // stage A: FIFO RAM -> q
            if (!empty && (!qv || b_take)) begin
                q  <= ram[rptr_bin[AW-1:0]];
                qv <= 1'b1;
                rptr_bin  <= rptr_bin + 1'b1;
                rptr_gray <= (rptr_bin + 1'b1) ^ ((rptr_bin + 1'b1) >> 1);
            end else if (b_take) begin
                qv <= 1'b0;
            end
        end
    end
endmodule
`default_nettype wire
