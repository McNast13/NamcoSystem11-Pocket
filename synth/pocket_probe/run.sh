#!/bin/sh
# Usage (inside the Quartus container, cwd = copy of SYSTEM11_MiSTer tree): run.sh [variant[,variant...]]
set -e
cp /probe/probe.qsf probe.qsf
echo '`define BUILD_DATE "000000"' > build_id.v
for v in $(echo "$1" | tr ',' ' '); do
  [ -x "/probe/variants/$v.sh" ] && "/probe/variants/$v.sh"
done
quartus_map probe -c probe
