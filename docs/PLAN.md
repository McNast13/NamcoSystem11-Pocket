# Plan: Namco System 11 on Analogue Pocket

## References
| Repo | Role |
|---|---|
| XelaNotPu/SYSTEM11_MiSTer | Source core: PSX CPU/GPU/GTE/DMA + C76 (M37702) MCU, C352 audio, KEYCUS, MRAs |
| GuardianSoul/openfpga-PlayStation | Proof that a PSX core fits the Pocket. Reusable: `rtl/memory/*` (SDRAM/PSRAM controllers, arbiter, CDC), `rtl/pocket/*` (APF video/audio/input/data-slot glue), slim GPU divider pool, `memctrl_lean`, Quartus project generator scripts, test setup |
| MiSTer PSX_MiSTer | Upstream of both |

Observed: System 11 MiSTer targets Cyclone V 5CSEBA6 (~41k ALM, 5.5 Mb M10K, SDRAM + DDR). The Pocket's main FPGA is a
smaller Cyclone V (5CEBA4, ~18k ALM, ~3 Mb M10K; verify against Analogue dev docs) with SDRAM, 2x PSRAM, SRAM and no HPS/DDR.
The PlayStation Pocket port already solves the same shrink; System 11 should be easier since it has **no CD, SPU, MDEC or memory cards**
(the S11 repo already stubs `cd_top`, `spu`, `sio0`).

## Phase 0 - Setup (this week)
- [ ] Toolchain: Quartus Prime Lite 25.1 (Cyclone V), Icarus/GHDL/Verilator (reuse PS repo `scripts/setup_*`).
- [ ] Add upstreams as pinned submodules under `references/`.
- [ ] Get a Pocket dev loop: openFPGA dev SDK (`openfpga-template`/APF), SD card layout, JTAG-less loading via SD.
- [ ] Obtain legally dumped Tekken 2 ROM set; confirm the MiSTer core runs it (baseline).
- [ ] Measure: resource report of the MiSTer core (ALMs, M10K, DSP, regs); ROM sizes per region (program, banked data, C352 wave ROM).

## Phase 1 - Feasibility / budget (go/no-go)
- [ ] Synthesize S11 core for the Pocket device with no board glue; list overflow vs. budget (ALM, M10K, DSP, clocks).
- [ ] Memory map for Pocket: main RAM 2 MB, VRAM 2 MB, sound RAM, game ROM (banked, read-only, large), wave ROM.
      Candidate: ROM + wave ROM in SDRAM (streamed from data slots), VRAM/RAM in PSRAM/SDRAM per PS port design (`psx_vram_psram`, `psx_main_memory`).
- [ ] Decide what to cut/slim: GTE dividers (use PS `divider_pool`), caches, savestates, cheats, overlay/crosshair, HPS ext, light gun.
- [ ] Decision doc: expected fmax for CPU clock (~33.8 MHz PSX) on the Pocket's -C8 speed grade.

## Phase 2 - Pocket shell
- [ ] APF wrapper (`apf_top`), core.json (data slots, interact menu, video modes), PLLs.
- [ ] Video: GPU output -> APF scaler (240p/480i handling, 15 kHz timing as in PS port `psx_apf_video`).
- [ ] Audio: C352 -> I2S (48 kHz/ resample), C76 sound.
- [ ] Input: Pocket pad -> S11 button registers; coin/start/service/test DIP mapping (menu items).
- [ ] ROM loading: replace MRA with a **ROM packer** (Python script producing one or a few `.bin` data slots + `.json` instance per game; interleave/byte-swap per MRA rules; parse MRA directly to avoid hand-translation).

## Phase 3 - Memory + CDC bring-up
- [ ] Port PS `rtl/memory` controllers; write arbiter for S11 clients (CPU/cache, GPU VRAM r/w, DMA, ROM bank, C352 wave ROM, C76 program).
- [ ] Sim testbenches with ROM stubs (CPU boot to KEYCUS/ROM reads).
- [ ] Bring-up on hardware with test patterns -> BIOS-less boot (System 11 has no BIOS: boots from game ROM).

## Phase 4 - Tekken 2 playable
- [ ] Boot -> attract mode -> in-game; C76 handshake, KEYCUS (TES2 key), inputs.
- [ ] Fix timing closure, GPU correctness (note: older TES2 revs need earlier CXD8538Q GPU variant; target TES2-VER.D first).
- [ ] Audio sync, performance (full speed) checks; save DIP/service settings.
- **Done when:** TES2-VER.D plays a full match at full speed with sound on a real Pocket.

## Phase 5 - Later
Other 11 titles, alternate revs, polish, release packaging (pupdate/Pocket Sync), docs.

## Risks
1. **Logic/M10K overflow** - main risk; mitigate via PS port techniques and feature cuts.
2. **Timing closure** at -C8 grade with the PSX CPU/GTE/GPU.
3. **ROM size/bandwidth** - banked ROM random access latency from SDRAM, wave ROM streaming; may need prefetch cache.
4. **Pocket has no debug/JTAG convenience** - invest in simulation and on-screen diagnostics early.
5. **Licensing** - GPL; keep upstream notices and credit (Robert Peip/FPGAzumSpass, XelaNotPu, GuardianSoul). Confirm with authors before releasing binaries.
6. **ROMs** - never committed; user supplies.

## Open questions
- Exact Pocket FPGA part/resources and memory sizes (confirm in Analogue docs).
- Tekken 2 ROM footprint (measure in Phase 0).
