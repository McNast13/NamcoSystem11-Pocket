#!/bin/sh
# The 512 B C76 internal RAM is read combinationally by two debug taps, which stops
# Quartus inferring block RAM (it becomes ~4k flip-flops + a mux). Tie the taps off.
sed -i 's/^\( *dbg_ram80 *<= \)ram(0);/\1(others => '"'0'"');/; s/^\( *dbg_ram83 *<= \)ram(3);/\1(others => '"'0'"');/' rtl/c76.vhd
grep -n "dbg_ram8[03] *<=" rtl/c76.vhd
