# Pocket shell architecture

`pocket/core/core_top_full.sv` (project revision `s11full`) wraps the System 11 core for the Analogue Pocket. The core itself is
`references/SYSTEM11_MiSTer/SYSTEM11.sv` (`emu`), unchanged except for the edits in `pocket/core/emu/pocket_emu.apply`, with the
area/timing variants from `synth/pocket_probe/variants` applied by `tools/build_core_tree.py` into `pocket/build/core_tree`
(generated, not committed). `s11` (core_top.sv) is the older skeleton revision that only carries the loader/memory/PLL pieces.

| Pocket side | Implementation |
|---|---|
| host/target commands, data table | `core_bridge_cmd.v` (Analogue template via MIRLO64) at bridge `0xF8xxxxxx` |
| ROM / BIOS / EEPROM / config load | `s11_ioctl_bridge.v`: bridge writes -> dual-clock FIFO -> the MiSTer `ioctl_*` stream (16-bit words, `ioctl_wait` pacing, one file per index with a download gap between) that `emu` already consumes. Slot map in `docs/LOADER.md` and `pocket/dist/.../data.json` |
| clocks | `s11_pll.sv`: 33.87 / 67.74 / 101.61 MHz core clocks, 53.69 MHz video clock and its 90 degree copy, all from 74.25 MHz |
| main RAM + ROMs | `emu`'s `sdram` instance is a shim (`shim/s11_sdram_shim.sv`) in front of the MIT `psx_sdram_ctrl` (single chip, CAS latency 3). `emu`'s own ch3 arbiter (download / RAM clear / SPROG / wave ROM reads) is untouched |
| GPU VRAM | `emu`'s `DDRAM_*` port -> `s11_vram.sv` -> MIT `psx_vram_psram` on the two PSRAMs (clk_2x) |
| video | `emu`'s raw hs/vs/hblank/vblank/ce/rgb -> `psx_apf_video` (MIT, PS Pocket): APF scaler slot selection, padding, centring; `video.json` has the five 240-line slots (640/320/256/384/512) |
| audio | C352 output (88.2 kHz) -> one-pole low-pass -> 48 kHz -> MIRLO64 I2S FIFO (`audio/s11_audio.sv`) |
| inputs | `cont*_key/joy` synchronised to clk_1x, mapped to the MiSTer joystick word (`map_joy` in core_top_full.sv): Y/X/B/A = Button1..4 (LP/RP/LK/RK), L/R = Button5/6, Select = Coin, Start = Start; sticks go to the analog inputs |
| DIP / service | `interact.json` -> bridge writes at `0x50000000..08` -> `status[96]` (DIP1 Test), `status[97]` (DIP2 Freeze), held Service button |
| EEPROM save | data slot 9 is nonvolatile; bridge reads of `0x09xxxxxx` are served from a shadow copy of zn1_io's EEPROM RAM refreshed ~1.5 s after each EEPROM write |

## Not verified on hardware
Everything. In simulation only: the loader FIFO/ioctl stream (`pocket/core/tb/run_ioctl.sh`, `run.sh`), the loader -> SDRAM controller -> chip model path
(`run_ram.sh`) and the C352 cache change. The APF `data.json` parameter bits, the instance JSON, the interact variables and the `input.json` key names were
written from the MIRLO64 and PS Pocket packages plus APF documentation recalled from memory.
