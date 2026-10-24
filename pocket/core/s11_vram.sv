// GPL-2.0-or-later. GPU VRAM for the System 11 core on the Pocket's two PSRAMs: the MiSTer core's DDRAM_* port (clk2x)
// served by psx_vram_psram (synchronous burst mode, 64-bit words, die/word address map as in that module's header).
// The memory-card auxiliary port is not used by System 11 and is tied off.
// FULL_RATE=1 (as the PlayStation core 0.5.6 ships): the chip clock runs at clk2x instead of clk2x/2, about twice the VRAM
// bandwidth. The controller's cram*_clk outputs become enables for vram_chip_clk (clk2x 10047 ps late) through a DDIO output
// (high half = enable, low half = 0); latency code 5 at 67.7 MHz. Pin timing is in core_constraints.sdc.
`default_nettype none
module s11_vram #(
    parameter bit FULL_RATE = 1'b0
) (
    input  wire         clk2x,
    input  wire         vram_chip_clk,          // FULL_RATE only: chip clock source
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

    wire c0_clk, c1_clk;
    generate if (FULL_RATE) begin : g_full
        altddio_out #(.extend_oe_disable("OFF"), .intended_device_family("Cyclone V"), .invert_output("OFF"),
            .lpm_hint("UNUSED"), .lpm_type("altddio_out"), .oe_reg("UNREGISTERED"), .power_up_high("OFF"), .width(2))
            vram_clk_ddio (.datain_h({c1_clk, c0_clk}), .datain_l(2'b00), .outclock(vram_chip_clk),
            .dataout({cram1_clk, cram0_clk}), .aclr(1'b0), .aset(1'b0), .oe(1'b1), .outclocken(1'b1), .sclr(1'b0), .sset(1'b0));
    end else begin : g_half
        assign cram0_clk = c0_clk;
        assign cram1_clk = c1_clk;
    end endgenerate

    psx_vram_psram #(.FULL_RATE(FULL_RATE), .LATENCY(FULL_RATE ? 5 : 3)) vram (
        .clk(clk2x), .reset(reset), .park(park),
        .ddr_busy(ddr_busy), .ddr_burstcnt(ddr_burstcnt), .ddr_addr(ddr_addr), .ddr_dout(ddr_dout),
        .ddr_dout_ready(ddr_dout_ready), .ddr_rd(ddr_rd), .ddr_din(ddr_din), .ddr_be(ddr_be), .ddr_we(ddr_we),
        .aux_req(1'b0), .aux_we(1'b0), .aux_addr(21'b0), .aux_din(32'b0), .aux_dout(), .aux_done(), .card_write(),
        .cram0_a(cram0_a), .cram0_dq_out(d0_out), .cram0_dq_oe(d0_oe), .cram0_dq_in(cram0_dq), .cram0_clk(c0_clk),
        .cram0_adv_n(cram0_adv_n), .cram0_cre(cram0_cre), .cram0_ce0_n(cram0_ce0_n), .cram0_ce1_n(cram0_ce1_n),
        .cram0_oe_n(cram0_oe_n), .cram0_we_n(cram0_we_n), .cram0_ub_n(cram0_ub_n), .cram0_lb_n(cram0_lb_n),
        .cram1_a(cram1_a), .cram1_dq_out(d1_out), .cram1_dq_oe(d1_oe), .cram1_dq_in(cram1_dq), .cram1_clk(c1_clk),
        .cram1_adv_n(cram1_adv_n), .cram1_cre(cram1_cre), .cram1_ce0_n(cram1_ce0_n), .cram1_ce1_n(cram1_ce1_n),
        .cram1_oe_n(cram1_oe_n), .cram1_we_n(cram1_we_n), .cram1_ub_n(cram1_ub_n), .cram1_lb_n(cram1_lb_n)
    );
endmodule
`default_nettype wire
