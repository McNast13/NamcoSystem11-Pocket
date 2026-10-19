// Self-checking testbench: pushes a reference image through the bridge side at a Pocket-like cadence and checks every
// delivered write (destination, address, data, order) against what was sent. Run: pocket/core/tb/run.sh
`timescale 1ns/1ps
module tb_s11_loader;
    parameter CLK_HALF = 14.762;   // core clock half period (ns): 14.762 = 33.87 MHz
    parameter GAP_MIN = 2, GAP_RND = 7;   // host cadence: GAP_MIN + 0..GAP_RND clk_74a between words
    reg clk_74a = 0, clk = 0;
    always #6.734 clk_74a = ~clk_74a;      // 74.25 MHz
    always #(CLK_HALF) clk = ~clk;         // core clock (any asynchronous ratio works)

    reg        bridge_wr = 0;
    reg [31:0] bridge_addr = 0, bridge_wr_data = 0;
    reg        rst = 1;
    wire       mem_valid; wire [26:0] mem_addr; wire [31:0] mem_data; reg mem_ready = 0;
    wire       c76_wr; wire [13:0] c76_addr; wire [7:0] c76_data;
    wire       ee_wr; wire [9:0] ee_addr; wire [31:0] ee_data;
    wire [7:0] cfg_platform, cfg_keycus; wire cfg_gun;
    wire       ld_busy, ld_overflow;

    s11_loader dut (.clk_74a(clk_74a), .bridge_wr(bridge_wr), .bridge_addr(bridge_addr), .bridge_wr_data(bridge_wr_data),
        .clk(clk), .rst(rst), .mem_valid(mem_valid), .mem_addr(mem_addr), .mem_data(mem_data), .mem_ready(mem_ready),
        .c76_wr(c76_wr), .c76_addr(c76_addr), .c76_data(c76_data), .ee_wr(ee_wr), .ee_addr(ee_addr), .ee_data(ee_data),
        .cfg_platform(cfg_platform), .cfg_keycus(cfg_keycus), .cfg_gun(cfg_gun), .ld_busy(ld_busy), .ld_overflow(ld_overflow));

    // expected writes in send order (each destination is delivered in order)
    reg [26:0] em_a [0:20000]; reg [31:0] em_d [0:20000];  integer em_n = 0, mem_got = 0;
    reg [13:0] ec_a [0:20000]; reg [7:0]  ec_d [0:20000];  integer ec_n = 0, c76_got = 0;
    reg [9:0]  ee_a [0:2000];  reg [31:0] ee_dd [0:2000];  integer ee_n = 0, ee_got = 0;
    integer errors = 0, sent = 0;
    integer seed = 7;

    always @(posedge clk) begin
        mem_ready <= ($random(seed) & 3) != 0;               // random back-pressure
        if (mem_valid && mem_ready) begin
            if (mem_got >= em_n || mem_addr !== em_a[mem_got] || mem_data !== em_d[mem_got]) begin
                errors = errors + 1;
                if (errors < 10) $display("MEM mismatch #%0d got %h:%h exp %h:%h", mem_got, mem_addr, mem_data, em_a[mem_got], em_d[mem_got]);
            end
            mem_got = mem_got + 1;
        end
        if (c76_wr) begin
            if (c76_got >= ec_n || c76_addr !== ec_a[c76_got] || c76_data !== ec_d[c76_got]) begin
                errors = errors + 1;
                if (errors < 10) $display("C76 mismatch #%0d got %h:%h exp %h:%h", c76_got, c76_addr, c76_data, ec_a[c76_got], ec_d[c76_got]);
            end
            c76_got = c76_got + 1;
        end
        if (ee_wr) begin
            if (ee_got >= ee_n || ee_addr !== ee_a[ee_got] || ee_data !== ee_dd[ee_got]) begin
                errors = errors + 1;
                if (errors < 10) $display("EE mismatch #%0d got %h:%h exp %h:%h", ee_got, ee_addr, ee_data, ee_a[ee_got], ee_dd[ee_got]);
            end
            ee_got = ee_got + 1;
        end
    end

    task bwrite(input [31:0] a, input [31:0] d);
        begin
            @(posedge clk_74a); bridge_addr <= a; bridge_wr_data <= d; bridge_wr <= 1;
            @(posedge clk_74a); bridge_wr <= 0;
            repeat (GAP_MIN + ({$random(seed)} % (GAP_RND + 1))) @(posedge clk_74a);
            sent = sent + 1;
        end
    endtask

    // window `win`, `words` words from word 0, expected placement = base + ((i*4) & mask)
    task send_mem(input [3:0] win, input integer words, input [26:0] base, input [26:0] mask, input [26:0] add_hi);
        integer i; reg [31:0] d;
        begin
            for (i = 0; i < words; i = i + 1) begin
                d = $random(seed);
                em_a[em_n] = base + add_hi + ((i*4) & mask); em_d[em_n] = d; em_n = em_n + 1;
                bwrite({4'h0, win, 24'd0} + i*4, d);
            end
        end
    endtask

    integer i, k;
    reg [31:0] dd;
    initial begin
        repeat (20) @(posedge clk); rst = 0; repeat (20) @(posedge clk);
        send_mem(4'd0, 4096, 27'h0400000, 27'h3FFFFF, 0);                  // program (OR with BIOS_START, no overlap)
        send_mem(4'd3, 2048, 27'h0800000, 27'hFFFFFF, 0);                  // banked low
        send_mem(4'd4,  256, 27'h0800000, 27'hFFFFFF, 27'h1000000);        // banked high
        send_mem(4'd6,  256, 27'h2800000, 27'h3FFFF, 0);                   // sprog
        send_mem(4'd7, 4096, 27'h2840000, 27'h3FFFFF, 0);                  // wave
        send_mem(4'd2,  128, 27'h0480000, 27'h7FFFFF, 0);                  // fixed rom
        for (i = 0; i < 4096; i = i + 1) begin                            // C76 BIOS, 16 KB
            dd = $random(seed);
            for (k = 0; k < 4; k = k + 1) begin ec_a[ec_n] = i*4 + k; ec_d[ec_n] = dd >> (8*k); ec_n = ec_n + 1; end
            bwrite({4'h0, 4'd8, 24'd0} + i*4, dd);
        end
        for (i = 0; i < 1024; i = i + 1) begin                            // EEPROM, 4 KB
            dd = $random(seed);
            ee_a[ee_n] = i; ee_dd[ee_n] = dd; ee_n = ee_n + 1;
            bwrite({4'h0, 4'd9, 24'd0} + i*4, dd);
        end
        bwrite({4'h0, 4'd1, 24'd0}, 32'h0001_0104);                       // platform 4, keycus 1, gun 1
        bwrite(32'hF800_0000, 32'hDEADBEEF);                              // outside the data window: ignored
        bwrite(32'h1000_0100, 32'hDEADBEEF);
        bwrite({4'h0, 4'd5, 24'd0}, 32'hDEADBEEF);                        // unused window
        repeat (200) @(posedge clk_74a);
        wait (!ld_busy); repeat (50) @(posedge clk);

        if (mem_got !== em_n) begin errors = errors + 1; $display("mem count %0d expected %0d", mem_got, em_n); end
        if (c76_got !== ec_n) begin errors = errors + 1; $display("c76 count %0d expected %0d", c76_got, ec_n); end
        if (ee_got  !== ee_n) begin errors = errors + 1; $display("ee count %0d expected %0d", ee_got, ee_n); end
        if (cfg_platform !== 8'h04 || cfg_keycus !== 8'h01 || cfg_gun !== 1'b1) begin errors = errors + 1; $display("cfg wrong %h %h %b", cfg_platform, cfg_keycus, cfg_gun); end
        if (ld_overflow) begin errors = errors + 1; $display("OVERFLOW"); end
        $display("sent=%0d mem=%0d/%0d c76=%0d/%0d ee=%0d/%0d errors=%0d overflow=%b", sent, mem_got, em_n, c76_got, ec_n, ee_got, ee_n, errors, ld_overflow);
        if (errors == 0) $display("PASS"); else $display("FAIL");
        $finish;
    end
    initial begin #800_000_000; $display("TIMEOUT"); $finish; end
endmodule
