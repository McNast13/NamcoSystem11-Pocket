# Timing constraints for the probe fit/STA (FIT=1). The real Pocket shell will replace the PLLs, but the core clock
# frequencies (clk_1x 33.87 MHz, clk_2x 67.7 MHz) are what matters for closure.
create_clock -name CLK_50M -period 20.000 [get_ports CLK_50M]
derive_pll_clocks
derive_clock_uncertainty
# management-clock config logic and the video PLL domain are asynchronous to the core domain
set_false_path -from [get_clocks CLK_50M]
set_false_path -to   [get_clocks CLK_50M]
set_clock_groups -asynchronous -group [get_clocks {pll|*}] -group [get_clocks {pll2|*}]
