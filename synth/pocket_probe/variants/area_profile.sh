#!/bin/sh
# Quartus settings from openfpga-PlayStation COMPILE_PROFILES['area-min-state'] (no RTL change).
cat >> probe.qsf <<'Q'
set_global_assignment -name OPTIMIZATION_TECHNIQUE AREA
set_global_assignment -name MUX_RESTRUCTURE ON
set_global_assignment -name ALLOW_ANY_RAM_SIZE_FOR_RECOGNITION ON
set_global_assignment -name ALLOW_ANY_ROM_SIZE_FOR_RECOGNITION ON
set_global_assignment -name PRE_MAPPING_RESYNTHESIS OFF
set_global_assignment -name ADV_NETLIST_OPT_SYNTH_WYSIWYG_REMAP OFF
set_global_assignment -name PHYSICAL_SYNTHESIS_REGISTER_RETIMING OFF
set_global_assignment -name AUTO_RESOURCE_SHARING ON
set_global_assignment -name STATE_MACHINE_PROCESSING "MINIMAL BITS"
Q
