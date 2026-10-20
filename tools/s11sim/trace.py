import sys, pickle, collections
sys.path.insert(0, sys.argv[1])
from r3k import *
D = sys.argv[1]; N = int(float(sys.argv[2]))
st = pickle.load(open(D + '/snap_entry.pkl', 'rb'))
rom0 = open(D + '/t2/rom_0.bin', 'rb').read(); rom3 = open(D + '/t2/rom_3.bin', 'rb').read()
class T(R3K):
    def rd(self, a, size):
        v = R3K.rd(self, a, size); p = a & 0x1FFFFFFF
        if p >= 0x1F800400 and not (0x1F000000 <= p < 0x1F800000) and not (0x1FC00000 <= p) : self.ev.append((self.n, self.pc, 'R', p, size, v))
        elif 0x1F000000 <= p < 0x1F800000 or p >= 0x1FC00000: self.ev.append((self.n, self.pc, 'r', p, size, v))
        return v
    def wr(self, a, size, v):
        p = a & 0x1FFFFFFF
        if p >= 0x1F800400: self.ev.append((self.n, self.pc, 'W', p, size, v & 0xFFFFFFFF))
        R3K.wr(self, a, size, v)
cpu = T(rom0, rom3); cpu.ev = []
cpu.ram[:] = st['ram']; cpu.sp[:] = st['sp']; cpu.r = list(st['r']); cpu.hi = st['hi']; cpu.lo = st['lo']; cpu.pc = st['pc']; cpu.npc = st['npc']; cpu.pend = st['pend']; cpu.cop0 = list(st['cop0']); cpu.io = dict(st['io']); cpu.n = st['n']
n0 = cpu.n; hist = collections.Counter(); seen = {}
try:
    for i in range(N):
        cpu.step(); hist[cpu.pc >> 8] += 1
except Exception as e:
    print('stop:', e, 'pc %08X after %d instr' % (cpu.pc, cpu.n - n0))
print('executed %d, final pc %08X' % (cpu.n - n0, cpu.pc))
# first occurrence of each (type,addr) event
first = collections.OrderedDict(); cnt = collections.Counter()
for ev in cpu.ev:
    k = (ev[2], ev[3]); cnt[k] += 1
    if k not in first: first[k] = ev
for k, ev in list(first.items())[:70]:
    print('%9d pc %08X %s %08X sz%d val %08X  (x%d)' % (ev[0] - n0, ev[1], ev[2], ev[3], ev[4], ev[5], cnt[k]))
print('top code pages (256B):', ['%08X:%d' % (a << 8, c) for a, c in hist.most_common(8)])
