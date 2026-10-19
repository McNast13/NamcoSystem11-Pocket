#!/bin/sh
# Usage (inside the Quartus container, cwd = copy of SYSTEM11_MiSTer tree): run.sh [variant[,variant...]]
# Env: FIT=1 also runs quartus_fit (all pins virtual); FIT_DEVICE overrides the FPGA part.
set -e
cp /probe/probe.qsf probe.qsf
echo '`define BUILD_DATE "000000"' > build_id.v
for v in $(echo "$1" | tr ',' ' '); do
  [ -x "/probe/variants/$v.sh" ] && "/probe/variants/$v.sh"
done
if [ "$FIT" = 1 ]; then
  # emu has far more pins than the device; the fit is for logic/memory/DSP only.
  # Must precede quartus_map so the assignments reach the netlist.
  # (explicit per-port list: DDIO clock outputs SDRAM_CLK/SDRAM2_CLK must stay real pins, and
  # a wildcard VIRTUAL_PIN ON is not overridden by a later OFF)
  awk '/^module emu/{f=1} f&&/\);/{f=0} f' SYSTEM11.sv | sed 's@//.*@@' | grep -E '\b(input|output|inout)\b' \
    | sed -E 's/[,;[:space:]]*$//' | awk '{print $NF}' | grep -v -E '^(SDRAM_CLK|SDRAM2_CLK|CLK_50M)$' | while read n; do
      echo "set_instance_assignment -name VIRTUAL_PIN ON -to $n" >> probe.qsf
      echo "set_instance_assignment -name VIRTUAL_PIN ON -to \"$n[*]\"" >> probe.qsf
    done
  if [ -n "$FIT_DEVICE" ]; then
    sed -i "s/^set_global_assignment -name DEVICE .*/set_global_assignment -name DEVICE $FIT_DEVICE/" probe.qsf
  fi
  if [ "$STA" = 1 ]; then
    cp /probe/probe.sdc probe.sdc
    echo 'set_global_assignment -name SDC_FILE probe.sdc' >> probe.qsf
  fi
  grep -n "DEVICE\|VIRTUAL\|SDC" probe.qsf
fi
quartus_map probe -c probe
if [ "$FIT" = 1 ]; then
  quartus_fit probe -c probe || true
fi
if [ "$FIT" = 1 ] && [ "$STA" = 1 ]; then
  cp /probe/sta.tcl sta.tcl
  quartus_sta -t sta.tcl || true
fi
