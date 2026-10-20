import sys, struct
from capstone import *
rom = open(sys.argv[1], 'rb').read()
off = int(sys.argv[2], 0); n = int(sys.argv[3], 0); base = int(sys.argv[4], 0) if len(sys.argv) > 4 else 0xBFC00000
md = Cs(CS_ARCH_MIPS, CS_MODE_MIPS32 + CS_MODE_LITTLE_ENDIAN)
for i in md.disasm(rom[off:off + n * 4], base + off):
    print('%08X: %s %s' % (i.address, i.mnemonic, i.op_str))
