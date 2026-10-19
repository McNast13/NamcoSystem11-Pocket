#!/usr/bin/env python3
"""Pack a MiSTer .mra ROM description plus MAME zips into per-index binary images.

Mirrors the loader semantics of Main_MiSTer support/arcade/mra_loader.cpp (rom_data):
  * <interleave output="N"> sets unit length N/8 bytes.
  * part map is a hex string; the lowest nibble is output byte 0. A non-zero nibble v
    places the part's next byte at (lowest non-zero nibble position) + (v-1) (+ gaps
    between non-zero nibbles). e.g. "01" -> byte 0, "10" -> byte 1.
  * <part>HEX</part> inserts literal bytes; offset/length/repeat/zip attributes honoured.
  * <nvram> is ignored (runtime save data).
CRC32 of every named part is checked against the MRA.

Usage: rom_packer.py GAME.mra --roms DIR --out DIR [--instance NAME]
Writes rom_<index>.bin per <rom index=...> and manifest.json (index, file, size, crc32).
The config image (index 1) is padded to a whole 32-bit word: the Pocket bridge delivers whole words, so
byte 0 = platform id, byte 1 = KEYCUS type, bit 16 = light-gun flag (zero-padded).
--instance NAME also writes NAME.json, an APF instance file naming each image as the data slot of the same index
(MRA index -> data slot id: 0->1, 1->2, 2->3, 3->4, 6->6, 7->7, 8->8; see pocket/dist/.../data.json).
"""
import argparse, json, os, sys, zipfile, zlib
import xml.etree.ElementTree as ET


class PackError(Exception):
    pass


class ZipSet:
    def __init__(self, roms_dir):
        self.dir, self.cache = roms_dir, {}

    def read(self, zip_names, part, crc):
        last = None
        for zn in zip_names.split("|"):
            zn = zn.strip()
            if not zn:
                continue
            if zn not in self.cache:
                path = os.path.join(self.dir, zn)
                self.cache[zn] = zipfile.ZipFile(path) if os.path.exists(path) else None
            z = self.cache[zn]
            if z is None:
                last = f"{zn} not found in {self.dir}"
                continue
            if part in z.namelist():
                data = z.read(part)
                if crc is not None and zlib.crc32(data) != crc:
                    raise PackError(f"{zn}/{part}: CRC {zlib.crc32(data):08x} != expected {crc:08x}")
                return data
            if crc is not None:
                # Merged/renamed sets: accept a differently-named file with the same CRC.
                for info in z.infolist():
                    if info.CRC == crc:
                        return z.read(info)
            last = f"{part} not in {zn}"
        raise PackError(last or f"{part}: no zip given")


def place(image, data, unit, mapv, cursors=None):
    """Port of rom_data(): write `data` into image using the interleave map.

    cursors[idx] (idx = lowest byte lane used by the map) is the next unit number for
    that lane, as romlen[idx] is in the MiSTer loader, so "01" and "10" parts fill
    the same words rather than appending after each other.
    """
    if cursors is None:
        cursors = [0] * 8
    if not mapv:
        mapv = 1
    idx, m = 0, mapv
    for _ in range(unit):
        if m & 0xF:
            break
        m >>= 4
        idx += 1
    if idx >= unit:
        raise PackError("illegal map")
    offsets, first, gaps, m = [], True, 0, mapv
    for _ in range(unit):
        if m & 0xF:
            offsets.append(idx + (m & 0xF) - 1 + gaps)
            first = False
        elif not first:
            gaps += 1
        m >>= 4
    n = len(offsets)
    if len(data) % n:
        raise PackError(f"part length {len(data)} not a multiple of {n} bytes per unit")
    count = len(data) // n
    end = (cursors[idx] + count) * unit
    if len(image) < end:
        image.extend(bytes(end - len(image)))
    for k in range(count):
        base = (cursors[idx] + k) * unit
        for j, off in enumerate(offsets):
            image[base + off] = data[k * n + j]
    cursors[idx] += count


def pack(mra_path, roms_dir):
    root = ET.parse(mra_path).getroot()
    zips, out = ZipSet(roms_dir), {}
    for rom in root.findall("rom"):
        index = int(rom.get("index", "0"))
        default_zip = rom.get("zip", "")
        image, cursors = bytearray(), [0] * 8

        def parts(node, unit):
            for p in node:
                if p.tag == "interleave":
                    yield from parts(p, int(p.get("output", "8")) // 8)
                elif p.tag == "part":
                    yield p, unit

        for p, unit in parts(rom, 1):
            mapv = int(p.get("map", "0"), 16)
            repeat = int(p.get("repeat", "1"), 0)
            name = p.get("name")
            if name:
                crc = int(p.get("crc"), 16) if p.get("crc") else None
                data = zips.read(p.get("zip") or default_zip, name, crc)
                off = int(p.get("offset", "0"), 0)
                ln = int(p.get("length", "0"), 0)
                data = data[off:off + ln] if ln else data[off:]
            else:
                data = bytes.fromhex("".join((p.text or "").split()))
            for _ in range(repeat):
                place(image, data, unit, mapv, cursors)
        out[index] = bytes(image)
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("mra")
    ap.add_argument("--roms", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--instance", help="also write an APF instance JSON with this name (no extension)")
    a = ap.parse_args()
    try:
        images = pack(a.mra, a.roms)
    except (PackError, OSError, zipfile.BadZipFile, ET.ParseError) as e:
        sys.exit(f"error: {e}")
    os.makedirs(a.out, exist_ok=True)
    manifest = []
    for i, d in sorted(images.items()):
        if i == 1 and len(d) % 4:
            d = d + b"\x00" * (4 - len(d) % 4)
        fn = f"rom_{i}.bin"
        with open(os.path.join(a.out, fn), "wb") as f:
            f.write(d)
        manifest.append({"index": i, "file": fn, "size": len(d), "crc32": f"{zlib.crc32(d):08x}"})
        print(f"index {i}: {fn} {len(d)} bytes crc {zlib.crc32(d):08x}")
    with open(os.path.join(a.out, "manifest.json"), "w") as f:
        json.dump(manifest, f, indent=2)
    if a.instance:
        slot_of = {0: 1, 1: 2, 2: 3, 3: 4, 6: 6, 7: 7, 8: 8, 9: 9}
        inst = {"instance": {"magic": "APF_VER_1", "data_path": a.instance + "/",
                             "data_slots": [{"id": slot_of[m["index"]], "filename": m["file"]} for m in manifest]}}
        with open(os.path.join(a.out, a.instance + ".json"), "w") as f:
            json.dump(inst, f, indent=2)
        print(f"instance: {a.instance}.json ({len(manifest)} slots)")


if __name__ == "__main__":
    main()
