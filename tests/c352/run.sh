#!/bin/sh
# usage: tests/c352/run.sh <patched c352.vhd> [ROM_LAT] [NSAMP]   (reference = references/SYSTEM11_MiSTer/rtl/c352.vhd)
set -e
D=$(cd "$(dirname "$0")" && pwd); R=$D/../..; O=${TMPDIR:-/tmp}/c352tb; rm -rf "$O"; mkdir -p "$O"
cd "$O"
nvc --std=08 --work=orig:orig -a "$R/references/SYSTEM11_MiSTer/rtl/c352.vhd"
nvc -L . --std=08 -a "$1" "$D/tb_c352_cmp.vhd"
nvc -L . --std=08 -e -gROM_LAT=${2:-10} -gNSAMP=${3:-300} tb_c352_cmp
nvc -L . --std=08 -r tb_c352_cmp 2>&1 | tail -20
