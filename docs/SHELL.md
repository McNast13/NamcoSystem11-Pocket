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

## First hardware install (2026-10-19)
Bitstream: run 39318148815 (seed 99, 18,266 ALMs): worst timing misses are clk_3x setup -0.16 ns (slow 85C) and clk_1x->clk_3x hold -0.04 ns (fast model); everything else met.
SD layout (same convention as the Dragon 32 core): `Cores/McNast13.NamcoSystem11/{bitstream.rbf_r,core.json,data.json,video.json,audio.json,input.json,interact.json,icon.bin}`,
`Platforms/namco_system11.json` + `Platforms/_images/namco_system11.bin` (placeholder artwork), `Assets/namco_system11/common/tekken2ud.json` + `tekken2ud/rom_*.bin`
(Tekken 2 US TES3 VER.D from the user's own MAME set via tools/rom_packer.py). Launch: Pocket menu -> Namco System 11 -> choose `tekken2ud.json` as the Game.

### Diagnostic build installed (run 39326342385, seed 99, 18,229 ALMs)
Timing: every hold check met; clk_2x setup -0.04 ns (0C slow model), video-clock setup -0.66 ns (0C) inside the diagnostic screen generator only.
Boots into the diagnostic screen (core setting "Diagnostic screen", default on). Rows (green = 1, MSB left): 1 system flags, 2 MIPS PC, 3 C76 first PC + alive flags,
4 platform/keycus bytes + RAM-clear/SDRAM activity, 5 frame counter, then colour ramps/bars. Flag order in core_top_full.sv `flags_a`.

## Status at pause (2026-10-19, late)
**Hardware result so far:** the core loads on a real Pocket (no setup errors after the core.json shortname and variants.json fixes), the game file is selectable and the data slots load, but the
screen shows only a uniform blue-grey picture with one thin speckled line near the top (video recorded by the owner). The diagnostic screen did not appear: the "Diagnostic screen" setting is
not on by default on the device, so the game video path (core held in reset, no sync) was being shown.
**Installed on the SD card:** diagnostic build run 39326342385 (seed 99) without the automatic fallback.
**Fixed in the repo, not yet built successfully:** (1) outputs retimed to the falling edge of video_rgb_clock (same-edge race with the APF DDIO, as in the Dragon 32 core); (2) the diagnostic screen
and a 1 kHz tone appear automatically when the core produces no vsync for ~150 ms; (3) `S11_NO_MDEC` build option (workflow input `no_mdec`) because (1)+(2) made the MDEC build miss the 5CEBA4 by 2 LABs
(1,850 needed of 1,848; runs 39331586183/594479/602680).
**Blocker:** GitHub Actions refuses to start jobs ("recent account payments have failed or your spending limit needs to be increased", runs 39333312622 onward). Needs billing/spending-limit review, a public repo,
or a local Linux VM (UTM is installed; Quartus has no macOS build).
**Next steps once builds run:** `gh workflow run pocket-shell.yml -f project=s11full -f no_mdec=true -f label=gNN -f "qsf_extra=set_global_assignment -name SEED NN"` for seeds 99/22/44, install the best
package (copy `bitstream.rbf_r` and `interact.json` to `Cores/McNast13.NamcoSystem11/` on the SD card), photograph the diagnostic screen, and use its flags (docs above) to see how far the core gets.
If the picture still does not reach the scaler, build a minimal video-only core to test the APF video path on its own (Dragon 32's video_frame_buffer.sv shows a proven 60 Hz, real-pixel-clock approach).
Remaining timing misses (none clean in all four models yet): see docs/BASELINE.md.


## Bring-up log 2026-10-20 (hardware debugging session)
Where it stands: the video, audio, PLL, loader and bridge shell are verified on a real Pocket; the System 11 core boots to the game's startup code but the game never draws
(GPU never touched). Findings, in the order they were established:
1. The flat grey screen with one bright line was NOT broken video. (a) The `psx_apf_video` path works on hardware (video-only test core `s11vid`, formatter and raw paths). (b) The falling-edge
   output retime (copied from the Dragon 32 core) corrupted colour bits; the PlayStation core registers outputs on the rising edge: macro `S11_POSEDGE_OUT` (use it). (c) The
   "Diagnostic screen" core setting does not take effect on the device, so the mux showed the (black) game video; macro `S11_FORCE_DIAG` forces the diagnostic screen and tone.
2. PLL placement was a red herring (pinned and unpinned both behave the same).
3. With the diagnostic forced on the status is: all data slots loaded (idx 0,1,3,6,7,8,9), platform byte 0x14 (System 11), KEYCUS 1, RAM cleared, C76 BIOS running (first PC 0xC030,
   C352 written, response flag set, never reached the mailbox-service ISR, MIPS mailbox write count 0), MIPS fetched game-entry code (boot bits 0x01500800/0x01700800), GPUSTAT stays at the
   reset value 0x14802000 (never configured), no VBLANK-mask write, DDRAM (VRAM) reads/writes never seen. First genuine CPU fault = Reserved Instruction (code 0xA).
4. EEPROM scan (`S11_NO_EE_SCAN`) and blank EEPROM image (`S11_EE_BLANK`) made no difference.
5. Rate probe (build `rateA`): CPU clock enable is high every cycle (full speed, not paused), ~3.36 M instruction-fetch requests/s = continuous sequential cache-line refills, i.e. the CPU is
   running straight-line code through memory (PC samples span 0x80000000-0x80100000, two landed in all-zero RAM = NOP sled). Best hypothesis: the game image in RAM is gone (zeroed under
   the CPU) or the decompressor output is wrong.
Next steps (in order):
 a. Count RAM-clear sessions and `ioctl_download` sessions (rising edges of `clr_active` / `ioctl_download` in SYSTEM11.sv) and show them on the diagnostic screen: if a second clear/download
    happens after the CPU started (e.g. the nonvolatile EEPROM slot loads after reset release) the RAM is wiped under the running game. Fix: hold the emu in reset until every slot incl. slot 9 is
    done, and never clear RAM after the first run.
 b. If only one clear: capture the instruction words fetched at 0x80010000 / 0x80196D8C (expect 0x08065B63 and 0x3C02801D) and a checksum of the decompressed image to test the decompressor/SDRAM read path.
 c. MiSTer author's notes (references/SYSTEM11_MiSTer/rtl/psx_top.vhd comments) record the same class of stall; his latches are exported through `synth/pocket_probe/variants/s11_bootbits.apply`.
Diagnostic screen layout (forced-diag builds): rows 0-3 flags/live PC/C76/platform, then extra rows 4-9 = sampled PC, CPU clock enables per second, boot-progress bits,
instruction-fetch requests/s, data requests/s, paused cycles/s (see core_top_full.sv `.extra(...)`). Decode photos with `tools/diag_decode.py`; simulate the boot with `tools/s11sim/`.
Build recipe used all session: `gh workflow run pocket-shell.yml -f project=s11full -f no_mdec=true -f label=X -f 'qsf_extra=set_global_assignment -name SEED 99\nset_global_assignment -name VERILOG_MACRO "S11_POSEDGE_OUT=1"\nset_global_assignment -name VERILOG_MACRO "S11_FORCE_DIAG=1"'`
(one build is ~20 min of Actions; the test cores are `-f project=s11vid`). The SD card currently holds build `rateA` (run 39502603486).


## Mined from the MiSTer author's notes (references/SYSTEM11_MiSTer, SYSTEM11.sv + rtl/psx_top.vhd comments) - read before resuming
Same failure class as ours, recorded by XelaNotPu during his own bring-up:
- **"MIPS reached game code but isn't rendering" was caused by the C76 sound CPU never completing its IPL/mailbox handshake.** His probes: `c76_ever_bios` (C76 ran the TB0 timer ISR store @0xC279),
  `c76_ever_c098` (reached the TB1 mailbox-service ISR @0xC31F), `c76_resp` (wrote handshake word 0xBD30), MIPS mailbox write count (0 = MIPS not sending), RAM[0x83] toggling = TB0 alive
  (the 0xC151 wait loop is normal). Ours (hardware, this session): resp=1, ever_bios=0, ever_c098=0, mailbox writes=0, ever_sprog=0, C76 PC parked near 0xC1BD, "derailed" flag set. => the C76 timer
  interrupt (TB0) looks DEAD on the Pocket. MAME reaches the first game code only after a BIOS handshake timeout.
- **My unsimulated area patches touch exactly that logic:** `c76_sfr_ram` (SFR file -> M10K, ~350 ALMs saved; timer start/reload/interrupt-priority SFRs 0x1E,0x40,0x70,0x77,0x78,0x7A,0x7B,0x7D-0x7F stay in FFs
  but everything else is now registered-read RAM) and `c76_ram_bram` (512 B internal RAM -> BRAM, registered read; I also tied dbg_ram80/dbg_ram83 to 0, so those two diagnostic values read 0 by design).
- **SDRAM channel 3 is shared by RAM clear, C76 SPROG reads and C352 wave reads, and each requester just waits for the next `sdramCh3_done` pulse.** He fixed a bug where a stray done pulse was latched as the
  C76's opcode byte (C76 then ran RAM contents -> BRK -> halt @0xC1E9). Our `shim/s11_sdram_shim.sv` must reproduce the original `sdram.sv` done semantics exactly (one pulse per request, none spurious).
- **Main RAM must be zero:** the game reads never-written regions (e.g. 0x802B1CE0, the EEPROM-default source buffer) expecting 0; SDRAM powers up as garbage -> his EEPROM verify @0x8003E6xx (Tekken 1 binary)
  never converged. `reset_or = RESET | buttons[1] | status[0] | ioctl_download | ~ram_cleared` and a 4 MB zero-fill state machine (CLR_IDLE -> SETTLE (16-bit counter, rearms if a new download starts) ->
  ISSUE/WAIT -> DONE) run after the last download. Our hardware reaches `ram_cleared=1`, but whether the writes actually landed in the Pocket SDRAM is UNVERIFIED.
- Other facts: first game code is a late-boot ROM region 0x1FC2xxxx handshake then RAM; `zn_platform_r[4]` = System 11 mode, bit5 = gputype1 force; his SDRAM write-timing experiments (clk_3x_ps +90 deg)
  are noted in the source; PSX data-cache/IO latches in this trimmed edition only fire on cache-miss requests, so "last IO read" style latches read 0 (use the bus_* signals instead).
Decompressed-image facts (tools/s11sim): entry 0x80010000 = `j 0x80196D8C` followed by TEXT strings and data tables; real code starts at 0x80196D8C (crt0) / 0x801A0xxx. Every PC we sampled on hardware
(0x80000D30..0x800FEE20) is data or zeros in that image => the hardware CPU is executing DATA, i.e. it did not follow the entry jump (or the code it fetched differs).

## Resume plan (ranked by information per build; each hardware build ~20 min of Actions)
1. **Free, no hardware: simulate the C76 variants.** Extend `tests/c352/run.sh` (nvc dual-DUT) to `c76.vhd` + `m37702.vhd` with the C76 BIOS (`rom_8.bin`, 16 KB, from rom_packer) and a stub mailbox: run reference vs patched
   (`c76_sfr_ram`, `c76_ram_bram`) for a few million cycles, compare PC traces and RAM[0x83] toggling / TB0 ISR (@0xC279) / reaching 0xC31F. Any divergence is the bug. Also fuzz the SFR read/write semantics of the ten
   special registers and the interrupt request/ack path.
2. **One build with the discriminating probes** (add to the diagnostic extra rows): (a) first four distinct instruction-fetch lines at/after 0x80010000 (expect 0x80010000, then 0x80196D80...) to see whether the entry jump is
   followed; (b) the instruction word delivered for 0x80010000 (expect 0x08065B63); (c) real C76 RAM[0x80]/[0x83] (registered copies, not the tied-off taps) and `ever_bios`/`ever_c098`; (d) count of `clr_active` and
   `ioctl_download` sessions and a periodic readback of SDRAM word 0x2B1CE0 plus 0x0 and 0x3FFFFC after the clear (the author's own runtime monitor idea, gated so it cannot collide with the SPROG/wave FSMs).
3. **Hardware A/B of my area variants** (macro-selectable in tools/build_core_tree.py): build without `c76_sfr_ram` (+~350 ALMs; we have ~700 spare with no_mdec), then also without `c76_ram_bram`, then without
   `cpu_execute_share`; whichever restores ever_bios/ever_c098 or the entry-jump behaviour is the culprit. (`gte_laxer`, `ps_patches`, `gpu_*` variants are GPU/GTE side and unlikely.)
4. **SDRAM self-test in the shell** before releasing the emu reset: write/readback patterns through the same ch1/ch3 path (incl. read-after-write to the same address and the 4 MB clear), show pass/fail on the diagnostic
   screen. Also check the shim's `sdramCh3_done`/`readack`/`writeack` pulse counts against the number of requests.
5. If the shell and variants are clean: checksum the decompressed game image (accumulate over the CPU's SDRAM write stream during decompression in the emulator and in hardware) to test decompressor/SDRAM-read integrity.
6. When the game finally draws: switch the diagnostic default back off, restore the interact "Diagnostic screen" setting handling (the setting does not take effect on the device - find out why), drop the probe
   extras from the shipping build, and go back to timing closure (seed sweep) and MDEC restore (+~600 ALMs).


## Tekken 1 reference (added 2026-10-20 late) - ROMs in ~/Downloads/tekken.zip (MAME `tekken`, MRA "Tekken (Asia TE4 Ver.C)" from _alternatives/_Tekken; the MRA "Tekken (TE2 Ver.C)" needs te2verc.* which this zip lacks)
Pack: `python3 tools/rom_packer.py "references/SYSTEM11_MiSTer/releases/_Arcade/_alternatives/_Tekken/Tekken (Asia TE4 Ver.C).mra" --roms <dir with tekken.zip + namcoc76.zip> --out OUT/tekken1 --instance tekken1`
(config word 0x14 00 00 00: platform 0x14, KEYCUS 0). SD layout: `Assets/namco_system11/common/tekken1.json` + `common/tekken1/rom_*.bin` (like tekken2ud). Simulator findings (tools/s11sim on Tekken 1): game entry 0x80010000 is
real code (decompress ~53 M instr), 0x80018654 = early game code (matches the MiSTer author's note), **0x8003E600..0x8003E700 = the EEPROM compare/verify routine** (exactly the author's "EEPROM verify never converges" loop), EEPROM
I/O code at 0x8003D4B0, 0x802B1Cxx default buffer referenced from 0x80042150. With I/O stubbed to 0 the emulator spends 99.9% of its time in that page polling 0x1FA30040. Hardware test to run on resume: load tekken1.json on the
diagnostic build: PC samples in 0x8003E6xx => the author's known failure with his known cause/fix (main RAM not really zero / EEPROM state: verify the 4 MB zero-fill landed and zn1_io EEPROM readback);
PC samples in data regions like Tekken 2 => a system-level fault (C76 variants, SDRAM shim, CPU variants). Either result halves the search space.


## CORRECTION and Tekken 1 hardware result (2026-10-20, last test of the night)
**Correction:** the "instruction-fetch requests per second" counter (diag row 7 in build rateA) reads ~2^25/10 (0x00333xxx) in BOTH Tekken 1 and Tekken 2: a fixed request cadence, not a measure of the
workload. The earlier inference "continuous sequential fetches = NOP sled sweeping RAM" drawn from it is WRONG and is withdrawn. What the counters do show: CPU clock enable high every cycle (full speed), paused cycles 0.
**Tekken 1 on hardware (build rateA, tekken1.json):** config 0x14/KEYCUS 0 loaded, RAM-clear flag set, boot bits 0x01700800 and GPUSTAT behaviour identical to Tekken 2 (GPU never touched, no IRQ mask).
Sampled PCs (diag row 4): 0x8003E650 (inside the EEPROM compare/verify routine = the MiSTer author's failing loop), 0x8002B6A4 (real code), 0x800732EC / 0x8006037C / 0x8007A9EC (data tables in the Tekken 1 image).
Conclusion: BOTH games execute a mix of real code and data => control flow is going wrong at system level, matching the author's documented cause (uninitialised/garbage RAM -> corrupt tables/pointers -> wild jumps, EEPROM verify never
converges). The Tekken 2 observation that every sampled PC is data was probably the same effect seen later in time. FIRST THING ON RESUME: verify the 4 MB zero-fill actually landed in the Pocket SDRAM (plan item 2d / 4),
then compare against the C76 variant theory. The SD card holds core build rateA plus both tekken2ud.json and tekken1.json.
