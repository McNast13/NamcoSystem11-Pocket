// GPL-2.0-or-later. System 11 audio to the Pocket's I2S: the core's 16-bit signed stereo (updated at the C352 rate,
// 33.8688 MHz / 384 = 88.2 kHz) is low-passed (one-pole, ~21 kHz) and decimated to 48 kHz, pushed into the MIRLO64-derived
// audio FIFO/I2S block. The FIFO is primed with PRIME silent samples so the 48 kHz read side does not underrun while the
// two PLLs drift against each other by a few ppm.
`default_nettype none
module s11_audio #(parameter integer PRIME = 256) (
    input  wire        clk_74b,
    input  wire        clk,                 // clk1x, 33.8688 MHz
    input  wire        reset,
    input  wire signed [15:0] in_l,
    input  wire signed [15:0] in_r,
    output wire        audio_mclk,
    output wire        audio_lrck,
    output wire        audio_dac
);
    // one-pole low-pass at clk: y += (x - y) >> 8   (24-bit state = 16 bit + 8 fraction)
    reg signed [23:0] yl = 0, yr = 0;
    wire signed [23:0] xl = {in_l, 8'h00}, xr = {in_r, 8'h00};
    always @(posedge clk) begin
        yl <= yl + ((xl - yl) >>> 8);
        yr <= yr + ((xr - yr) >>> 8);
    end

    // 48 kHz output tick: 33,868,800 / 48,000 = 705.6 clk -> phase accumulator
    localparam [31:0] CLK_HZ = 32'd33868800, OUT_HZ = 32'd48000;
    reg [31:0] acc = 0;
    reg        tick = 0;
    reg [9:0]  prime = 0;
    reg        wr = 0;
    reg [31:0] word = 0;
    always @(posedge clk) begin
        tick <= 0; wr <= 0;
        if (reset) begin
            acc <= 0; prime <= 0;
        end else if (prime < PRIME) begin          // prime the FIFO with silence, one word per clk
            prime <= prime + 1'b1; word <= 32'd0; wr <= 1;
        end else begin
            acc <= acc + OUT_HZ;
            if (acc + OUT_HZ >= CLK_HZ) begin acc <= acc + OUT_HZ - CLK_HZ; tick <= 1; end
            if (tick) begin word <= {yl[23:8], yr[23:8]}; wr <= 1; end
        end
    end

    audio audio (
        .clk_74b(clk_74b), .clk_sys(clk), .reset(reset),
        .audio_bus_in(word), .audio_bus_wr(wr),
        .audio_playback_en(1'b1), .audio_flush(1'b0), .audio_buffer_fill(),
        .audio_mclk(audio_mclk), .audio_lrck(audio_lrck), .audio_dac(audio_dac)
    );
endmodule
`default_nettype wire
