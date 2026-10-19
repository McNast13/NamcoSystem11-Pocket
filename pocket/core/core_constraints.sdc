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
