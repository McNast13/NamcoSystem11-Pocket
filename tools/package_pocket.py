#!/usr/bin/env python3
"""Assemble an Analogue Pocket SD-card tree for the System 11 core.

  package_pocket.py --rbf output_files/s11full.rbf --out OUTDIR [--packed DIR --instance NAME]

Writes OUTDIR/Cores/McNast13.NamcoSystem11/{core.json,data.json,video.json,audio.json,input.json,interact.json,bitstream.rbf_r},
OUTDIR/Platforms/namco_system11.json and, with --packed (rom_packer.py output made with --instance NAME), the game into
OUTDIR/Assets/namco_system11/common/NAME.json plus NAME/rom_*.bin. bitstream.rbf_r is the .rbf with the bits of every byte reversed (APF requirement, same naming as the Dragon 32 core).
Copy OUTDIR onto the Pocket's SD card. ROM images are the user's own; nothing here ships them.
"""
import argparse, json, shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CORE_DIR = ROOT / "pocket/dist/Cores/McNast13.NamcoSystem11"
REV = bytes(int(f"{i:08b}"[::-1], 2) for i in range(256))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--rbf", required=True, type=Path)
    ap.add_argument("--out", required=True, type=Path)
    ap.add_argument("--packed", type=Path, help="rom_packer.py output directory")
    ap.add_argument("--instance", help="instance name used with rom_packer.py --instance")
    a = ap.parse_args()

    core = a.out / "Cores/McNast13.NamcoSystem11"
    core.mkdir(parents=True, exist_ok=True)
    plat = a.out / "Platforms"
    plat.mkdir(parents=True, exist_ok=True)
    for f in CORE_DIR.glob("*.json"):
        shutil.copy(f, core / f.name)
    (core / "bitstream.rbf_r").write_bytes(a.rbf.read_bytes().translate(REV))
    # placeholder artwork: icon 36x36 and platform picture 521x165, RGB565 little-endian, solid colour
    def solid(w, h, rgb565):
        return rgb565.to_bytes(2, "little") * (w * h)
    (core / "icon.bin").write_bytes(solid(36, 36, 0xC0A0))
    (a.out / "Platforms/_images").mkdir(parents=True, exist_ok=True)
    (a.out / "Platforms/_images/namco_system11.bin").write_bytes(solid(521, 165, 0x2104))

    (plat / "namco_system11.json").write_text(json.dumps(
        {"platform": {"category": "Arcade Multi", "name": "Namco System 11", "manufacturer": "Namco", "year": 1994}}, indent=2) + "\n")

    if a.packed:
        if not a.instance:
            ap.error("--packed needs --instance")
        common = a.out / "Assets/namco_system11/common"
        (common / a.instance).mkdir(parents=True, exist_ok=True)
        shutil.copy(a.packed / f"{a.instance}.json", common / f"{a.instance}.json")
        for f in a.packed.glob("rom_*.bin"):
            shutil.copy(f, common / a.instance / f.name)
    print(f"wrote {a.out}")


if __name__ == "__main__":
    main()
