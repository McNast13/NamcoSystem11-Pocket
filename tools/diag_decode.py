import sys, numpy as np
from PIL import Image
def decode(path, rot=0, rows=10):
    im = Image.open(path).convert('RGB')
    if rot: im = im.rotate(rot, expand=True)
    a = np.asarray(im).astype(int); H, W, _ = a.shape
    R, G, B = a[..., 0], a[..., 1], a[..., 2]
    green = (G > 150) & (R < 150) & (B < 90)
    red = (R > 70) & (R < 190) & (G < 45) & (B < 45)
    box = green | red
    # box area bounding box (robust), restricted to the upper picture area
    bright = a.max(axis=2) > 170
    # bars bottom (bright, wide) gives an upper limit for the box area
    frac = bright.mean(axis=1); ys = [y for y in range(H - 1, H // 3, -1) if frac[y] > 0.35]
    ybot = ys[0]
    yl = np.where(box[: ybot - 330].sum(axis=1) > 40)[0]; y0, y1 = np.percentile(yl, [0.3, 99.7])
    xl = np.where(box[int(y0):int(y1)].sum(axis=0) > 6)[0]; x0, x1 = np.percentile(xl, [0.3, 99.7])
    s = (x1 - x0) / 319.0
    out = []
    for r in range(rows):
        yc = y0 + (16 * r + 7) * s
        row = []
        for c in range(32):
            xc = x0 + (10 * c + 4.5) * s
            p = a[int(yc) - 2:int(yc) + 3, int(xc) - 2:int(xc) + 3].reshape(-1, 3).mean(axis=0)
            row.append(1 if (p[1] > 150 and p[0] < 150) else 0)
        out.append(int(''.join(map(str, row)), 2))
    return out, (x0, x1, y0, y1, s)
if __name__ == '__main__':
    rot = 0
    args = sys.argv[1:]
    if args[0] == '--rot': rot = int(args[1]); args = args[2:]
    for p in args:
        v, g = decode(p, rot)
        print(p.split('/')[-1], 'grid x %.0f-%.0f y %.0f-%.0f s %.2f' % g)
        print('  ' + '  '.join('%08X' % x for x in v))
