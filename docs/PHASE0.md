# Phase 0 notes

## Files you must supply (never committed)
System 11 has **no BIOS**: it boots from the game's own program ROM. Needed (MAME set `tekken2` plus the C76 BIOS):

| File | CRC32 | Role |
|---|---|---|
| tes2verd.2l / tes2verd.2j | 1aef3da8 / 03787fd0 | Program (interleaved) |
| tes1verd.2k / tes1verd.2f | 846ace0a / 7a0663b4 | Program (interleaved) |
| tes1rom0l.ic6 / rom0u.ic5 | fc904ede / 57b38f5d | Banked data |
| tes1rom1l.ic8 / rom1u.ic3 | aa48f04b / b147c543 | Banked data |
| tes1rom2l.ic7 / rom2u.ic4 | b08da52c / 8a1561b8 | Banked data |
| tes1rom3l.ic9 / rom3u.ic1 | d5ac0f18 / 44ed509d | Banked data |
| tes1sprog.6d | af18759f | C76 sound program |
| tes1wave.8k | 34a34eab | C352 wave ROM (4 MB) |
| c76.bin (in namcoc76.zip) | - | Namco C76 internal BIOS (16 KB) |

Put `tekken2.zip` and `namcoc76.zip` (MAME names; match your MAME version, tekken2 = "Tekken 2 (TES2/VER.D)") under `roms/` (gitignored).
Tekken 2's KEYCUS is C406 (platform byte 0x14, type 0x01).

## Memory layout in the MiSTer core (from the MRA)
SDRAM: program @0x400000, banked data (16 MB window) @0x800000, C76 prog @0x1800000, wave @0x1840000 (+4 MB) => ~28 MB of ROM.
The Pocket has a 64 MiB SDRAM and two PSRAMs (32 MiB total) per MIRLO64's documentation (corrected 2026-10-19; this note originally said ~32 MB), so the MiSTer layout (top at 0x2C40000) fits.

## Toolchain finding
Quartus Prime Lite has **no macOS build**. This machine (Apple Silicon) has iverilog and verilator but not ghdl or Quartus.
Options: x86 Linux VM/cloud box or GitHub Actions runner with Quartus Lite 25.1 for synthesis; simulate locally (verilator/ghdl via brew).

## ROM status (2026-10-18)
`roms/tekken2.zip` (supplied by the owner, not committed) is the **US set, TES3/VER.D** (MRA `_alternatives/_Tekken 2/Tekken 2 Ver.B (US TES3-VER.D).mra`, setname `tekken2ud`).
Verified by CRC: all banked data ROMs, sprog and wave match; program ROMs are `tes3verd.2l` (0768f36c) / `.2j` (d29a0545) / `.2k` (846ace0a) / `.2f` (7a0663b4),
not the `tes2verd.*` names listed above. **Use the TES3/VER.D MRA as the first target** (same hardware, KEYCUS C406).
Total ROM payload 25.4 MB. `roms/namcoc76.zip` supplied: c76.bin, 16384 bytes, CRC 399faac7. **All ROMs for Tekken 2 are now in hand.**
