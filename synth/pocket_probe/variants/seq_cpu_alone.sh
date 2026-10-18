#!/bin/sh
# Measure the PS port's sequential R3000 (psx_cpu) on its own: make it the top entity.
sed -i 's/^set_global_assignment -name TOP_LEVEL_ENTITY .*/set_global_assignment -name TOP_LEVEL_ENTITY psx_cpu/' probe.qsf
echo 'set_global_assignment -name SYSTEMVERILOG_FILE psx_cpu_seq.sv' >> probe.qsf
grep -n "TOP_LEVEL\|psx_cpu" probe.qsf
