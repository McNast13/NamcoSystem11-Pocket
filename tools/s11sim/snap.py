import sys, time, pickle
sys.path.insert(0, sys.argv[1])
from r3k import *
D = sys.argv[1]
rom0 = open(D + '/t2/rom_0.bin', 'rb').read(); rom3 = open(D + '/t2/rom_3.bin', 'rb').read()
cpu = R3K(rom0, rom3); t0 = time.time()
while True:
    cpu.step()
    p = cpu.pc & 0x1FFFFFFF
    if (0x10000 <= p < 0x40000) or cpu.n > 2e8: break
print('entry pc %08X n=%d %.0fs' % (cpu.pc, cpu.n, time.time() - t0))
state = dict(ram=bytes(cpu.ram), sp=bytes(cpu.sp), r=cpu.r, hi=cpu.hi, lo=cpu.lo, pc=cpu.pc, npc=cpu.npc, pend=cpu.pend, cop0=cpu.cop0, io=cpu.io, n=cpu.n)
pickle.dump(state, open(D + '/snap_entry.pkl', 'wb'))
