#!/bin/sh
# Stronger area settings on top of area_profile (no RTL change). Later assignments override earlier ones.
cat >> probe.qsf <<'Q'
set_global_assignment -name OPTIMIZATION_MODE "AGGRESSIVE AREA"
set_global_assignment -name REMOVE_REDUNDANT_LOGIC_CELLS ON
set_global_assignment -name SYNTH_TIMING_DRIVEN_SYNTHESIS OFF
set_global_assignment -name AUTO_SHIFT_REGISTER_RECOGNITION ALWAYS
Q
