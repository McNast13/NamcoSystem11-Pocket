#!/bin/sh
# Usage (inside the Quartus container, cwd = copy of SYSTEM11_MiSTer tree): run.sh [variant[,variant...]]
set -e
cp /probe/probe.qsf probe.qsf
echo '`define BUILD_DATE "000000"' > build_id.v
for v in $(echo "$1" | tr ',' ' '); do
  [ -x "/probe/variants/$v.sh" ] && "/probe/variants/$v.sh"
done
quartus_map probe -c probe

if [ "$FIT" = 1 ]; then
  # emu has far more pins than the device; the fit is for logic/memory/DSP only
  echo 'set_instance_assignment -name VIRTUAL_PIN ON -to *' >> probe.qsf
  [ -n "$FIT_DEVICE" ] && sed -i "s/^set_global_assignment -name DEVICE .*/set_global_assignment -name DEVICE $FIT_DEVICE/" probe.qsf
  grep -n "DEVICE" probe.qsf
  quartus_fit probe -c probe || true
fi
