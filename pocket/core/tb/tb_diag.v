`timescale 1ns/1ps
module tb_diag;
    reg clk = 0; always #9.31 clk = ~clk;
    wire ce, hs, vs, hb, vb; wire [23:0] rgb;
    s11_diag d (.clk(clk), .extra(64'h0), .bus({32'hA5A5A5A5, 32'hFFFF0000, 32'h12345678, 32'h0000FFFF}), .ce(ce), .hsync(hs), .vsync(vs), .hblank(hb), .vblank(vb), .rgb(rgb));
    integer pixels = 0, lines = 0, active = 0, frames = 0, vsp = 0, ce_per_line = 0, errs = 0;
    reg hs_d = 0, vs_d = 0;
    always @(posedge clk) if (ce) begin
        ce_per_line = ce_per_line + 1;
        hs_d <= hs; vs_d <= vs;
        if (!hs && hs_d) begin if (lines > 3 && ce_per_line != 426) errs = errs + 1; ce_per_line = 0; lines = lines + 1; end
        if (vs && !vs_d) begin frames = frames + 1; end
        if (!hb && !vb) begin active = active + 1; if (rgb != 0) pixels = pixels + 1; end
    end
    initial begin
        #40_000_000;   // ~2.4 frames of 262 lines x 426 px x 8 clk x 18.62ns = 16.6 ms
        $display("frames=%0d lines=%0d active=%0d nonblack=%0d line_len_errors=%0d", frames, lines, active, pixels, errs);
        if (frames >= 2 && errs == 0 && active > 2*320*240 - 1000 && pixels > active/3) $display("PASS"); else $display("FAIL");
        $finish;
    end
endmodule
