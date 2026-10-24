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


## ROOT CAUSE of the C76 failure found by simulation (2026-10-21): the C76 BIOS was loaded with every 4n+1 byte missing
**Not the area patches.** `tests/c76/run.sh` (nvc dual-DUT, reference c76+m37702 vs the same with `c76_sfr_ram` applied, real C76 BIOS `rom_8.bin`, real SPROG `rom_6.bin`, substrate-like external bus, ce = clk_1x/2) shows
the patched C76 is cycle-identical to the reference over 20 M clocks: C098 at clk 25 k, wait loop 0xC151 at 1.3 M, then TB0 ISR (0xC279) and mailbox ISR (0xC31F) run forever (1488/2244 times in 20 M clocks). SPROG content
(zeros / 0xFF / garbage) and SPROG read latency do not matter to the BIOS reaching 0xC151.
Then: BIOS image variants. A BIOS with **every byte at offset 4n+1 zeroed** parks the C76 at **0xC1BD within ~100 clocks and never leaves** (milestones never reached) = the hardware symptom (PC parked ~0xC1BD, ever_bios=0, mailbox 0).
Cause: `s11_ioctl_bridge` emitted the low and high halves of each 32-bit word on consecutive clocks; SYSTEM11.sv's C76 BIOS byte writer (`c76bios_*`) writes byte 0 of a half on the clock after `ioctl_wr` and byte 1 one clock later,
but a new `ioctl_wr` takes priority over the pending byte, so byte 1 of the low half (offset 4n+1) was overwritten. `pocket/core/tb/tb_c76bios.v` (bridge -> verbatim SYSTEM11.sv writer -> 16 KB memory) reproduced it:
4,079 bad bytes / 4,096 never written; after the fix 0 bad. (MiSTer's hps_io spaces the halves further apart so the original never saw it.)
Fix: one idle clock between the halves (`S_MID` in `s11_ioctl_bridge.v`); `tb_ioctl_bridge.v` still passes, `pocket/core/tb/run_ioctl.sh` runs both. NOT yet built or tested on hardware.
Consequences: with a corrupted BIOS the C76 never handshakes, so the MIPS side waiting for it would derail exactly as observed; resume plan items 3 (A/B area variants) and the C76 half of 2 are deferred until a build with this fix is
tried. Keep the RAM zero-fill / SDRAM probes (plan 2d/4) for the next build in case the game still derails. Also check every other consumer of the bridge for the same back-to-back assumption (EEPROM path, SPROG/wave SDRAM path both
accept either spacing; config word is consumed by `zn_platform_r` capture - not re-checked).


## Diagnostic screen layout from build `probe1` (2026-10-21, after the C76 BIOS fix)
Hardware result of build c76fix (photo): C76 first PC 0xC030, `ever_sprog`=1, C352 written, not halted (before the fix: parked at 0xC1BD, ever_sprog=0) => the C76 BIOS load is fixed on the device.
MIPS side unchanged: boot bits 0x01700800, ~0x333332E fetches/s, 0 data requests/s, sampled PC ~0x8004144C (Tekken 1, near the EEPROM verify/compare code).
Photo decoding note: `tools/diag_decode.py` drifts by a column under perspective; take photos square-on and upright, whole grid in frame.
Rows (green = 1, MSB left): 0 flags | 1 C76 status {halted, resp, ever_c098, ever_bios, c352_seen, derailed, 00, pc[23:0]} | 2 C76 first PC + {ever_sprog, halted, c352, reached_game} |
3 platform, keycus, {ram_cleared, reset, ioctl_download, sdram_req, readack, writeack, ch3_done, clr_active} | 4 sampled MIPS PC | 5 derail source PC (before the first fetch into the wild loop 0xBFC07xxx) |
6 boot bits (see s11_bootbits.apply) | 7 {first CPU fault ExcCode[31:28], 000, low-sled seen, faulting address[23:0]} | 8 last RAM instruction-fetch PC | 9 {C76 RAM80, RAM83 (tied 0 by design), MIPS mailbox write count[15:0]}.
Dropped from the screen: clock enables/s, fetches/s, data requests/s, paused cycles/s (they were constant), the live MIPS PC, GPUSTAT.
Not in this build: the SDRAM readback of 0x0 / 0x2B1CE0 / 0x3FFFFC after the RAM clear (needs a ch3-arbitrated FSM; do it next if row 5/7/8 do not explain the stall).


## probe1 hardware result (2026-10-21; photos Tekken 1 and Tekken 2, build c76fix+probe rows)
Both photos decode identically in the shared rows (lattice-calibrated per photo; `tools/diag_decode.py` is unreliable under perspective). Rows as in the probe1 layout above.
- **C76 is healthy on the device**: status 0x3800C151 = ever_bios(TB0 ISR ran)=1, ever_c098(TB1 mailbox ISR)=1, c352_seen=1, not halted, not derailed, PC = 0xC151 (the normal idle wait loop). resp=0 and the MIPS mailbox write count = 0 (MIPS never sends).
- **MIPS side**: first genuine CPU fault ExcCode = 0xA (Reserved Instruction) in both games (row 7 = 0xA0000000 Tekken 1, 0xA1000000 Tekken 2: low-sled flag set only in Tekken 2), derail_src = 0 (never reached the 0xBFC07xxx wild loop),
  boot bits unchanged 0x01700800, GPU still never touched, sampled PC 0x800466DC (T1) / 0x800316DC (T2), last RAM fetch 0x800D7Fxx (T1) / 0x800A7Fxx (T2). Platform 0x14, keycus 0 (T1) / 1 (T2), RAM cleared = 1 in both.
- **Conclusion**: the MIPS decodes a Reserved Instruction early in game init in both games, i.e. it executes data/garbage or our CPU decoder rejects a real opcode (suspects: `cpu_execute_share`, `gte_laxer`/GTE patches, instruction-cache/SDRAM fetch integrity).
## probe2 layout (build `probe2`): the missing facts for that RI
Row 5 = EPC of the first fault (the faulting PC), row 6 = `cpu_dbg_fault_a1` ({irqVecCount[31:24], 000, maxRAMPC[20:0]}), row 9 = RA (r31) at the first fault; rows 0-4, 7, 8 as probe1 (boot-bits row dropped, constant; mailbox row dropped).
Next: look up the word at EPC in the Tekken 1/2 decompressed image (tools/s11sim): if the image holds a valid opcode there, the hardware fetched/decoded it wrongly (SDRAM/icache or a CPU patch); if the image itself holds data there, control flow derailed before it (look at RA / the jump source).


## probe2 hardware result (2026-10-21; Tekken 1 and Tekken 2 photos) and probe3
Decoded (photos square-on; per-photo fixed lattice): rows 0-3 identical to probe1. Row 4 sampled PC 0x800645DC (T1) / 0x80057078 (T2); row 5 first-fault EPC = 0x00000000 (T1) / 0x0009416C (T2, bit 31 probably misread: 0x8009416C);
row 6 a1 = 0xFF094170 in BOTH games => irqVecCount saturated (255+ exception-vector entries) and maxRAMPC = 0x094170 (the highest KSEG0 PC ever committed, identical in two different games); row 7 {ExcCode A, ..., lowsled seen in T2 only};
row 8 last RAM fetch 0x800FC970 (T1) / 0x800D5370 (T2); row 9 RA = 0.
Image check (tools/s11sim snapshots at game entry, packed tekken1/tekken2ud): T2 entry 0x80010000 = `j 0x80196D8C`; T1 entry 0x80010000 is real code (addiu sp / jal 0x800106DC). The word at 0x8009416C is data in both (T2 0x0014020C = SYSCALL encoding, T1 0x00110000);
T1 sampled PC 0x800645DC lies in a table of 0x8010xxxx/0x8011xxxx pointers. maxRAMPC identical (0x94170) in both games and never beyond (T2's crt0 is at 0x80196D8C) => the CPU never follows the entry jump / never reaches the game proper.
The fetch cadence (one instruction fetch request per exactly 10 clocks, data requests 0) is what a straight-line sweep through memory with a ~10-clock cache line fill looks like (NOP/benign words, no loads).
Working theory: after game entry the CPU executes straight-line code that is not the game (all-zero RAM or stale/zeroed instruction-cache lines), reaches an RI/SYSCALL word, vectors to 0x80000080 (zeros) and sweeps again: irqVecCount saturates, maxRAMPC stalls.
probe3 (build `probe3`) tests it: row 1 = last NON-ZERO instruction-cache line-fill first word, row 6 = zero-word fills per window (2^25 clk), row 9 = non-zero fills per window; rows 4, 5, 7, 8 as before. High zero count, ~no non-zero fills => the CPU runs through zeros
(RAM not holding the image / SDRAM read path); mostly non-zero => it executes real data (control-flow bug).


## probe3 hardware result (2026-10-21) and probe4
probe3 photos (T1 / T2 identical in shared rows): zero-word instruction-cache fills per ~1 s window 0x947E / 0xA989 (~38-43 k), non-zero fills 1, last non-zero first-word ~0xAAAAAAAA (that value does not occur in the decompressed image; it does occur
in the compressed ROM data), first-fault EPC 0x00094BB4 in both games (probe2 saw 0x0009416C), first fault ExcCode 0xB (coprocessor unusable) with the low-sled flag set, C76 healthy, MIPS mailbox writes 0.
Open: instruction fetch requests run at one per 10 clocks (3.36 M/s) but only ~40 k/s are icache fills, so most fetches are NOT cached line fills (uncached fetches, i.e. kseg1/ROM, cost ~10 clocks each).
Checks done: (1) tests via pocket/core/tb/run_ram.sh now also cover the CPU's own RAM paths - posted ch2 writes with random byte enables, read-after-write instruction-cache line fills (captured on clk3x like cpu.vhd's icache) and plain
ch1 reads, strict SDR chip model, CL2 and CL3: PASS, so the controller/loader logic is not the culprit in simulation. (2) cpu_execute_share (the only CPU RTL patch) read through by hand: the shared add/sub/slt/shift is equivalent.
(3) The decompressed image (tools/s11sim) holds real code/data at 0x80010000..0x801C89D4 (T2) and the words at the probe2/3 fault addresses differ between the games (data), so the two games cannot both execute the image at 0x80094BB4.
probe4 (build `probe4`) shows: row 1 = the first instruction-cache fill word of the line at physical 0x10000 (game entry; expect 0x08065B63 in Tekken 2, 0x27BDFFE0 in Tekken 1, 0 = RAM empty there); row 5 EPC; rows 6, 8, 9 = the last three distinct
committed PCs before the first genuine fault (newest first: sequential +4 = straight-line, a jump = real control flow); row 7 {ExcCode, low-sled flag, fault addr}; row 4 sampled PC.


## probe4 hardware result (2026-10-21/22, build probe4 = run 39687105180; photos Tekken 1 and Tekken 2) and plan for next session
Decoded with the new `tools/diag_decode_calib.py` (fits the lattice to rows with known values; score 96/96 on both photos). Rows: 0 flags 737DFC20 / F37DFC20 (bit 31 = blink), 1 entry-line fill word, 2 C76 00C030B0, 3 platform 14008000 / 14018000 (keycus 0 / 1),
4 sampled PC, 5 first-fault EPC, 6/8/9 last three distinct committed PCs before the first fault (newest first), 7 {ExcCode, low-sled, fault address}.
- **Row 1 = 0 in both games**: either the line at 0x10000 was never requested through the instruction cache after reset, or its first fill word was zero. Ambiguous (the capture arms on the request and takes the next fill's first word); do not read it as "RAM empty at entry".
- **Tekken 1**: sampled PC 0x80046D7C, EPC = 0, ring = {0x4, 0, 0} (only PCs 0 then 4 seen), row 7 = 0xA0000000 (first fault ExcCode 0xA = Reserved Instruction, no low-sled). In the decompressed Tekken 1 image RAM[0..0xC] holds the stub
  `lui $k0,0xA000 / addiu $k0,$k0,0x800 / jr $k0` (all valid opcodes): so the CPU got a reserved instruction for a word that should be a LUI at physical 0 => the instruction fetched for address 0 is not what the boot code stored there
  (or the first fault is a different event than assumed). The first genuine fault is therefore EARLY in boot, not at game level.
- **Tekken 2**: sampled PC 0x80026250 (0x80066250 in a second lattice fit), first-fault ExcCode 0xB (coprocessor unusable), ring rows 6/8/9 = 0x000496A8 (or 0x000812A8) / 0x00049B00 / 0x00049B40, EPC 0x000416A4 (or 0x000936A4). The values in rows 5/6/7 differ between two equally
  good lattice fits (only the upper bits), the 0x49Bxx rows agree. The ring PCs have bit 31 clear (kuseg alias of RAM), well below the game text at 0x80010000+; in the image those words are data.
- Interpretation so far: the CPU takes a genuine fault (RI in T1, CpU in T2) very early, executing low-RAM addresses (0, 4 / 0x49Bxx), i.e. the boot-ROM/kernel-stub phase, before the game proper runs. The probe shows the FIRST fault only, so everything after it
  (irqVecCount saturated, sweeps) is downstream. Consistent with the earlier facts: C76 healthy, MIPS mailbox writes 0, GPU untouched, boot bits 0x01700800.
### Next session, ranked
1. Direct RAM readback on the device: a small ch3-arbitrated FSM (idle slots only, after ram_cleared and a few seconds of run) reading physical words 0x0, 0x4, 0x8, 0x10000 and 0x49B00 and showing them; compare with the simulator's image (T1: 3C1AA000 275A0800 03400008). This says whether
   RAM holds what the CPU wrote (write path / SDRAM) and whether instruction fetch returns it (icache). Tekken 1 and 2 both.
2. Make the first-fault capture trustworthy: also latch the boot-bits word and a free-running clock count at the first fault (early or late?), and the instruction word at EPC (opcode1), plus count faults by ExcCode. Photo reads of rows 5-9 are uncertain in the upper bits: show each of
   these 32-bit words twice (second copy inverted) or add a parity box so a mis-fit lattice is detectable.
3. Free: dual-DUT RTL simulation of cpu.vhd (reference vs `cpu_execute_share`) with the Tekken 1 snapshot RAM and a simple memory model (compare committed PCs). The shared ALU was hand-checked equivalent but never simulated.
4. A/B hardware build without `cpu_execute_share` (and, if needed, without `ps_patches`) - only if 1-3 point at the CPU.
5. Check isolate-cache / icache invalidate behaviour against what the boot code does (it writes kernel stubs to RAM then executes them; a stale icache line would return the wrong word at PC 0 exactly as T1 suggests).
State of the SD card: build probe4 installed (bitstream.rbf_r + interact.json), tekken1.json and tekken2ud.json in Assets/namco_system11/common/.


## 2026-10-22: local builds, probes 5-7, root cause (CPU reset PC) and the reset-only savestates fix
Builds now run locally (`tools/local_build.sh`, docs/LOCAL_BUILD.md; same image as Actions, ~16 min). Every diagnostic build: `S11_NO_MDEC=1`, `SEED 99`, `S11_POSEDGE_OUT=1`, `S11_FORCE_DIAG=1`
(without FORCE_DIAG the device shows the flat game-video screen with one white line). New build knobs: `S11_SKIP=variant,...` (A/B) and `S11_PROBES=s11_ramprobe` (probe applied after pocket_emu.apply).
- A/B without `cpu_execute_share` (Tekken 1): same failure class (straight-line run through a data table at 0x91CC8.., Reserved Instruction on 0x03E70001 at 0x91CD0). Patch cleared.
- probe5/6 (`s11_ramprobe.apply`, main-RAM readback through the ch3 sentinel slot): RAM[0x0] and RAM[0x10000] read 0 at 10, 30 and 60 s after load, no system resets, while in the simulator they hold the kernel stub
  (3C1AA000 275A0800 03400008) and the game entry word (27BDFFE0) from game entry onwards. So the boot never wrote them. (probe5's rows were shifted: a 320-bit concat into the 288-bit PK_DBG2.)
- probe7: SDRAM[0x400000] = 3C080013 and SDRAM[0x420400] = 0BF080BC, i.e. the boot program (rom_0.bin) is loaded intact; but the first CPU-side ch1 read after reset is address 0x10, data 0, not the reset vector.
- **Root cause**: `drop_scaffold.apply` replaced savestates.vhd with a stub that passed reset through but never pulsed `ss_reset`. cpu.vhd resets its PC from `ss_in(0)`, which only becomes 0xBFC00000 (and PRID 2) on
  `SS_reset`, so the MIPS started at PC 0 and swept zeroed RAM. Every earlier symptom fits (T1 RI at EPC 0 with ring {4,0,0}, varying fault EPCs, empty RAM, GPU untouched, MIPS mailbox writes 0).
  The PS Pocket core avoids this by keeping the sequencer in a reset-only form (references/openfpga-PlayStation/scripts/prepare_reset_only.py).
- **Fix**: `drop_scaffold.apply` no longer stubs savestates; new `savestates_reset_only.apply` (after drop_scaffold in tools/build_core_tree.py) pins resetMode=1/savemode=0/exeMode=0 as constants, collapses the
  12 unreachable SAVE states into one null arm, and ties `save_state`/`load_state` low in SYSTEM11.sv. `tests/savestates/run.sh` (nvc, idealized pause/ddr3/SDRAM/SPU handshakes with psx_top's clk2xIndex and
  aligned clocks) shows the sequence after reset_in falls: ss_reset at clk 2071 (system paused), scratchpad/SPU RAM/VRAM/2 MB main RAM cleared, final reset_out at clk 2,459,802 (~73 ms); cycle-identical to the
  unmodified upstream file. Device checks done by reading: every SS_idle source is driven (stubs report idle), the SPU stub acks SS_SPURAM at once, the PSRAM VRAM adapter aliases high address bits so the
  savestate-slot header reads still return data.
- Builds queued: `fix8` (fix + probe rows 1 = RAM[0x0], 6 = RAM[0x10000], 8/9 = data/address of the first ch1 read after reset; expect 3C1AA000, 27BDFFE0, 3C080013, 00400000) and `game8` (fix, no FORCE_DIAG).
- **Result (game8 = fix, no MDEC, seed 99)**: Tekken 1 boots on the Pocket: attract ranking screen and the 3D attract fight render; coin (Select) works, credits count to 9.
  Open: (1) Start is not seen by the game (mapping checked on paper: key[15] -> joy[10] -> c76_sound in_player1 bit 7, active low); probe `s11_inprobe.apply` (build `probe9`:
  rows 1 = {C76 P1-port reads, SWITCH reads}, 6 = {last P1 byte, last SW byte, live P1, live SW}, 8 = {P1 bits ever pressed, SW bits ever pressed, P2 reads}, 9 = joy[19:0]).
  (2) Polygons missing on character models; the A/B without `gpu_divider_pool` does not fit (seeds 99/22/44 short by 7-13 LABs). (3) No FMV (MDEC dropped). (4) Thin line at the top of the picture.
- Polygon A/B: without `gpu_divider_pool` the full build does not fit (seeds 99/22/44/7/3, 18,337-18,380 ALMs). The lean build `S11_SKIP=gpu_divider_pool,s11_bootbits S11_PROBES=s11_dbg2_zero`
  (new `s11_dbg2_zero.apply` ties PK_DBG2 to 0 when the bring-up probe export is left out) fits at seed 44: 18,208 ALMs (`leannopool44`), with timing misses video_pll setup -0.192 ns (85C) / -1.206 ns (0C)
  and core PLL general[0] hold -0.203 ns (85C). Not yet tested on the device.
- `tools/build_core_tree.py` used to rewrite `pocket/project/s11full.qsf` even for scratch trees; running it during a compile crashed quartus_fit (probe9, "Settings File changed outside of the
  Quartus Prime software"). It now writes the .qsf only for `pocket/build/core_tree`.
- `probe9` rerun built: 18,142 ALMs, seed 99, misses PLL general[2] setup -0.115 ns (85C) and video_pll setup -0.299 ns (0C); package `pocket/package-probe9`, not yet tested.
  probe9's 85C miss is savestates reset_out -> ram_refresh/refreshForce -> psx_sdram_ctrl a[10] (clk_3x): register refreshForce once in clk_3x in s11_sdram_shim.sv.

## 2026-10-23: Start, FMV and the first playable build (game14)
- **Result (game14): Tekken plays on the Pocket.** Intro FMV, credits, Start -> PLAYER SELECT -> fight. 18,029 ALMs, real MDEC, seed 44.
  Recipe: `S11_SKIP=s11_bootbits S11_PROBES=s11_dbg2_zero` with `SEED 44` and `S11_POSEDGE_OUT=1` (no `S11_NO_MDEC`).
- **Why Start was ignored.** Probes 9-13 followed the press end to end against MAME 0.289 (`brew install mame`, Lua scripts; see below):
  the C76 reads it (probe9), writes it to shared RAM BD02/BD03/BD83 (probe10/11, identical to MAME), the MIPS reads the edge (probe12),
  sets its Start flag 0x802648D0 bit 15, coins 2 and coins/credit 2 are right (probe13), but never plays the start sound 0x4113. The game
  state 0x80264880 was 00020001, a sub-step MAME never enters; mode 1 sub-step 1 is the intro movie, which the game feeds to the MDEC by DMA
  only (it never reads the MDEC registers). The no-MDEC stub never finished those DMAs. A stub that keeps both DMAs flowing (game12) was not
  enough; the real MDEC (game14) fixed it. "CREDIT 0/2" is normal: tekkenac ships at 2 coins per credit.
- **Area for MDEC came from following openfpga-PlayStation 0.5.6** (submodule moved from 4940d18):
  `ps_gpu_recip.apply` (gpu_timing_prune, gpu_dy_ram, gpu-recip for poly/line/gpu, poly stepadd, dma-share, dma-m10k) replaces
  `gpu_divider_pool` (the PS release GPU is the "nopool" base); `ps_gte.apply` adds the seven PS GTE patches to the Laxer GTE (control/data
  RAM, matrix RAM, add table, vector RAM, multicycle, M10K, shadow M10K), which S11 had none of. Synthesis estimate 18,143 -> 17,561.
  `tools/ps_patch_survey.py` now recopies `build/ps_root` when the submodule moves (it had kept using the old scripts). gpu_poly_diffmux
  does not apply to the S11 text after stepadd; bridge-cmd-lean (our core_bridge_cmd.v is byte-identical to MIRLO64) is not applied yet.
- `eeprom_blank.apply`: upstream's EEPROM BRAM init file `eeprom_ff.mif` is not shipped, so the BRAM came up zero; it now inits to all-FF.
- **Open:** polygons still hit and miss. game14's worst clk_2x setup is -0.495 ns (85C), all in gpu_pixelpipeline's texture-cache
  address (drawMode[7], stage0_u -> cache_address_a): first suspect. Seed sweep running; then a fix for that path, then A/B of the
  remaining GPU variants (gpu_area_reg, gpu_rect_timing, gpu_read_late, no_texfilter) against MAME frames.
- MAME reference tips: C76 device tag `:c76`; keep write/read tap objects referenced or they are collected; debugger works with
  `-debug -debugger none`, breakpoint actions log with `logerror` plus `-log`; `dasm file,addr,len` via `manager.machine.debugger:command`.

## 2026-10-24: full-rate VRAM fixes the polygon/HUD glitches; no in-core game switching
- **Polygons and HUD dropping out together** (game14-16) were GPU frame overruns, not logic: probe14 (`s11_frameprobe.apply`) counted
  1,575 of 15,380 vblanks (~10%) with the GPU still busy, worst 13 ms past vblank. MAME (`tools/mame/framesync.lua`) shows Tekken
  flips the display at vblank without waiting for the GPU (it only waits before sending the next DMA list), so an overrun shows a
  half-drawn frame: the near polygons and the HUD are drawn last.
- **Fix: PSRAM VRAM at full rate**, as the PlayStation core 0.5.6 release ships (checked in its release source tarball): chip clock
  67.7 MHz instead of 33.9 MHz, about twice the VRAM bandwidth. `pocket/core/memory/psx_vram_psram.sv` = PS v0.5.6, a fourth CPU PLL
  output (`vram_chip_clk`, clk2x 10047 ps late), `s11_vram` FULL_RATE (DDIO chip clock, latency 5), PS pin constraints in
  `core_constraints.sdc`. game17: Tekken 1 and 2 "working a lot better" on the device.
- Full rate adds a VRAM-busy -> GPU request path on clk2x; `gpu_read_late` (and `gpu_area_reg`, `gpu_rect_timing`) must stay in
  game builds (they had been skipped since the game16 A/B). Check clk2x setup in `s11full.sta.summary` before using a build.
- `c76_vblank_irq.apply`: the C76's IRQ0 now fires on the video vblank (IRQ2 2^17 clocks later) instead of a free-running 64.6 Hz
  counter, as on the hardware and in MAME. It did not change Tekken 2's combo timing by itself.
- **Game switching**: loading another game from the menu while the core runs does not work (the C76 restarts but the new game's files
  never reach SDRAM: Tekken 1's "good morning" plays whatever was picked). As the PlayStation core does for the same reason, the
  Game slot is not user-reloadable (`parameters 0x12`), so there is no "Load game" entry; quit the core to change games. A reload
  fix (`s11_reload`, games 18-21) was dropped; `s11_dlprobe.apply` (download counters, probe15) was written but not built.
- COH-100 (old GPU) handling checked against MAME: the core's gputype1 is on for every Tekken 1 set and the older Tekken 2 sets
  (platform byte bit 5), off for Tekken 2 VER.D and Soul Edge (COH-110), matching MAME.
