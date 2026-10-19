// GPL-2.0-or-later. Main memory for the System 11 core on the Pocket's 64 MiB SDRAM: the MiSTer-contract SDRAM controller
// (psx_sdram_ctrl, same ports as sdram.sv) on clk3x, with the data-slot loader attached to its ch3 write port.
//
//   ld_*  : loader write stream (clk1x), valid/ready, one 32-bit word at a time (s11_loader mem_*)
//   ch1/ch2/dmafifo/refresh : the core's own RAM ports, passed straight through (clk1x requests, as on MiSTer)
//   ch3 belongs to the loader while `ld_active`, otherwise to ext_ch3_* (RAM clear engine, etc.)
`default_nettype none
module s11_ram #(
    parameter integer CAS_LATENCY = 3          // 101.6 MHz needs CL3 for the AS4C32M16 class chip
) (
    input  wire         clk1x,
    input  wire         clk3x,
    input  wire         init,                  // hold high until the PLL is locked

    // loader stream (clk1x)
    input  wire         ld_valid,
    input  wire [26:0]  ld_addr,
    input  wire [31:0]  ld_data,
    output reg          ld_ready,
    input  wire         ld_active,             // loader owns ch3

    // core ports (clk1x), identical to sdram.sv
    input  wire         refreshForce,
    output wire         ram_idle,
    input  wire [26:0]  ch1_addr,
    output wire [127:0] ch1_dout,
    output wire [31:0]  ch1_dout32,
    input  wire         ch1_req,
    input  wire         ch1_dma,
    input  wire [1:0]   ch1_cntDMA,
    input  wire         ch1_cache,
    output wire         ch1_ready,
    output wire [3:0]   cache_wr,
    output wire [31:0]  cache_data,
    output wire [7:0]   cache_addr,
    output wire         dma_wr,
    output wire         dma_reqprocessed,
    output wire [31:0]  dma_data,
    input  wire [26:0]  ch2_addr,
    output wire [31:0]  ch2_dout,
    input  wire [31:0]  ch2_din,
    input  wire         ch2_req,
    input  wire [3:0]   ch2_be,
    output wire         ch2_ready,
    input  wire [26:0]  ext_ch3_addr,
    input  wire [31:0]  ext_ch3_din,
    input  wire         ext_ch3_req,
    input  wire         ext_ch3_rnw,
    input  wire [3:0]   ext_ch3_be,
    output wire [31:0]  ch3_dout,
    output wire         ext_ch3_ready,
    input  wire [26:0]  dmafifo_adr,
    input  wire [31:0]  dmafifo_data,
    input  wire         dmafifo_empty,
    output wire         dmafifo_read,

    // SDRAM pins
    inout  wire [15:0]  dram_dq,
    output wire [12:0]  dram_a,
    output wire [1:0]   dram_dqm,
    output wire [1:0]   dram_ba,
    output wire         dram_we_n, dram_ras_n, dram_cas_n, dram_cke, dram_clk
);
    // ---- loader -> ch3 write (one clk1x request pulse, wait ch3_ready, then ack the loader word) ----
    localparam L_IDLE = 2'd0, L_WAIT = 2'd1;
    reg [1:0]  lstate = L_IDLE;
    reg        l_req = 1'b0;
    reg [26:0] l_addr = 27'd0;
    reg [31:0] l_data = 32'd0;
    wire       ch3_ready;
    always @(posedge clk1x) begin
        l_req    <= 1'b0;
        ld_ready <= 1'b0;
        if (init) lstate <= L_IDLE;
        else case (lstate)
            L_IDLE: if (ld_valid && ld_active && !ld_ready) begin
                l_addr <= ld_addr; l_data <= ld_data; l_req <= 1'b1; lstate <= L_WAIT;
            end
            L_WAIT: if (ch3_ready) begin ld_ready <= 1'b1; lstate <= L_IDLE; end
            default: lstate <= L_IDLE;
        endcase
    end

    wire [26:0] ch3_addr_m = ld_active ? l_addr : ext_ch3_addr;
    wire [31:0] ch3_din_m  = ld_active ? l_data : ext_ch3_din;
    wire [3:0]  ch3_be_m   = ld_active ? 4'hf   : ext_ch3_be;
    wire        ch3_req_m  = ld_active ? l_req  : ext_ch3_req;
    wire        ch3_rnw_m  = ld_active ? 1'b0   : ext_ch3_rnw;
    assign ext_ch3_ready = ch3_ready && !ld_active;

    psx_sdram_ctrl #(.SINGLE_CHIP(1), .CAS_LATENCY(CAS_LATENCY)) controller (
        .init(init), .clk(clk3x), .clk_base(clk1x), .SDRAM_EN(1'b1),
        .SDRAM_DQ(dram_dq), .SDRAM_A(dram_a), .SDRAM_DQML(dram_dqm[0]), .SDRAM_DQMH(dram_dqm[1]),
        .SDRAM_BA(dram_ba), .SDRAM_nCS(), .SDRAM_nWE(dram_we_n), .SDRAM_nRAS(dram_ras_n),
        .SDRAM_nCAS(dram_cas_n), .SDRAM_CKE(dram_cke), .SDRAM_CLK(dram_clk),
        .refreshForce(refreshForce), .ram_idle(ram_idle),
        .ch1_addr(ch1_addr), .ch1_dout(ch1_dout), .ch1_dout32(ch1_dout32), .ch1_din(16'b0),
        .ch1_req(ch1_req), .ch1_rnw(1'b1), .ch1_dma(ch1_dma), .ch1_cntDMA(ch1_cntDMA),
        .ch1_cache(ch1_cache), .ch1_ready(ch1_ready),
        .cache_wr(cache_wr), .cache_data(cache_data), .cache_addr(cache_addr),
        .dma_wr(dma_wr), .dma_reqprocessed(dma_reqprocessed), .dma_data(dma_data),
        .ch2_addr(ch2_addr), .ch2_dout(ch2_dout), .ch2_din(ch2_din), .ch2_req(ch2_req), .ch2_rnw(1'b0),
        .ch2_be(ch2_be), .ch2_ready(ch2_ready),
        .ch3_addr(ch3_addr_m), .ch3_dout(ch3_dout), .ch3_din(ch3_din_m), .ch3_req(ch3_req_m), .ch3_rnw(ch3_rnw_m),
        .ch3_be(ch3_be_m), .ch3_ready(ch3_ready),
        .dmafifo_adr(dmafifo_adr), .dmafifo_data(dmafifo_data),
        .dmafifo_empty(dmafifo_empty), .dmafifo_read(dmafifo_read)
    );
endmodule
`default_nettype wire
