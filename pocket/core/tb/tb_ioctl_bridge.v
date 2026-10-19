// Checks s11_ioctl_bridge against a model of the System 11 core's download side: stream layout, index/address mapping,
// ioctl_wait pacing (the model stalls like SYSTEM11.sv does after every 32-bit SDRAM write), file gaps, end of download.
`timescale 1ns/1ps
module tb_ioctl_bridge;
    reg clk_74a = 0, clk = 0;
    always #6.734 clk_74a = ~clk_74a;
    always #14.762 clk = ~clk;
    reg bridge_wr = 0; reg [31:0] bridge_addr = 0, bridge_wr_data = 0; reg rst = 1;
    wire dl, wr; wire [7:0] idx; wire [26:0] addr; wire [15:0] dout; reg wait_r = 0;
    wire busy, ovf;
    s11_ioctl_bridge dut (.clk_74a(clk_74a), .bridge_wr(bridge_wr), .bridge_addr(bridge_addr), .bridge_wr_data(bridge_wr_data),
        .clk(clk), .rst(rst), .ioctl_download(dl), .ioctl_wr(wr), .ioctl_index(idx), .ioctl_addr(addr), .ioctl_dout(dout),
        .ioctl_wait(wait_r), .ld_busy(busy), .ld_overflow(ovf));

    // core-side model: a 32-bit word completes on the odd half; ioctl_wait is raised the clock after and held 6..13 clk
    integer seed = 3, errors = 0, got = 0, exp_n = 0, wcnt = 0, dl_drops = 0;
    reg [7:0]  e_idx [0:9999]; reg [26:0] e_addr [0:9999]; reg [15:0] e_data [0:9999];
    reg dl_d = 0; integer waitleft = 0;
    always @(posedge clk) begin
        dl_d <= dl;
        if (dl_d && !dl) dl_drops <= dl_drops + 1;
        if (waitleft > 0) begin waitleft <= waitleft - 1; if (waitleft == 1) wait_r <= 0; end
        if (wr) begin
            if (!dl) begin errors = errors + 1; $display("wr while !download"); end
            if (wait_r) begin errors = errors + 1; $display("wr while ioctl_wait"); end
            if (got >= exp_n || idx !== e_idx[got] || addr !== e_addr[got] || dout !== e_data[got]) begin
                errors = errors + 1;
                if (errors < 10) $display("MISMATCH #%0d got idx %0d addr %h data %h  exp idx %0d addr %h data %h", got, idx, addr, dout, e_idx[got], e_addr[got], e_data[got]);
            end
            got = got + 1;
            if (addr[1]) begin wait_r <= 1; waitleft <= 6 + ({$random(seed)} % 8); end   // odd half completes the word
        end
    end

    task bwrite(input [31:0] a, input [31:0] d);
        begin
            @(posedge clk_74a); bridge_addr <= a; bridge_wr_data <= d; bridge_wr <= 1;
            @(posedge clk_74a); bridge_wr <= 0;
            repeat (6 + ({$random(seed)} % 10)) @(posedge clk_74a);
        end
    endtask
    task send(input [3:0] win, input [7:0] index, input integer words, input [26:0] base);
        integer k; reg [31:0] d;
        begin
            for (k = 0; k < words; k = k + 1) begin
                d = $random(seed);
                e_idx[exp_n] = index; e_addr[exp_n] = base + k*4;     e_data[exp_n] = d[15:0];  exp_n = exp_n + 1;
                e_idx[exp_n] = index; e_addr[exp_n] = base + k*4 + 2; e_data[exp_n] = d[31:16]; exp_n = exp_n + 1;
                bwrite({4'h0, win, 24'd0} + k*4, d);
            end
        end
    endtask
    initial begin
        repeat (20) @(posedge clk); rst = 0; repeat (20) @(posedge clk);
        send(4'd8, 8'd8, 64, 0);              // C76 BIOS
        send(4'd1, 8'd1, 1, 0);               // config
        send(4'd0, 8'd0, 300, 0);             // program
        send(4'd3, 8'd3, 300, 0);             // banked
        send(4'd4, 8'd3, 100, 27'h1000000);   // banked second half: index 3, +16 MB
        send(4'd7, 8'd7, 200, 0);             // wave
        send(4'd6, 8'd6, 100, 0);             // sprog
        send(4'd9, 8'd9, 64, 0);              // eeprom
        bwrite(32'hF800_0000, 32'hDEAD); bwrite({4'h0, 4'd5, 24'd0}, 32'hDEAD);   // ignored
        repeat (200) @(posedge clk_74a);
        wait (!busy); repeat (50) @(posedge clk);
        if (got !== exp_n) begin errors = errors + 1; $display("count %0d expected %0d", got, exp_n); end
        if (dl) begin errors = errors + 1; $display("download still high"); end
        if (ovf) begin errors = errors + 1; $display("overflow"); end
        if (dl_drops < 7) begin errors = errors + 1; $display("expected a download gap per file, saw %0d", dl_drops); end
        $display("halfwords=%0d/%0d file_gaps=%0d errors=%0d", got, exp_n, dl_drops, errors);
        if (errors == 0) $display("PASS"); else $display("FAIL");
        $finish;
    end
    initial begin #600_000_000; $display("TIMEOUT"); $finish; end
endmodule
