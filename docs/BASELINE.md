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
| &nbsp;&nbsp;- mdec | 680 | 19 | 9 | **unused by System 11 - remove** |
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
- Free wins: MDEC (0.7k ALM, 9 DSP, 19 M10K), savestates, hps_io, light-gun, cheats, overlay.
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
roughly 17k ALUTs (~40%): MDEC/savestates/hps_io/pll_cfg (~3k), then slimming GPU (multiplier sharing), GTE, CPU caches and the C76 core.
Next probe variants (`synth/pocket_probe/variants/<name>.sh`, applied before synthesis): no-MDEC, no-savestates, GPU with shared multipliers.
