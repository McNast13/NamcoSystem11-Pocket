#!/usr/bin/env python3
"""Decode the on-screen diagnostic grid (10 rows x 32 boxes, MSB left, green = 1) from a photo of the Pocket.

diag_decode.py assumes one rectangular grid and drifts by a column under perspective. This one finds the grid's vertical extent from the dark-red/green
cells, then searches the horizontal lattice (left edge, pitch) that best reproduces rows whose value is known to be (nearly) constant across builds:
row 0 flags (737DFC20/F37DFC20), row 2 C76 first PC (00C030B0, from build c76fix on), row 3 platform byte (14xx....). Needs pillow, numpy. Upright photo.
Usage: diag_decode_calib.py photo.jpg [...]
"""
import sys
import numpy as np
from PIL import Image

KNOWN = {0: (0x737DFC20, 0xF37DFC20), 2: (0x00C030B0,), 3: (0x14008000, 0x14018000, 0x14000000)}


def decode(path):
    im = np.asarray(Image.open(path).convert('RGB')).astype(float)
    R, G, B = im[..., 0], im[..., 1], im[..., 2]
    box = ((G > 150) & (R < 150) & (B < 90)) | ((R > 45) & (G < 60) & (B < 60))
    H, W = box.shape
    ys = np.where(box.sum(axis=1) > W * 0.25)[0]
    y0, y1 = ys.min(), ys.max()
    xs = np.where(box[y0:y1].sum(axis=0) > (y1 - y0) * 0.15)[0]
    l0, r0 = xs.min(), xs.max()
    py = (y1 - y0 + 1) / 10.0

    def row_bits(r, left, pitch):
        yc = int(y0 + (r + 0.5) * py)
        s = ''
        for c in range(32):
            xc = int(left + (c + 0.5) * pitch)
            p = im[yc - 4: yc + 5, xc - 4: xc + 5].reshape(-1, 3).mean(0)
            s += '1' if (p[1] > 150 and p[0] < 150) else '0'
        return int(s, 2)

    best = None
    for left in np.arange(l0 - 12, l0 + 25, 1.0):
        for pitch in np.arange((r0 - l0) / 32.0 - 1.0, (r0 - l0) / 32.0 + 3.0, 0.1):
            sc = sum(max(32 - bin(row_bits(r, left, pitch) ^ k).count('1') for k in vals) for r, vals in KNOWN.items())
            if best is None or sc > best[0]: best = (sc, left, pitch)
    sc, left, pitch = best
    return [row_bits(r, left, pitch) for r in range(10)], (sc, left, pitch, y0, py)


if __name__ == '__main__':
    for p in sys.argv[1:]:
        v, info = decode(p)
        print(p.split('/')[-1], 'calibration score %d/%d left %.1f pitch %.2f' % (info[0], 32 * len(KNOWN), info[1], info[2]))
        print('  ' + '  '.join('%08X' % x for x in v))
