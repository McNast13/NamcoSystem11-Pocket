#!/usr/bin/env python3
"""Assemble an Analogue Pocket SD-card tree for the System 11 core.

  package_pocket.py --rbf output_files/s11full.rbf --out OUTDIR [--packed DIR --instance NAME]

Writes OUTDIR/Cores/McNast13.NamcoSystem11/{core.json,data.json,video.json,audio.json,input.json,interact.json,bitstream.rbf_r},
OUTDIR/Platforms/namco_system11.json and, with --packed (rom_packer.py output made with --instance NAME), the game into
OUTDIR/Assets/namco_system11/common/NAME.json plus NAME/rom_*.bin. bitstream.rbf_r is the .rbf with the bits of every byte reversed (APF requirement, same naming as the Dragon 32 core).
Copy OUTDIR onto the Pocket's SD card. ROM images are the user's own; nothing here ships them.
"""
import argparse, json, shutil, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(Path(__file__).resolve().parent))
CORE_DIR = ROOT / "pocket/dist/Cores/McNast13.NamcoSystem11"
REV = bytes(int(f"{i:08b}"[::-1], 2) for i in range(256))


ASSETS_README = """Namco System 11 game files go in this folder. None are included: they are built from your own current-MAME romsets.

- c76.bin: the C76 sound CPU BIOS, shared by every game. Copy it out of namcoc76.zip into this folder
  (CRC 399faac7, md5 8ca155e5ad03571e0930d8d361749b03).
- One folder per game, named after its MAME set (tekken2/, souledge/, xevi3dg/, ...), holding rom_0.bin ... rom_7.bin.
  Build them with tools/make_games.py from https://github.com/McNast13/NamcoSystem11-Pocket:

      python3 tools/make_games.py --roms <folder with your zips and namcoc76.zip> --sd <SD card root>

The game list is in ../McNast13.NamcoSystem11/ (main versions; other versions in _alternatives/). pupdate and Pocket Sync
show which files each game still needs. To change game, quit the core and open it again.
"""


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
    icon = CORE_DIR / "icon.bin"   # author icon on the core's About screen: pocket/dist/art/author_icon.png, encoded with pocket_image.py
    (core / "icon.bin").write_bytes(icon.read_bytes() if icon.exists() else solid(36, 36, 0xC0A0))
    (a.out / "Platforms/_images").mkdir(parents=True, exist_ok=True)
    banner = ROOT / "pocket/dist/Platforms/_images/namco_system11.bin"   # pocket/dist/art/namco_system11_banner.png, encoded with
    (a.out / "Platforms/_images/namco_system11.bin").write_bytes(           # references/openfpga-PlayStation/scripts/pocket_image.py
        banner.read_bytes() if banner.exists() else solid(521, 165, 0x2104))

    (plat / "namco_system11.json").write_text(json.dumps(
        {"platform": {"category": "Arcade Multi", "name": "Namco System 11", "manufacturer": "Namco", "year": 1994}}, indent=2) + "\n")

    # the game list: one instance JSON per System 11 set with an MRA (tools/make_games.py); pupdate / Pocket Sync read the files each
    # names as the game's required files. The ROM images themselves are the user's own (make_games.py --roms ... --sd ...).
    import make_games
    if make_games.ARCADE.is_dir():
        games = make_games.sets()
        for s in games:
            make_games.write_instance(a.out / "Assets" / make_games.PLATFORM / make_games.CORE / make_games.instance_name(s), s)
        print(f"{len(games)} game instances")
    else:
        print("warning: references/SYSTEM11_MiSTer not checked out: no game instances in the package")

    # where the user's files go, as in the Dragon 32 core's release (a README beside the files it asks for), and the licence
    common = a.out / "Assets" / "namco_system11" / "common"
    common.mkdir(parents=True, exist_ok=True)
    (common / "README.md").write_text(ASSETS_README)
    shutil.copy(ROOT / "LICENSE", a.out / "LICENSE.txt")

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
