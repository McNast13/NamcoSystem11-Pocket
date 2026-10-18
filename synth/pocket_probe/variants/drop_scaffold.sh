#!/bin/sh
# use the pll_cfg stub instead of the Altera reconfig IP
sed -i '/QIP_FILE sys\/pll_cfg.qip/d' probe.qsf
echo 'set_global_assignment -name VERILOG_FILE pll_cfg_stub.v' >> probe.qsf
grep -n "pll_cfg" probe.qsf
