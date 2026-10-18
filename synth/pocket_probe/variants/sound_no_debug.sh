#!/bin/sh
# Leave every c76_sound dbg_* port unconnected (JTAG/overlay diagnostics don't exist on
# the Pocket), so the ring buffers, mailbox forensics and PC trackers are pruned.
sed -i -E '/\.dbg_c352_wrcnt/,/\.dbg_c76resp/ s/\.(dbg_[A-Za-z0-9_]+)\([^()]*\)/.\1()/g' SYSTEM11.sv
sed -n '/\.dbg_c352_wrcnt/,/\.dbg_c76resp/p' SYSTEM11.sv | head -12
