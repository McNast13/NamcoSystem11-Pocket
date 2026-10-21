#!/bin/sh
set -e
D=$(cd "$(dirname "$0")" && pwd)
iverilog -g2012 -o "${TMPDIR:-/tmp}/tb_ioctl.vvp" "$D/tb_ioctl_bridge.v" "$D/../s11_ioctl_bridge.v"
vvp "${TMPDIR:-/tmp}/tb_ioctl.vvp"
iverilog -g2012 -o "${TMPDIR:-/tmp}/tb_c76bios.vvp" "$D/tb_c76bios.v" "$D/../s11_ioctl_bridge.v"
vvp "${TMPDIR:-/tmp}/tb_c76bios.vvp" | grep -E "bad bytes|PASS|FAIL"
