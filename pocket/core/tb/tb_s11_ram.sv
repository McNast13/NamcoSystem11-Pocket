// Loader -> s11_ram -> psx_sdram_ctrl -> strict SDR chip model. Pushes a mixed slot image through the bridge side, then
// reads every loaded word back through the core's ch1 port and compares. Run: pocket/core/tb/run_ram.sh
`timescale 1ns/1ps
`default_nettype none
module tb_s11_ram;
    parameter CAS = 3;
    parameter integer WORDS = 3000;
    reg clk_74a = 0, clk3 = 0, clk1 = 0;
    always #6.734 clk_74a = ~clk_74a;
    // 101.6064 MHz and its /3 (aligned), as the PLL provides
    always #4.921 clk3 = ~clk3;
    reg [1:0] div = 0;
    always @(posedge clk3) begin div <= (div == 2) ? 0 : div + 1; end
    always @(posedge clk3) clk1 <= (div == 2) ? 1'b1 : (div == 0) ? 1'b0 : clk1;   // 50% of 3 clk3: close enough, edges aligned

    reg  init = 1;
    reg        bridge_wr = 0; reg [31:0] bridge_addr = 0, bridge_wr_data = 0;
    wire       mem_valid, c76_wr, ee_wr, cfg_gun, ld_busy, ld_overflow; wire [26:0] mem_addr; wire [31:0] mem_data, ee_data;
    wire [13:0] c76_addr; wire [7:0] c76_data, cfg_platform, cfg_keycus; wire [9:0] ee_addr;
    wire       mem_ready;

    s11_loader loader (.clk_74a(clk_74a), .bridge_wr(bridge_wr), .bridge_addr(bridge_addr), .bridge_wr_data(bridge_wr_data),
        .clk(clk1), .rst(init), .mem_valid(mem_valid), .mem_addr(mem_addr), .mem_data(mem_data), .mem_ready(mem_ready),
        .c76_wr(c76_wr), .c76_addr(c76_addr), .c76_data(c76_data), .ee_wr(ee_wr), .ee_addr(ee_addr), .ee_data(ee_data),
        .cfg_platform(cfg_platform), .cfg_keycus(cfg_keycus), .cfg_gun(cfg_gun), .ld_busy(ld_busy), .ld_overflow(ld_overflow));

    reg [26:0] ch1_addr = 0; reg ch1_req = 0;
    wire [31:0] ch1_dout32; wire ch1_ready;
    wire [15:0] dq; wire [12:0] a; wire [1:0] ba, dqm; wire we_n, ras_n, cas_n, cke, chip_clk;
    wire ld_active = ld_busy;

    s11_ram #(.CAS_LATENCY(CAS)) ram (
        .clk1x(clk1), .clk3x(clk3), .init(init),
        .ld_valid(mem_valid), .ld_addr(mem_addr), .ld_data(mem_data), .ld_ready(mem_ready), .ld_active(ld_active),
        .refreshForce(1'b0), .ram_idle(),
        .ch1_addr(ch1_addr), .ch1_dout(), .ch1_dout32(ch1_dout32), .ch1_req(ch1_req), .ch1_dma(1'b0), .ch1_cntDMA(2'b0),
        .ch1_cache(1'b0), .ch1_ready(ch1_ready), .cache_wr(), .cache_data(), .cache_addr(), .dma_wr(), .dma_reqprocessed(), .dma_data(),
        .ch2_addr(27'b0), .ch2_dout(), .ch2_din(32'b0), .ch2_req(1'b0), .ch2_be(4'b0), .ch2_ready(),
        .ext_ch3_addr(27'b0), .ext_ch3_din(32'b0), .ext_ch3_req(1'b0), .ext_ch3_rnw(1'b0), .ext_ch3_be(4'b0),
        .ch3_dout(), .ext_ch3_ready(),
        .dmafifo_adr(27'b0), .dmafifo_data(32'b0), .dmafifo_empty(1'b1), .dmafifo_read(),
        .dram_dq(dq), .dram_a(a), .dram_dqm(dqm), .dram_ba(ba), .dram_we_n(we_n), .dram_ras_n(ras_n), .dram_cas_n(cas_n),
        .dram_cke(cke), .dram_clk(chip_clk));

    wire chip_clk_d; assign #(2.0) chip_clk_d = chip_clk;
    sdram_chip_model #(.CAS(CAS), .T_AC(CAS == 2 ? 6.0 : 5.5), .T_OH(2.5), .T_RET(2.0), .NAME("s11")) chip (
        .clk(chip_clk_d), .cke(cke), .ncs(1'b0), .nras(ras_n), .ncas(cas_n), .nwe(we_n), .a(a), .ba(ba), .dqm(dqm), .dq(dq));

    // expected image (word index -> byte address via the S11 slot map)
    reg [26:0] ea [0:WORDS-1]; reg [31:0] ed [0:WORDS-1];
    integer n = 0, i, errors = 0, seed = 11;
    task bwrite(input [31:0] adr, input [31:0] d);
        begin
            @(posedge clk_74a); bridge_addr <= adr; bridge_wr_data <= d; bridge_wr <= 1;
            @(posedge clk_74a); bridge_wr <= 0;
            repeat (6 + ({$random(seed)} % 8)) @(posedge clk_74a);
        end
    endtask
    task push(input [3:0] win, input integer cnt, input [26:0] base);
        integer k; reg [31:0] d;
        begin
            for (k = 0; k < cnt; k = k + 1) begin
                d = $random(seed);
                ea[n] = base + k*4; ed[n] = d; n = n + 1;
                bwrite({4'h0, win, 24'd0} + k*4, d);
            end
        end
    endtask

    reg [31:0] got;
    initial begin
        repeat (30) @(posedge clk1); init = 0;
        repeat (9000) @(posedge clk1);                   // controller power-up / mode register set
        push(4'd0, 1200, 27'h0400000);                    // program
        push(4'd3, 1200, 27'h0800000);                    // banked ROM
        push(4'd7,  300, 27'h2840000);                    // wave ROM
        push(4'd6,  300, 27'h2800000);                    // sprog
        wait (!ld_busy); repeat (200) @(posedge clk1);
        for (i = 0; i < n; i = i + 1) begin
            @(posedge clk1); ch1_addr <= ea[i]; ch1_req <= 1;
            @(posedge clk1); ch1_req <= 0;
            while (!ch1_ready) @(posedge clk1);
            got = ch1_dout32;
            if (got !== ed[i]) begin errors = errors + 1; if (errors < 10) $display("MISMATCH @%h got %h want %h", ea[i], got, ed[i]); end
        end
        $display("words=%0d errors=%0d overflow=%b chip_errors=%0d", n, errors, ld_overflow, chip.errors);
        if (errors == 0 && !ld_overflow && chip.errors == 0) $display("PASS"); else $display("FAIL");
        $finish;
    end
    initial begin #3_000_000_000; $display("TIMEOUT"); $finish; end
endmodule
