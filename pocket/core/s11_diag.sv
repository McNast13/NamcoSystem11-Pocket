// GPL-2.0-or-later. Bring-up diagnostic screen: a self-contained 320x240 video generator (clk_vid / 8 pixel enable) that draws
// 128 status bits as 4 rows of 32 boxes (green = 1, dark red = 0, MSB at the left, a gap after every box), a frame counter and
// colour ramps. It runs whether or not the System 11 core produces video, so the Pocket scaler always has a valid picture.
// `bus` is sampled straight from registers in other clock domains (a diagnostic, no synchronisers).
//
//   row 0 bus[127:96]  row 1 bus[95:64]  row 2 bus[63:32]  row 3 bus[31:0]      (rows are 16 lines high)
//   rows 4, 5 extra[63:32], extra[31:0]   rows 6-8 R / G / B ramps   row 9 grey ramp   rows 10-13 eight colour bars
`default_nettype none
module s11_diag (
    input  wire         clk,                 // clk_vid
    input  wire [127:0] bus,
    input  wire [63:0]  extra,               // rows 4 and 5 (extra[63:32], extra[31:0])
    output reg          ce = 1'b0,
    output reg          hsync = 1'b0, vsync = 1'b0, hblank = 1'b1, vblank = 1'b1,
    output reg  [23:0]  rgb = 24'd0
);
    reg [2:0]  div = 3'd0;
    reg [8:0]  h = 9'd0;                      // 0..425
    reg [8:0]  v = 9'd0;                      // 0..261
    reg [15:0] frame = 16'd0;
    always @(posedge clk) begin
        ce <= 1'b0;
        div <= div + 1'b1;
        if (div == 3'd7) begin
            ce <= 1'b1;
            if (h == 9'd425) begin
                h <= 9'd0;
                if (v == 9'd261) begin v <= 9'd0; frame <= frame + 1'b1; end else v <= v + 1'b1;
            end else h <= h + 1'b1;
        end
    end
    // timing of the pixel that is output with the next ce
    wire [8:0] x = h - 9'd72;
    wire [8:0] y = v - 9'd18;
    wire act_h = h >= 9'd72 && h < 9'd392;
    wire act_v = v >= 9'd18 && v < 9'd258;
    wire [3:0] row = y[7:4];
    wire [5:0] col = x / 10;                  // 0..31
    wire [3:0] sub = x - col * 10;            // 0..9 within the box column
    wire [3:0] ly  = y[3:0];
    wire box = sub < 4'd9 && ly < 4'd14;
    reg [31:0] word;
    always @* begin
        case (row)
            4'd0: word = bus[127:96];
            4'd1: word = bus[95:64];
            4'd2: word = bus[63:32];
            4'd3: word = bus[31:0];
            4'd4: word = extra[63:32];
            4'd5: word = extra[31:0];
            default: word = {frame, 15'd0, frame[5]};
        endcase
    end
    wire bit_v = word[5'd31 - col[4:0]];
    wire [16:0] ramp_w = x * 17'd205;              // 17 bit: the 9 bit product overflowed and the ramps stayed black; x*205/256 = 0..255 over 0..319
    wire [7:0] ramp = ramp_w[15:8];                // (a divide by 319 here took 27 ns, more than the 18.6 ns video clock period)
    reg [23:0] pix;
    always @* begin
        pix = 24'h000000;
        if (row <= 4'd5) begin
            if (box) pix = bit_v ? 24'h00C000 : 24'h300000;
        end else if (row == 4'd6) pix = {ramp, 16'd0};
        else if (row == 4'd7) pix = {8'd0, ramp, 8'd0};
        else if (row == 4'd8) pix = {16'd0, ramp};
        else if (row == 4'd9) pix = {ramp, ramp, ramp};
        else if (row >= 4'd10 && row <= 4'd13) begin
            case (col[4:2])
                3'd0: pix = 24'hFFFFFF; 3'd1: pix = 24'hFFFF00; 3'd2: pix = 24'h00FFFF; 3'd3: pix = 24'h00FF00;
                3'd4: pix = 24'hFF00FF; 3'd5: pix = 24'hFF0000; 3'd6: pix = 24'h0000FF; default: pix = 24'h808080;
            endcase
        end
    end
    always @(posedge clk) if (div == 3'd7) begin
        hsync  <= h < 9'd32;
        vsync  <= v < 9'd3;
        hblank <= !act_h;
        vblank <= !act_v;
        rgb    <= (act_h && act_v) ? pix : 24'd0;
    end
endmodule
`default_nettype wire
