#!/bin/sh
set -e
D=$(cd "$(dirname "$0")" && pwd)
iverilog -g2012 -o "${TMPDIR:-/tmp}/tb_ioctl.vvp" "$D/tb_ioctl_bridge.v" "$D/../s11_ioctl_bridge.v"
vvp "${TMPDIR:-/tmp}/tb_ioctl.vvp"
