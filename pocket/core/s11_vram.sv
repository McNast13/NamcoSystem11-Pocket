// GPL-2.0-or-later. GPU VRAM for the System 11 core on the Pocket's two PSRAMs: the MiSTer core's DDRAM_* port (clk2x)
// served by psx_vram_psram (synchronous burst mode, 64-bit words, die/word address map as in that module's header).
// The memory-card auxiliary port is not used by System 11 and is tied off.
`default_nettype none
module s11_vram (
    input  wire         clk2x,
    input  wire         reset,                  // synchronous to clk2x
    input  wire         park,                   // core held in reset / not running: return the chips to power-on mode (any clock)

    // DDRAM_* port of the GPU (clk2x)
    output wire         ddr_busy,
    input  wire [7:0]   ddr_burstcnt,
    input  wire [24:0]  ddr_addr,
    output wire [63:0]  ddr_dout,
    output wire         ddr_dout_ready,
    input  wire         ddr_rd,
    input  wire [63:0]  ddr_din,
    input  wire [7:0]   ddr_be,
    input  wire         ddr_we,

    // PSRAM pins
    output wire [21:16] cram0_a,
    inout  wire [15:0]  cram0_dq,
    output wire         cram0_clk, cram0_adv_n, cram0_cre, cram0_ce0_n, cram0_ce1_n, cram0_oe_n, cram0_we_n, cram0_ub_n, cram0_lb_n,
    output wire [21:16] cram1_a,
    inout  wire [15:0]  cram1_dq,
    output wire         cram1_clk, cram1_adv_n, cram1_cre, cram1_ce0_n, cram1_ce1_n, cram1_oe_n, cram1_we_n, cram1_ub_n, cram1_lb_n
);
    wire [15:0] d0_out, d1_out;
    wire        d0_oe, d1_oe;
    assign cram0_dq = d0_oe ? d0_out : 16'bz;
    assign cram1_dq = d1_oe ? d1_out : 16'bz;

    psx_vram_psram vram (
        .clk(clk2x), .reset(reset), .park(park),
        .ddr_busy(ddr_busy), .ddr_burstcnt(ddr_burstcnt), .ddr_addr(ddr_addr), .ddr_dout(ddr_dout),
        .ddr_dout_ready(ddr_dout_ready), .ddr_rd(ddr_rd), .ddr_din(ddr_din), .ddr_be(ddr_be), .ddr_we(ddr_we),
        .aux_req(1'b0), .aux_we(1'b0), .aux_addr(21'b0), .aux_din(32'b0), .aux_dout(), .aux_done(), .card_write(),
        .cram0_a(cram0_a), .cram0_dq_out(d0_out), .cram0_dq_oe(d0_oe), .cram0_dq_in(cram0_dq), .cram0_clk(cram0_clk),
        .cram0_adv_n(cram0_adv_n), .cram0_cre(cram0_cre), .cram0_ce0_n(cram0_ce0_n), .cram0_ce1_n(cram0_ce1_n),
        .cram0_oe_n(cram0_oe_n), .cram0_we_n(cram0_we_n), .cram0_ub_n(cram0_ub_n), .cram0_lb_n(cram0_lb_n),
        .cram1_a(cram1_a), .cram1_dq_out(d1_out), .cram1_dq_oe(d1_oe), .cram1_dq_in(cram1_dq), .cram1_clk(cram1_clk),
        .cram1_adv_n(cram1_adv_n), .cram1_cre(cram1_cre), .cram1_ce0_n(cram1_ce0_n), .cram1_ce1_n(cram1_ce1_n),
        .cram1_oe_n(cram1_oe_n), .cram1_we_n(cram1_we_n), .cram1_ub_n(cram1_ub_n), .cram1_lb_n(cram1_lb_n)
    );
endmodule
`default_nettype wire
