# Core constraints (loaded with the APF ones through core.qip)
# The PLL's three outputs (33.87 / 67.74 / 101.61 MHz) are phase aligned and timed against each other. They are
# asynchronous to the Pocket's 74.25 MHz clocks and the bridge SPI clock; every crossing is a gray-code FIFO or a
# 2-flop synchroniser (s11_loader FIFO, lock/reset synchronisers in core_top).
set core_clocks [get_clocks {ic|pll|pll|*}]
set_clock_groups -asynchronous \
    -group { bridge_spiclk } \
    -group { clk_74a } \
    -group { clk_74b } \
    -group $core_clocks
# TODO: SDRAM pin timing (input delay/skew of dram_dq, output delay of dram_*) - see openfpga-PlayStation
# scripts/prepare_native_sdram_io.py; the controller registers DQ in the I/O cell but the constraints are not applied yet.

# ---- SDRAM pin timing (AS4C32M16MSA-6, CAS latency 3 at 101.6 MHz) ----
# Adapted from openfpga-PlayStation scripts/pocket_native_sdram_io.tcl. Board flight 0..0.5 ns per leg is an assumption,
# not a measurement. The controller forwards inverted clk3x on dram_clk from a DDR output cell; DQ is captured in
# dq_in[*] (I/O cell registers) and the reviewed CL3 capture consumes the previous beat (setup multicycle 2, no hold relaxation).
set sdram_clk3x [get_clocks {ic|pll|pll|general[2]*divclk}]
set sdram_caps  [get_registers {*|ram|controller|dq_in[*]}]
set sdram_in    [get_ports {dram_dq[*]}]
set sdram_out   [get_ports {dram_a[*] dram_ba[*] dram_dqm[*] dram_dq[*] dram_we_n dram_ras_n dram_cas_n dram_cke}]
if {[get_collection_size $sdram_clk3x] == 1 && [get_collection_size $sdram_caps] == 16 &&
    [get_collection_size $sdram_in] == 16 && [get_collection_size $sdram_out] == 37} {
    set sdram_board_min 0.0
    set sdram_board_max 0.5
    set sdram_tac 5.5
    foreach_in_collection c $sdram_clk3x { set sdram_src [get_clock_info -targets $c] }
    create_generated_clock -name sdram_chip_clk -source $sdram_src -divide_by 1 -invert [get_ports dram_clk]
    derive_clock_uncertainty
    set_input_delay  -clock sdram_chip_clk -max [expr {$sdram_tac + 2*$sdram_board_max}] $sdram_in
    set_input_delay  -clock sdram_chip_clk -min [expr {2.5 + 2*$sdram_board_min}]        $sdram_in
    set_output_delay -clock sdram_chip_clk -max [expr {2.0 + $sdram_board_max - $sdram_board_min}]  $sdram_out
    set_output_delay -clock sdram_chip_clk -min [expr {-1.0 + $sdram_board_min - $sdram_board_max}] $sdram_out
    set_multicycle_path -setup 2 -from $sdram_in -to $sdram_caps
    puts "S11_SDRAM_IO constraints applied"
} else {
    puts "S11_SDRAM_IO WARNING: pin/register collections not as expected, SDRAM pin constraints NOT applied"
}
