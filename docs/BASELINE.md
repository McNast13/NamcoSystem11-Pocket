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
