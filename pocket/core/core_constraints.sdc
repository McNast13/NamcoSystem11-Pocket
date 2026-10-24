# Core constraints (loaded with the APF ones through core.qip / core_full.qip)
# core PLL (ic|pll|pll): general[0..2] = 33.87 / 67.74 / 101.61 MHz (phase aligned, timed against each other); video PLL
# (ic|pll|video_pll): 53.69 MHz and its 90 degree copy (full build only). All are asynchronous to the Pocket's 74.25 MHz clocks and the bridge SPI clock;
# every crossing is a gray-code FIFO or a 2-flop synchroniser (s11_ioctl_bridge / s11_loader FIFO, lock/reset/pad synchronisers).
set core_clocks [get_clocks -nowarn {ic|pll|pll|general[0]* ic|pll|pll|general[1]* ic|pll|pll|general[2]*}]
set vid_clocks  [get_clocks -nowarn {ic|pll|video_pll|general[0]* ic|pll|video_pll|general[1]*}]
# audio PLL (I2S master/serial clocks from clk_74b): the audio FIFO is a dcfifo crossing from clk_1x
set aud_clocks  [get_clocks -nowarn {ic|audio|audio|audio_pll|mf_audio_pll_inst|altera_pll_i|general[0]* ic|audio|audio|audio_pll|mf_audio_pll_inst|altera_pll_i|general[1]*}]
set groups [list -group { bridge_spiclk } -group { clk_74a } -group { clk_74b } -group $core_clocks]
if {[get_collection_size $vid_clocks] > 0} { lappend groups -group $vid_clocks }
if {[get_collection_size $aud_clocks] > 0} { lappend groups -group $aud_clocks }
set_clock_groups -asynchronous {*}$groups
# Per-game configuration registers (platform id, KEYCUS type, gun flag, CAT702 keys): written once by the data-slot download while the core is
# held in reset and constant afterwards. They fan out into the GPU's clk_2x logic (texture swizzle / GPU type selection); the 1x -> 2x timing
# of that fan-out was the entire clk_2x failure on the first full fit (300 worst endpoints all launched from zn_keycus_id).
set s11_static [get_registers -nowarn {core_top:ic|emu:s11|zn_keycus_id[*] core_top:ic|emu:s11|zn_platform_r[*] core_top:ic|emu:s11|zn_gun_game core_top:ic|emu:s11|zn_cat702_key_a[*] core_top:ic|emu:s11|zn_cat702_key_b_r[*]}]
if {[get_collection_size $s11_static] > 0} {
    set_false_path -from $s11_static
    post_message -type info "S11_STATIC_CFG false path from [get_collection_size $s11_static] registers"
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
set sdram_clk3x [get_clocks {ic|pll|pll|general[2]*divclk}]
set sdram_in    [get_ports {dram_dq[*]}]
set sdram_out   [get_ports {dram_a[*] dram_ba[*] dram_dqm[*] dram_dq[*] dram_we_n dram_ras_n dram_cas_n dram_cke}]
if {[get_collection_size $sdram_clk3x] == 1 && [get_collection_size $sdram_in] == 16 && [get_collection_size $sdram_out] == 37} {
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
    # the only logic fed by dram_dq is the 16 capture registers (dq_in, I/O cell registers, invisible to get_registers)
    set_multicycle_path -setup 2 -from $sdram_in
    post_message -type info "S11_SDRAM_IO constraints applied"
} else {
    post_message -type warning "S11_SDRAM_IO: collections clk=[get_collection_size $sdram_clk3x] in=[get_collection_size $sdram_in] out=[get_collection_size $sdram_out] (want 1/16/37), SDRAM pin constraints NOT applied"
}

# PSRAM VRAM at full rate (s11_vram FULL_RATE=1, values from the PlayStation core 0.5.6 pocket.sdc): the chip clock is the fourth CPU
# PLL output (clk2x 10047 ps late) through a DDIO output. Chip timing (AS1C8M16PL): inputs set up 3 ns / held 2 ns around the chip
# clock; read data valid 9 ns after a chip edge until 2 ns after the next; a word is registered in dq_r at the second clk2x edge after
# the edge that launched it (setup multicycle 2).
set vram_chip {ic|pll|pll|general[3].gpll~PLL_OUTPUT_COUNTER|divclk}
if {[get_collection_size [get_pins -nowarn $vram_chip]] > 0} {
    foreach c {cram0 cram1} {
        create_generated_clock -name ${c}_clk_out -source [get_pins $vram_chip] [get_ports ${c}_clk]
        set outs [get_ports "${c}_a[*] ${c}_dq[*] ${c}_adv_n ${c}_cre ${c}_ce0_n ${c}_ce1_n ${c}_oe_n ${c}_we_n ${c}_ub_n ${c}_lb_n"]
        set_output_delay -clock ${c}_clk_out -max 3.0 -add_delay $outs
        set_output_delay -clock ${c}_clk_out -min -2.0 -add_delay $outs
        set_input_delay -clock ${c}_clk_out -max 9.0 -add_delay [get_ports ${c}_dq[*]]
        set_input_delay -clock ${c}_clk_out -min 2.0 -add_delay [get_ports ${c}_dq[*]]
        set_multicycle_path -setup 2 -from [get_clocks ${c}_clk_out] -to [get_registers {*|psx_vram_psram:vram|dq_r[*]}]
        set_multicycle_path -hold 1 -from [get_clocks ${c}_clk_out] -to [get_registers {*|psx_vram_psram:vram|dq_r[*]}]
    }
    post_message -type info "S11_VRAM_FULL_RATE constraints applied"
} else {
    post_message -type warning "S11_VRAM_FULL_RATE: PLL output $vram_chip not found, PSRAM pin constraints NOT applied"
}
