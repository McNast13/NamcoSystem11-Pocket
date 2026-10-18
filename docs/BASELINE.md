# Baseline: unmodified SYSTEM11_MiSTer compile

Run: Actions #39130913018, Quartus 17.0.2 Lite (`raetro/quartus:mister`), device 5CSEBA6U23I7, fit succeeded (~45 min).
Reports are in the run's `mister-baseline-reports` artifact.

| Resource | Used | Device (MiSTer) |
|---|---|---|
| ALMs (needed) | 37,029 | 41,910 (88%) |
| Registers | 42,842 | |
| M10K blocks / bits | 287 / 1.70 Mb | 553 / 5.66 Mb |
| DSP blocks | 109 | 112 (97%) |
| PLLs | 4 | 6 |

## By module (ALMs / M10K / DSP)
| Module | ALM | M10K | DSP | Notes |
|---|---|---|---|---|
| `sys_top` framework (ascal, audio_out, hps_io, ...) | ~6,200 | 60 | 23 | MiSTer-only; replaced by Pocket APF (scaler is outside this FPGA) |
| `emu` total | 30,800 | 227 | 86 | the core proper |
| - `psx_top` | 21,178 | 171 | 74 | |
| &nbsp;&nbsp;- gpu | 7,820 | 67 | 44 | |
| &nbsp;&nbsp;- gte | 4,686 | 1 | 15 | |
| &nbsp;&nbsp;- cpu (incl. caches) | 3,499 | 78 | 6 | |
| &nbsp;&nbsp;- dma | 1,703 | 2 | 0 | |
| &nbsp;&nbsp;- memorymux | 897 | 0 | 0 | |
| &nbsp;&nbsp;- mdec | 680 | 19 | 9 | **needed for Tekken/S11 intro FMVs** (author restored it; stubbing = black/no movies) |
| &nbsp;&nbsp;- savestates | 566 | 0 | 0 | cut |
| &nbsp;&nbsp;- zn1_io | 573 | 4 | 0 | |
| - `c76_sound` | 7,121 | 55 | 4 | C76 MCU 4,285 ALM / 16 M10K; C352 2,778 ALM / 7 M10K |
| - `hps_io` | 600 | 0 | 0 | MiSTer-only |

## Timing
All `emu` clock domains meet setup/hold. The only negative slack (-1.8 ns) is the HDMI PLL domain in `sys_top`, which does not exist on the Pocket.

