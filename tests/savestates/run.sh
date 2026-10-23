#!/bin/sh
# usage: tests/savestates/run.sh   reset-only savestates sequencer (synth/pocket_probe/variants/savestates_reset_only.apply) vs an idealized system
set -e
D=$(cd "$(dirname "$0")" && pwd); R=$D/../..; O=${TMPDIR:-/tmp}/sstb
rm -rf "$O"; mkdir -p "$O/tree/rtl"; cd "$O"
cp "$R/references/SYSTEM11_MiSTer/rtl/savestates.vhd" tree/rtl/
printf '   .save_state            (ss_save),\n   .load_state            (ss_load),\n' > tree/SYSTEM11.sv
python3 "$R/synth/pocket_probe/variants/savestates_reset_only.apply" "$O/tree"
nvc --std=08 -a --relaxed tree/rtl/savestates.vhd "$D/tb_ss_reset.vhd"
nvc --std=08 -e tb_ss_reset
nvc --std=08 -r tb_ss_reset 2>&1 | tail -5
