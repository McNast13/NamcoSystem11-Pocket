# Data-slot loader (pocket/core/s11_loader.v)

The Pocket host streams each data slot through the APF bridge as 32-bit writes (`bridge_wr`, `bridge_addr`, `bridge_wr_data`, clk_74a). The core sets
`bridge_endian_little = 1`, so byte 0 of a file is bits [7:0] of the first word. `pocket/dist/Cores/McNast13.NamcoSystem11/data.json` places slot *n* at
bridge address `n << 24`; the loader decodes `bridge_addr[27:24]` as the window.

| Window / slot | File (rom_packer.py) | Destination | MiSTer equivalent |
|---|---|---|---|
| 0 | rom_0.bin, 4 MB MIPS program | SDRAM `0x400000` | ioctl index 0 |
| 1 | rom_1.bin, 4 B config: platform, KEYCUS, gun flag | `cfg_*` registers | index 1 |
| 2 | fixed ROM (<= 2.5 MB), optional | SDRAM `0x480000` | index 2 |
| 3 | rom_3.bin, banked ROM (<= 16 MB) | SDRAM `0x800000` | index 3 |
| 4 | banked ROM second 16 MB, optional | SDRAM `0x1800000` | index 3 (> 16 MB) |
| 6 | rom_6.bin, C76 SPROG 256 KB | SDRAM `0x2800000` | index 6 |
| 7 | rom_7.bin, C352 wave ROM (<= 4 MB) | SDRAM `0x2840000` | index 7 |
| 8 | rom_8.bin, C76 internal BIOS 16 KB | C76 BIOS RAM, byte writes | index 8 |
| 9 | EEPROM image 4 KB (nonvolatile save) | EEPROM RAM, word writes | index 9 |

Bases are the MiSTer core's (`SYSTEM11.sv` BIOS_START etc.) and are parameters of the module. The Pocket's SDRAM is 64 MiB (MIRLO64 documents the same), so
this layout (top at `0x2C40000`) fits.

**Structure.** bridge write (edge-detected, `bridge_addr[31:28] == 0`) -> 1024 x 58-bit dual-clock FIFO (8 M10K) -> two-stage read pipeline -> destination.
One word per core clock when the destination keeps up; the memory output is valid/ready (`mem_valid` holds until `mem_ready`); the C76 BIOS is serialised four
bytes per word. The bridge cannot be stalled, so `ld_overflow` latches if the FIFO ever fills, and `ld_busy` stays high until everything is delivered (hold the
core in reset on `ld_busy`). Writes outside the data window (command handler at `0xF8xxxxxx`, interact, ...) are ignored.

**Verified** (`pocket/core/tb/run.sh`, iverilog; data, address, order and destination of every word, random `mem_ready` back-pressure): a full Tekken 2-sized
image mix passes with a 33.87 MHz core clock and the host writing a word every 8..15 clk_74a, and with a 100 MHz core clock and a word every 2..9 clk_74a. It
overflows (flagged, not silent) if the host writes faster than about one word per 4.5 clk_74a into a 33.87 MHz core, because the C76 serialiser then runs
at 4 clk per word; the real bridge is slower than that (limited by the SD card and the PIC32 link), but this has not been measured on hardware.

**Shell fit** (run 39277737963, real 5CEBA4F23C8): whole shell 477 ALMs, loader 97 ALMs + 8 M10K, clk_74a setup +5.3 ns, hold +0.36 ns.

**Not done yet.** The loader is wired to a placeholder sink on clk_74a: the real consumers (Pocket SDRAM controller, C76/EEPROM RAM ports, config registers) and the
core clock domain do not exist yet. `dataslot_requestwrite_ack` is tied high; it should be held until the SDRAM controller is ready (as MIRLO64 does).
EEPROM save-back (bridge reads of slot 9) and the instance-file flow on a real Pocket are untested. Design notes: the APF `data.json` parameter bits and the
instance JSON layout were written from MIRLO64's package and the APF documentation recalled from memory; verify them on a device.
