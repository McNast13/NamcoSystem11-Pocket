// Feeds a 16 KB C76 BIOS image through s11_ioctl_bridge into the byte writer copied verbatim from SYSTEM11.sv (c76bios_*)
// and compares the resulting 16 KB memory with the source image.
`timescale 1ns/1ps
module tb_c76bios;
    reg clk_74a = 0, clk = 0;
    always #6.734 clk_74a = ~clk_74a;
    always #14.762 clk = ~clk;
    reg bridge_wr = 0; reg [31:0] bridge_addr = 0, bridge_wr_data = 0; reg rst = 1;
    wire ioctl_download, ioctl_wr; wire [7:0] ioctl_index; wire [26:0] ioctl_addr; wire [15:0] ioctl_dout;
    wire busy, ovf;
    s11_ioctl_bridge dut (.clk_74a(clk_74a), .bridge_wr(bridge_wr), .bridge_addr(bridge_addr), .bridge_wr_data(bridge_wr_data),
        .clk(clk), .rst(rst), .ioctl_download(ioctl_download), .ioctl_wr(ioctl_wr), .ioctl_index(ioctl_index), .ioctl_addr(ioctl_addr),
        .ioctl_dout(ioctl_dout), .ioctl_wait(1'b0), .ld_busy(busy), .ld_overflow(ovf));

    // ---- verbatim from SYSTEM11.sv ----
    reg c76bios_download;
    always @(posedge clk) c76bios_download <= ioctl_download & (ioctl_index == 8);
    reg        c76bios_pend = 0;
    reg [13:0] c76bios_addr;
    reg [15:0] c76bios_word;
    reg        c76bios_wr = 0;
    always @(posedge clk) begin
       c76bios_wr <= 0;
       if (c76bios_download & ioctl_wr) begin
          c76bios_addr <= ioctl_addr[13:0];
          c76bios_word <= ioctl_dout;
          c76bios_wr   <= 1;
          c76bios_pend <= 1;
       end else if (c76bios_pend) begin
          c76bios_addr <= c76bios_addr | 14'd1;
          c76bios_word <= {8'h00, c76bios_word[15:8]};
          c76bios_wr   <= 1;
          c76bios_pend <= 0;
       end
    end
    // ---- end verbatim ----
    reg [7:0] mem [0:16383]; reg [7:0] src [0:16383]; reg [16383:0] written = 0;
    always @(posedge clk) if (c76bios_wr) begin mem[c76bios_addr] <= c76bios_word[7:0]; written[c76bios_addr] <= 1; end

    integer k, bad = 0, seed = 5;
    reg [31:0] d;
    task bwrite(input [31:0] a, input [31:0] dd);
        begin
            @(posedge clk_74a); bridge_addr <= a; bridge_wr_data <= dd; bridge_wr <= 1;
            @(posedge clk_74a); bridge_wr <= 0;
            repeat (40) @(posedge clk_74a);
        end
    endtask
    initial begin
        for (k = 0; k < 16384; k = k + 1) begin src[k] = $random(seed); mem[k] = 8'h00; end
        repeat (20) @(posedge clk); rst = 0; repeat (20) @(posedge clk);
        for (k = 0; k < 4096; k = k + 1) begin
            d = {src[k*4+3], src[k*4+2], src[k*4+1], src[k*4]};
            bwrite({4'h0, 4'd8, 24'd0} + k*4, d);
        end
        repeat (200) @(posedge clk_74a);
        wait (!busy); repeat (50) @(posedge clk);
        for (k = 0; k < 16384; k = k + 1) if (mem[k] !== src[k]) begin bad = bad + 1; if (bad < 9) $display("byte %0d (%h) got %h expected %h written=%b", k, k, mem[k], src[k], written[k]); end
        for (k = 0; k < 16; k = k + 1) begin : hist
            integer j, c; c = 0;
            for (j = 0; j < 1024; j = j + 1) if (mem[k*1024+j] !== src[k*1024+j]) c = c + 1;
            $display("  %0d KB..: %0d bad", k, c);
        end
        $display("overflow=%b bad bytes %0d / 16384, never written %0d", ovf, bad, 16384 - $countones(written));
        if (bad == 0) $display("PASS"); else $display("FAIL");
        $finish;
    end
    initial begin #400_000_000; $display("TIMEOUT"); $finish; end
endmodule