## Reading this against the Pocket (verify device numbers against Analogue docs)
Assumed Pocket FPGA (Cyclone V 5CEBA4): ~18.5k ALMs, ~308 M10K (3.1 Mb), ~66 DSP blocks.
- Essential logic today: cpu 3.5k + gpu 7.8k + gte 4.7k + dma 1.7k + C76/C352 7.1k = **~24.8k ALMs** before memory glue; the budget is ~18.5k with headroom needed for timing closure, so **we must cut roughly 30-40%**.
- DSP: 86 in `emu` vs ~66 available - GPU (44) and GTE (15) multipliers must be shared/serialized (the PlayStation Pocket port's divider pool and lean memctrl show how).
- M10K fits (227 vs ~308) but caches (cpu 78) and C76 (55) are big targets; VRAM/RAM must stay off-chip.
- Free wins: savestates, hps_io, light-gun, cheats, overlay.
- Biggest unknowns: whether C76 (M37702 soft CPU, 4.3k ALM) can be slimmed, and whether the GPU can be time-multiplexed at an acceptable rate.

Next: re-synthesize `emu` for the Pocket device (raetro/quartus:pocket) with the framework stripped, MDEC/savestates removed, to get a true Pocket-device number.

## Pocket-device synthesis probe (run #39137853331)
`emu` alone, unmodified, synthesized for 5CEBA4F23C8 with Quartus 18.1.1 (`raetro/quartus:pocket`); synthesis only, no fit
(ALM count is not reported at this stage; compare in combinational ALUTs). Workflow: `.github/workflows/pocket-probe.yml`.

| | emu (unmodified) | Pocket FPGA (approx.) |
|---|---|---|
| Combinational ALUTs | 43,352 | ~25.9k (18.5k ALMs x ~1.4; the MiSTer fit packed 30.8k ALMs for emu, ratio ~0.71 ALM/ALUT) |
| Registers | 31,385 | ~74k |
| Block memory bits | 1.32 Mb | 3.08 Mb |
| DSP blocks | 86 | ~66 |

| Module | ALUTs | Regs | Mem bits | DSP |
|---|---|---|---|---|
| psx_top | 29,938 | 19,224 | 919k | 74 |
| c76_sound (C76 CPU 5.8k, C352 3.7k) | 9,676 | 8,503 | 399k | 4 |
| hps_io | 921 | 1,155 | 0 | 0 |
| pll_cfg | 788 | 204 | 0 | 0 |
| sdram | 411 | 893 | 0 | 0 |

**Conclusion:** unmodified, `emu` is ~65-70% over the Pocket's logic and ~30% over its DSP budget. Reaching playable Tekken 2 means removing
roughly 17k ALUTs (~40%): savestates/hps_io/pll_cfg (~2k) and, optionally, MDEC, then slimming GPU (multiplier sharing), GTE, CPU caches and the C76 core.
Next probe variants (`synth/pocket_probe/variants/<name>.sh`, applied before synthesis): no-MDEC, no-savestates, GPU with shared multipliers.

## Variant results
| Variant | ALUTs | Regs | Mem bits | DSP | Run |
|---|---|---|---|---|---|
| baseline | 43,352 | 31,385 | 1,324,039 | 86 | 39137853331 |
| no_mdec (stub, FMV dead) | 42,179 (-1,173, -2.7%) | 30,482 | 1,264,711 | 77 (-9) | 39138672589 |

**MDEC correction:** the author's comments in `psx_top.vhd` say MDEC was deliberately restored because Tekken/System 11 intro FMVs are
MDEC streams, and that SPU and cheats were already stubbed to pay for it. Removing it saves only ~1.2k ALUTs and 9 DSP, and kills
the intro movies (risk: boot code that waits on MDEC DMA could hang - untested). Treat as an optional late cut, not a first one.

### GPU divider pool (variant `gpu_divider_pool`, run 39139784990)
Port of openfpga-PlayStation `prepare_gpu_divider_pool.py` onto S11 `rtl/gpu.vhd` (six dividers -> one shared, serial). Upstream flags it experimental
(adds setup latency; its own metadata says pixel equivalence/fit/game/hardware unverified).

| Variant | ALUTs | Regs | DSP |
|---|---|---|---|
| baseline | 43,352 | 31,385 | 86 |
| gpu_divider_pool | 42,627 (-725, -1.7%) | 31,180 | 86 (no change) |

Findings: divider pool saves little (~1.1k ALUTs of dividers -> 386 pool). The GPU is still 10.9k ALUTs; its 44 DSPs are in `gpu_poly` (29) and
`gpu_pixelpipeline` (15), not the dividers. GTE 6.3k ALUTs / 15 DSP, CPU 4.1k ALUTs / 6 DSP, DMA 2.5k.

### What the PlayStation Pocket port actually does (from source, not yet measured here)
- CPU: replaced with `psx_cpu.sv`, a **sequential, non-cycle-accurate R3000** with no caches (vs ~4.1k ALUT + 78 M10K cached CPU here).
- GTE: `rtl/gte/laxer_mister_adapter.sv` wraps Laxer3a's GTE (`references/Laxer3a_PSX`) rather than the MiSTer pipelined GTE.
- GPU: divider pool (above), `psx_gpu_read_math`; VRAM in PSRAM (`psx_vram_psram`).
These are the real levers. Cycle accuracy matters less for System 11 only if Tekken 2's timing tolerates it - needs testing.

### Correction + GTE swap (variant `gte_laxer`, run 39141582148)
**Correction:** earlier I wrote that the PS Pocket port uses a sequential CPU (`psx_cpu.sv`). That is an experimental component, not the shipped core.
The shipped core is upstream PSX_MiSTer plus ~30 area patches (`scripts/prepare_full_pocket.py` lists them: gpu-line-share, gpu-poly-share, gpu-mul-narrow,
gpu-half-pipe, gte-*-ram, gte-adapter (Laxer), dma-*-ram, mdec-*, ...). S11's gte/mdec/dma/gpu_poly/gpu_line are ~identical to upstream; gpu.vhd and cpu.vhd have diverged.

| Variant | ALUTs | Regs | Mem bits | DSP |
|---|---|---|---|---|
| baseline | 43,352 | 31,385 | 1,324,039 | 86 |
| gpu_divider_pool | 42,627 (-725) | 31,180 | 1,324,039 | 86 |
| **gte_laxer** (Laxer3a GTE) | **39,697 (-3,655, -8.4%)** | 30,144 | 1,351,175 | 83 |

GTE swap is the best single cut so far. Not functionally verified (S11 savestates, widescreen and turbo are unsupported by this GTE).

### Patch-stack results (synthesis only; none functionally verified)
`ps_patches` = the 8 openfpga-PlayStation patches that apply to S11 RTL unchanged (dma_channel_ram, dma_chcr_ram, gpu_area_reg, gpu_mul_narrow,
gpu_poly_onehot, gpu_no_watchdog, mdec_mednafen, mdec_idct_pipe); `area_profile` = Quartus area settings (no RTL change). Tools: `tools/ps_patch_survey.py`, `tools/ps_patch_chain.py`.

| Variant | ALUTs | Regs | DSP | vs baseline |
|---|---|---|---|---|
| baseline | 43,352 | 31,385 | 86 | |
| area_profile | 43,180 | 31,110 | 88 | -172 |
| ps_patches | 42,415 | 30,779 | 85 | -937 |
| gte_laxer | 39,697 | 30,144 | 83 | -3,655 |
| gte_laxer + area_profile | 39,626 | 29,948 | 85 | -3,726 |
| **gte_laxer + ps_patches** | **38,850** | 29,536 | 82 | **-4,502 (-10.4%)** |
| **gte_laxer + ps_patches + area_profile** | **38,183** | 29,316 | 83 | **-5,169 (-11.9%)** |

(An earlier combined run showed a worse number due to a tooling bug that reverted the Laxer GTE; fixed in `ps_patches.apply`.)
Remaining gap to the ~26k ALUT estimate: ~12k. Patches that did not apply (need manual port to S11's diverged gpu_poly/gpu/cpu):
gpu_poly_share, gpu_vertex_ram, gpu_half_pipe, gpu_dy_ram, gpu_sort_reread, gpu_tag_generation, gpu_read_late, gpu_cache_controls, cpu_execute_share, cpu_regfile_ram, gte RAM conversions (target MiSTer GTE).

## Sound blocks and CPU patches (synthesis only, ALUTs = "logic" figure; add 875 memory ALUTs)

| Variant | ALUTs | Regs | DSP | Notes |
|---|---|---|---|---|
| gte_laxer + ps_patches (11) | 37,948 | 29,358 | 60 | DSP now under the ~66 budget |
| + c76_ram_bram | 35,762 | 25,254 | 60 | c76's 512 B internal RAM was flip-flops: two combinational dbg taps (`dbg_ram80/83`) blocked M10K inference. Tied off. |
| + sound_no_debug | 35,762 | 25,254 | 60 | no change: Quartus already pruned the c76_sound diagnostics |
| + cpu_execute_share | 35,639 | 25,254 | 60 | only -123 ALUTs; patch applies to S11 cpu.vhd with its SHA pin rebound |

Where the area is now (hierarchy, ALUTs): gpu 10.5k, c76_sound 7.7k (m37702 2.8k, c352 3.8k, c76 wrapper ~1k incl. 128 B SFR file), cpu 4.0k,
gte 2.5k, dma 1.6k, memorymux 1.3k, mdec 1.2k; non-core (SYSTEM11 top, sys/, glue) the remainder.
`cpu_regfile_ram` was not tried: S11's cpu.vhd uses a hand-added flip-flop shadow register file (`regsFF`, HW workaround for an MLAB
read-back bug) that the patch does not model. Remaining gap to ~26k ALUTs: ~10k. The GPU is the largest remaining block.

## Pocket device resources (verified, replaces the earlier estimates)

Source: a real Quartus 18.1.1 fitter report for the Pocket's device `5CEBA4F23C8`
(pgate1/PlayStation_on_FPGA `Pocket/ap_core.fit.summary`; also the device used by openfpga-PlayStation), plus Analogue's
[developer overview](https://analogue.co/developer/docs) for the board (two FPGAs; the core FPGA is fully available).

| Resource | Capacity | Notes |
|---|---|---|
| ALMs | **18,480** | pgate1's reduced PSX (no sound, no FMV) fits at 17,060 (92%) |
| Block RAM | **308 M10K / 3,153,920 bits** | that core uses 307/308 |
| DSP blocks | **66** | that core uses 58 |
| PLLs | 4 | |
| I/O pins | 224 (all used by Analogue's wrapper in that fit) | |
| External RAM | 2x16 MB cellular RAM (PSRAM), 64 MB SDRAM, 256 KB async SRAM | per Analogue's published board spec (secondary sources); not in the dev docs overview |

Our current best probe (gte_laxer + ps_patches + c76_ram_bram + cpu_execute_share): 35,639 logic ALUTs (+875 memory ALUTs),
25,254 registers, 60 DSP, **1,356,039 block-memory bits (43% of capacity)**. Synthesis reports ALUTs, not ALMs; at the
MiSTer fit ratio (~0.71 ALM/ALUT) that is ~26k ALMs vs 18,480 available, i.e. **~7.5k ALMs (~29%) over**, unverified until a fit.

What can be leveraged: ~1.8 Mbit of M10K is unused and 6 DSPs are free. Logic that can be re-expressed as RAM/ROM
(register arrays, lookup tables, MLAB-based RAM which burns ALMs) should move to M10K; multipliers can use the spare DSPs.

## Real fit on the Pocket device (run 39153536343, Quartus 18.1.1, 5CEBA4F23C8, all `emu` ports virtual except the SDRAM clocks)

Variant: gte_laxer + ps_patches + c76_ram_bram + cpu_execute_share. The fitter fails at packing, but reports the demand:

| Resource | Needed | Device | |
|---|---|---|---|
| ALMs | **25,557** | 18,480 | 138% (**7,077 over; -27.7% required**) |
| LABs | 2,567 | 1,848 | |
| Registers | 24,446 | | |
| Block memory bits | 1,356,039 | 3,153,920 | 43% |
| DSP blocks | 60 | 66 | 91% |
| PLLs | 2 | 4 | |

ALM breakdown: 8,507 LUT+register, 12,364 LUT-only, 3,365 register-only, 700 memory; dense packing recovers ~0.
The ALUT-to-ALM estimate (0.71) was right: 25,557 / 36,637 = 0.70. Real figure for planning: **~7.1k ALMs to remove**
(plus headroom for timing closure and the Pocket shell/memory controller, which are not in this number).

## Placed breakdown (fit on 5CEBA9F23C8, run 39153542286 - same design, bigger part so it completes)

Total 25,282 ALMs, 26,400 regs, 232 M10K blocks (of 308), 60 DSP. ALMs by block (hierarchy totals):

| Block | ALMs | Notes |
|---|---|---|
| psx_top (all PS1 core) | 16,973 | |
| - gpu | 6,991 | poly 1,759, pixelpipeline 1,754, videoout ~1,230, line 445, rect 258 |
| - cpu | 3,378 | 2,942 local (includes the 32x32 flip-flop `regsFF`) |
| - gte (Laxer) | 2,108 | |
| - dma 1,098; memorymux 882; mdec 672; timer 271; memctrl 244 | | |
| c76_sound | 5,360 | m37702 1,751; c76 wrapper 751; c352 2,789 |
| zn1_io | 574 | System 11 I/O |
| **MiSTer scaffolding the Pocket shell replaces** | **~3,500** | emu glue 960, pll_cfg 698, hps_io 640, savestates 543, sdram 372, video_calc/freak/scale ~650 |

Excluding the scaffolding, the core is ~21.8k ALMs; the Pocket wrapper (APF bridge, data-slot loader, memory controller,
video/audio out) must then be added, so the realistic cut from the *core* is still ~5-6k ALMs.

### Sequential PS CPU is NOT a saving
`psx_cpu.sv` (openfpga-PlayStation, "sequential R3000 baseline", not shipped in its core) synthesized alone for the Pocket part:
**6,601 ALUTs, 2,325 regs, 0 DSP** vs the cached S11 `cpu.vhd` at ~4.0k ALUTs. It is larger (multiply/divide in LUTs) and slower, and needs an adapter
to the cached memory protocol. Dropped as an option.

## Scaffolding drop measured (variant drop_scaffold: stub savestates + pll_cfg; fit on 5CEBA9F23C8, run 39157057553)

| | ALMs | Regs | M10K |
|---|---|---|---|
| before (same stack) | 25,282 | 26,400 | 232 |
| after | **22,553** | 22,816 | 230 |
| change | **-2,729** | -3,584 | -2 |

More than the ~1.2k the two modules' own sizes suggest: with the savestate engine gone, the per-module save/load read paths
(SS_DataRead_*, statemanager) are pruned too. Remaining gap to the Pocket's 18,480 ALMs: **~4,070 plus the Pocket shell**
(APF bridge, data-slot loader, memory controller, video/audio out), which are not yet counted.
Not yet dropped: hps_io/hps_ext, video_freak/scale/gamma, sdram2, debug glue in SYSTEM11.sv (likely another ~1-1.5k, but partly replaced by shell logic).
