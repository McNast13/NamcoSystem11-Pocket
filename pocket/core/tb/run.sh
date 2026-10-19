#!/bin/sh
# Simulate the data-slot loader (needs iverilog: brew install icarus-verilog)
set -e
D=$(cd "$(dirname "$0")" && pwd)
# usage: run.sh [CLK_HALF_ns] [GAP_MIN] [GAP_RND]   defaults: 33.87 MHz core clock, a word every 2..9 clk_74a (very fast host)
iverilog -g2012 -P tb_s11_loader.CLK_HALF=${1:-14.762} -P tb_s11_loader.GAP_MIN=${2:-2} -P tb_s11_loader.GAP_RND=${3:-7} -o "${TMPDIR:-/tmp}/tb_s11_loader.vvp" "$D/tb_s11_loader.v" "$D/../s11_loader.v"
vvp "${TMPDIR:-/tmp}/tb_s11_loader.vvp"
