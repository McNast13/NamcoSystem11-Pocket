// GPL-2.0-or-later. Core clocks from the Pocket's 74.25 MHz reference: the System 11 / PlayStation clock plan
// (33.8688 / 67.7376 / 101.6064 MHz = 1x / 2x / 3x, all phase aligned). clk3x runs the SDRAM controller; the controller
// forms the SDRAM chip clock itself (inverted clk3x from a DDR output cell). Same plan as openfpga-PlayStation's cpu_pll.
`default_nettype none
module s11_pll (
    input  wire clk_74a,
    input  wire rst,
    output wire clk1x,
    output wire clk2x,
    output wire clk3x,
    output wire locked
);
    altera_pll #(
        .fractional_vco_multiplier("true"), .reference_clock_frequency("74.25 MHz"),
        .operation_mode("normal"), .number_of_clocks(3), .pll_type("General"), .pll_subtype("General"),
        .output_clock_frequency0("33.868800 MHz"),  .phase_shift0("0 ps"), .duty_cycle0(50),
        .output_clock_frequency1("67.737600 MHz"),  .phase_shift1("0 ps"), .duty_cycle1(50),
        .output_clock_frequency2("101.606400 MHz"), .phase_shift2("0 ps"), .duty_cycle2(50)
    ) pll (
        .refclk(clk_74a), .rst(rst), .fbclk(1'b0), .fboutclk(), .locked(locked),
        .outclk({clk3x, clk2x, clk1x})
    );
endmodule
`default_nettype wire
