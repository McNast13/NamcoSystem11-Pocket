#!/bin/sh
# Loader -> SDRAM controller -> chip model readback (needs iverilog and the openfpga-PlayStation submodule for the chip model)
set -e
D=$(cd "$(dirname "$0")" && pwd); R=$D/../../..; O=${TMPDIR:-/tmp}/s11ram; mkdir -p "$O"
cat > "$O/altddio_out.sv" <<'V'
module altddio_out #(parameter extend_oe_disable="", intended_device_family="", invert_output="",
    lpm_hint="", lpm_type="", oe_reg="", power_up_high="", integer width=1) (
    input wire [width-1:0] datain_h, datain_l, input wire outclock, output wire [width-1:0] dataout,
    input wire aclr, aset, oe, outclocken, sclr, sset);
    assign dataout = oe ? (outclock ? datain_h : datain_l) : {width{1'bz}};
endmodule
V
# the stock model keeps only row bits [5:0]; widen it to [8:0] so the wave ROM / sprog / program regions do not alias
sed -e 's/reg \[15:0\] mem \[0:(1<<18)-1\]/reg [15:0] mem [0:(1<<21)-1]/' -e 's/i < (1<<18)/i < (1<<21)/' -e 's/function \[17:0\] index/function [20:0] index/' -e 's/{b, r\[5:0\], c}/{b, r[8:0], c}/' \
    "$R/references/openfpga-PlayStation/sim/memory/sdram_chip_model.sv" > "$O/sdram_chip_model.sv"
iverilog -g2012 -o "$O/tb.vvp" -s tb_s11_ram -Ptb_s11_ram.CAS=${1:-3} "$O/altddio_out.sv" \
  "$O/sdram_chip_model.sv" \
  "$D/../memory/psx_sdram_ctrl.sv" "$D/../s11_loader.v" "$D/../s11_ram.sv" "$D/tb_s11_ram.sv"
vvp -n "$O/tb.vvp"
