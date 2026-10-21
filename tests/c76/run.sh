#!/bin/sh
# usage: tests/c76/run.sh [NCLK] [variant ...]   dual-DUT: reference c76/m37702 vs the same with the named variants/*.apply applied (default c76_sfr_ram)
# BIOS = rom_8.bin from a packed instance (build/tekken2ud/rom_8.bin, produced by tools/rom_packer.py).
set -e
D=$(cd "$(dirname "$0")" && pwd); R=$D/../..; O=${TMPDIR:-/tmp}/c76tb; N=${1:-3000000}; shift || true
V=${*:-c76_sfr_ram}
rm -rf "$O"; mkdir -p "$O/tree/rtl"; cd "$O"
cp "$R/references/SYSTEM11_MiSTer/rtl/c76.vhd" "$R/references/SYSTEM11_MiSTer/rtl/m37702.vhd" tree/rtl/
for v in $V; do python3 "$R/synth/pocket_probe/variants/$v.apply" "$O/tree"; done
python3 -c "
b=open('$R/build/tekken2ud/rom_8.bin','rb').read()[:16384]
open('bios.hex','w').write('\n'.join('%02X'%x for x in b)+'\n')"
python3 -c "
b=open('$R/build/tekken2ud/rom_6.bin','rb').read()[:262144]
open('sprog.hex','w').write('\\n'.join('%02X'%x for x in b)+'\\n')"
nvc --std=08 --work=orig:orig -a --relaxed "$D/dpram_stub.vhd" "$R/references/SYSTEM11_MiSTer/rtl/m37702.vhd" "$R/references/SYSTEM11_MiSTer/rtl/c76.vhd"
nvc --std=08 -L . -a --relaxed "$D/dpram_stub.vhd" tree/rtl/m37702.vhd tree/rtl/c76.vhd "$D/tb_c76_cmp.vhd"
nvc --std=08 -L . -e -gNCLK=$N ${TB_GENERICS} tb_c76_cmp
nvc --std=08 -L . -r tb_c76_cmp 2>&1 | grep -v "DBG\|SFRWR\|^ *$\|IT \|RESETVEC" | tail -30
