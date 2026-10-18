#!/bin/sh
# Usage (inside the Quartus container, cwd = copy of SYSTEM11_MiSTer tree): run.sh [variant]
set -e
cp /probe/probe.qsf probe.qsf
[ -n "$1" ] && [ -x "/probe/variants/$1.sh" ] && "/probe/variants/$1.sh"
quartus_map probe -c probe 2>&1 | tail -60
