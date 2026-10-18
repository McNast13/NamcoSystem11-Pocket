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
  echo 'set_instance_assignment -name VIRTUAL_PIN ON -to *' >> probe.qsf
  # DDIO outputs must drive a real pin
  echo 'set_instance_assignment -name VIRTUAL_PIN OFF -to SDRAM_CLK' >> probe.qsf
  if [ -n "$FIT_DEVICE" ]; then
    sed -i "s/^set_global_assignment -name DEVICE .*/set_global_assignment -name DEVICE $FIT_DEVICE/" probe.qsf
  fi
  grep -n "DEVICE\|VIRTUAL" probe.qsf
fi
quartus_map probe -c probe
if [ "$FIT" = 1 ]; then
  quartus_fit probe -c probe || true
fi
