#!/usr/bin/env python3
"""Make the Pocket game list (instance JSONs) and, from your own current-MAME romsets, the game files, for every System 11 set the
SYSTEM11_MiSTer core has an MRA for (references/SYSTEM11_MiSTer/releases/_Arcade, main and _alternatives; set names are current MAME's).

SD-card layout (APF; the same convention the PlayStation core's instances use on hardware):
  Assets/namco_system11/McNast13.NamcoSystem11/<Title>.json   one instance per set: the game list, shipped with the core. pupdate and
                                                                Pocket Sync read the files each one names as the game's required files.
  Assets/namco_system11/common/<set>/rom_<index>.bin           that set's images, built from its MRA (rom_packer.py; every CRC checked)
  Assets/namco_system11/common/c76.bin                         the C76 sound CPU BIOS (namcoc76.zip), shared by every game: data slot 8
                                                                names it in data.json, so the tools list it as the core's BIOS
Instances use an empty data_path and give each file with its set folder (pupdate resolves files from the filename alone).

  make_games.py --instances OUT              write the instance JSONs for every set (no ROMs needed; what the release ships)
  make_games.py --roms DIR --sd OUT [--set S ...]
                                             also pack every set whose zips are in DIR (current MAME names, plus namcoc76.zip) into
                                             OUT/Assets/namco_system11/common, and c76.bin; OUT can be the SD card's root
"""
import argparse, glob, hashlib, json, os, sys, xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ARCADE = ROOT / "references/SYSTEM11_MiSTer/releases/_Arcade"
PLATFORM, CORE = "namco_system11", "McNast13.NamcoSystem11"
SLOT_OF = {0: 1, 1: 2, 2: 3, 3: 4, 6: 6, 7: 7}   # MRA index -> data slot (pocket/dist/.../data.json); index 8 is the shared c76.bin
BANK = 0x1000000                                 # data slot 4 holds 16 MB; a larger banked ROM continues in slot 5

sys.path.insert(0, str(Path(__file__).resolve().parent))
import rom_packer  # noqa: E402


def sets():
    out = []
    for f in sorted(glob.glob(str(ARCADE / "*.mra")) + glob.glob(str(ARCADE / "_alternatives/*/*.mra"))):
        r = ET.parse(f).getroot()
        out.append({"set": r.findtext("setname"), "title": r.findtext("name"), "mra": f,
                    "indices": sorted({int(x.get("index")) for x in r.iter("rom")})})
    return out


def files_of(s, sizes=None):
    """[(slot id, file name)] for a set; sizes (index -> bytes) decides whether the banked ROM needs slot 5."""
    fl = []
    for i in s["indices"]:
        if i == 8:
            continue
        fl.append((SLOT_OF[i], f"{s['set']}/rom_{i}.bin"))
        if i == 3 and sizes and sizes.get(3, 0) > BANK:
            fl.append((5, f"{s['set']}/rom_3b.bin"))
    return fl


def instance_name(s):
    return s["title"].replace("/", "-").replace(":", " -") + ".json"


def write_instance(path, s, sizes=None, md5s=None):
    slots = []
    for sid, fn in files_of(s, sizes):
        e = {"id": sid, "filename": fn}
        if md5s and fn in md5s:
            e["md5"] = md5s[fn]
        slots.append(e)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps({"instance": {"magic": "APF_VER_1", "data_path": "", "data_slots": slots}}, indent=2) + "\n")


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--instances", type=Path, help="write the instance JSONs for every set into this directory")
    ap.add_argument("--roms", type=Path, help="directory with current-MAME zips and namcoc76.zip")
    ap.add_argument("--sd", type=Path, help="SD-card root (or staging folder) to write Assets/ into")
    ap.add_argument("--set", action="append", help="only these sets")
    a = ap.parse_args()
    if not a.instances and not (a.roms and a.sd):
        ap.error("give --instances DIR, or --roms DIR --sd OUT")
    allsets = [s for s in sets() if not a.set or s["set"] in a.set]

    if a.instances:
        for s in allsets:
            write_instance(a.instances / instance_name(s), s)
        print(f"{len(allsets)} instance JSONs in {a.instances}")

    if a.roms and a.sd:
        common = a.sd / "Assets" / PLATFORM / "common"
        inst_dir = a.sd / "Assets" / PLATFORM / CORE
        c76 = None
        packed, skipped = [], []
        for s in allsets:
            try:
                images = rom_packer.pack(s["mra"], str(a.roms))
            except rom_packer.PackError as e:
                skipped.append(f"{s['set']}: {e}")
                continue
            if c76 is None:
                c76 = images[8]
            elif images[8] != c76:
                sys.exit(f"{s['set']}: C76 BIOS differs from the other sets")
            (common / s["set"]).mkdir(parents=True, exist_ok=True)
            sizes, md5s = {i: len(d) for i, d in images.items()}, {}
            for i, d in images.items():
                if i == 8:
                    continue
                if i == 1 and len(d) % 4:
                    d = d + b"\x00" * (4 - len(d) % 4)   # config: whole 32-bit words (the bridge delivers words)
                parts = [(f"rom_{i}.bin", d[:BANK]), ("rom_3b.bin", d[BANK:])] if i == 3 and len(d) > BANK else [(f"rom_{i}.bin", d)]
                for name, chunk in parts:
                    (common / s["set"] / name).write_bytes(chunk)
                    md5s[f"{s['set']}/{name}"] = hashlib.md5(chunk).hexdigest()
            write_instance(inst_dir / instance_name(s), s, sizes, md5s)
            packed.append(s["set"])
        if c76 is not None:
            common.mkdir(parents=True, exist_ok=True)
            (common / "c76.bin").write_bytes(c76)
            print(f"c76.bin md5 {hashlib.md5(c76).hexdigest()}")
        print(f"packed {len(packed)}: {' '.join(packed)}")
        for line in skipped:
            print("  not packed:", line)


if __name__ == "__main__":
    main()
