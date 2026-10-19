# Core constraints (loaded with the APF ones through core.qip / core_full.qip)
# core PLL (ic|pll|pll): general[0..2] = 33.87 / 67.74 / 101.61 MHz (phase aligned, timed against each other); video PLL
# (ic|pll|video_pll): 53.69 MHz and its 90 degree copy (full build only). All are asynchronous to the Pocket's 74.25 MHz clocks and the bridge SPI clock;
# every crossing is a gray-code FIFO or a 2-flop synchroniser (s11_ioctl_bridge / s11_loader FIFO, lock/reset/pad synchronisers).
set core_clocks [get_clocks -nowarn {ic|pll|pll|general[0]* ic|pll|pll|general[1]* ic|pll|pll|general[2]*}]
set vid_clocks  [get_clocks -nowarn {ic|pll|video_pll|general[0]* ic|pll|video_pll|general[1]*}]
if {[get_collection_size $vid_clocks] > 0} {
    set_clock_groups -asynchronous -group { bridge_spiclk } -group { clk_74a } -group { clk_74b } -group $core_clocks -group $vid_clocks
} else {
    set_clock_groups -asynchronous -group { bridge_spiclk } -group { clk_74a } -group { clk_74b } -group $core_clocks
}
# The Laxer GTE engine runs on a half-rate clock enable (the shipped PS Pocket core uses the same constraint)
set gte_state [get_registers -nowarn {*|PocketGTEEngine:engine|*}]
if {[get_collection_size $gte_state] > 0} {
    set_multicycle_path -from $gte_state -to $gte_state -setup 2
    set_multicycle_path -from $gte_state -to $gte_state -hold 1
}

# ---- SDRAM pin timing (AS4C32M16MSA-6, CAS latency 3 at 101.6 MHz) ----
# Adapted from openfpga-PlayStation scripts/pocket_native_sdram_io.tcl. Board flight 0..0.5 ns per leg is an assumption,
# not a measurement. The controller forwards inverted clk3x on dram_clk from a DDR output cell; DQ is captured in
# dq_in[*] (I/O cell registers) and the reviewed CL3 capture consumes the previous beat (setup multicycle 2, no hold relaxation).
# diagnostics: what the register collections actually contain at SDC-read time
foreach pat {{*dq_in*} {*psx_sdram_ctrl*dq_in*} {*|dq_in[*]} {*dq_in[*]}} {
    set c [get_registers -nowarn $pat]
    set n [get_collection_size $c]
    set first ""
    foreach_in_collection r $c { if {$first == ""} { set first [get_node_info -name $r] } }
    post_message -type info "S11_SDC_DBG get_registers $pat -> $n first=$first"
}
set sdram_clk3x [get_clocks {ic|pll|pll|general[2]*divclk}]
set sdram_caps  [get_registers {*|psx_sdram_ctrl:controller|dq_in[*]}]
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
    post_message -type info "S11_SDRAM_IO constraints applied"
} else {
    post_message -type warning "S11_SDRAM_IO: collections clk=[get_collection_size $sdram_clk3x] caps=[get_collection_size $sdram_caps] in=[get_collection_size $sdram_in] out=[get_collection_size $sdram_out] (want 1/16/16/37), SDRAM pin constraints NOT applied"
}
