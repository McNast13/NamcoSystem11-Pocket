#!/bin/sh
# Fitter-side settings from MIRLO64 (N64 on Pocket), which closes timing at ~17.5k ALMs.
cat >> probe.qsf <<'Q'
set_global_assignment -name FITTER_EFFORT "STANDARD FIT"
set_global_assignment -name PHYSICAL_SYNTHESIS_EFFORT FAST
set_global_assignment -name PHYSICAL_SYNTHESIS_COMBO_LOGIC ON
set_global_assignment -name PHYSICAL_SYNTHESIS_REGISTER_DUPLICATION ON
set_global_assignment -name PHYSICAL_SYNTHESIS_ASYNCHRONOUS_SIGNAL_PIPELINING ON
set_global_assignment -name ROUTER_LCELL_INSERTION_AND_LOGIC_DUPLICATION ON
set_global_assignment -name PLACEMENT_EFFORT_MULTIPLIER 10.0
Q
