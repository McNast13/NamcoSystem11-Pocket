#!/bin/sh
# Usage (inside the Quartus container, cwd = copy of SYSTEM11_MiSTer tree): run.sh [variant]
set -e
cp /probe/probe.qsf probe.qsf
echo '`define BUILD_DATE "000000"' > build_id.v
[ -n "$1" ] && [ -x "/probe/variants/$1.sh" ] && "/probe/variants/$1.sh"
quartus_map probe -c probe
