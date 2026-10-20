# System 11 boot simulator and diagnostic-photo decoder (bring-up tools)

Pure-Python R3000 interpreter (`r3k.py`) that runs the Tekken 2 BIOS/boot ROM (`rom_0.bin`, `rom_3.bin` from `tools/rom_packer.py`), with just enough hardware stubbed
(GPUSTAT ready, expansion-2 UART ready, 4 MB RAM mirrored through 8 MB, cache-control writes ignored). About 1.3 M instructions/s.

- `snap.py DIR`  : run from reset to the first game-code fetch (physical 0x10000..0x40000, ~113 M instructions, ~90 s) and pickle the CPU/RAM state to `DIR/snap_entry.pkl`.
- `trace.py DIR N`: restart from that snapshot and print the first hardware accesses in order (IO reads/writes with PCs).
- `disrom.py ROM OFFSET COUNT [BASE]`: capstone MIPS disassembly of a ROM window (needs `pip install capstone` in a venv).
Expected `DIR` layout: `DIR/t2/rom_0.bin`, `DIR/t2/rom_3.bin` (output of `rom_packer.py ... --out DIR/t2`).
Findings: decompression is ~106 M instructions at BFC20220..BFC20400; game entry 0x80010000 is `j 0x80196D8C` (crt0, clears 0x801C89D8..0x80354D10); the game then sets the memory
controller, writes the 0x1FA0xxxx I/O block, kicks a watchdog (0x1FA0BE88) ~790k times and reads EEPROM at 0x1FA30000.

`../diag_decode.py [--rot DEG] photo.jpg ...` decodes the on-screen diagnostic grid (32 boxes per row, MSB left) from a photo of the Pocket (needs pillow, numpy; rotate with --rot if the Pocket was held sideways).
