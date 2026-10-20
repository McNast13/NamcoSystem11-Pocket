import sys, struct, time, collections
M32 = 0xFFFFFFFF
class R3K:
    def __init__(self, rom0, rom3):
        self.ram = bytearray(0x400000); self.sp = bytearray(0x400)
        self.rom0, self.rom3 = rom0, rom3
        self.r = [0] * 32; self.hi = self.lo = 0; self.pc = 0xBFC00000; self.npc = self.pc + 4
        self.pend = None; self.cop0 = [0] * 32; self.cop0[12] = 0x00400000   # BEV set
        self.io = {}; self.io_log = collections.OrderedDict(); self.n = 0
        self.gpustat = 0x14802000
        self.in_delay = False; self.branch_pc = 0
    # ---- memory ----
    def rd(self, a, size):
        p = a & 0x1FFFFFFF
        if p < 0x800000: p &= 0x3FFFFF; return int.from_bytes(self.ram[p:p+size], 'little')
        if 0x1F800000 <= p < 0x1F800400: return int.from_bytes(self.sp[p-0x1F800000:p-0x1F800000+size], 'little')
        if 0x1FC00000 <= p < 0x20000000: o = p - 0x1FC00000; return int.from_bytes(self.rom0[o:o+size], 'little')
        if 0x1F000000 <= p < 0x1F800000: o = p - 0x1F000000; return int.from_bytes(self.rom3[o:o+size], 'little')
        if p == 0x1F801814: return self.gpustat
        if p == 0x1F801810: return 0
        if 0x1F802000 <= p < 0x1F802100: return (0xFFFFFFFF >> (8 * (4 - size))) & ((1 << (8 * size)) - 1) if size < 4 else 0xFFFFFFFF   # expansion-2 UART: always ready
        v = self.io.get(p & ~3, 0)
        key = (p & ~3)
        self.io_log.setdefault(key, [0, 0]); self.io_log[key][0] += 1
        return (v >> (8 * (p & 3))) & ((1 << (8 * size)) - 1)
    def wr(self, a, size, v):
        p = a & 0x1FFFFFFF
        if self.cop0[12] & 0x10000: return           # isolate cache: writes do not reach memory
        v &= (1 << (8 * size)) - 1
        if p < 0x800000: p &= 0x3FFFFF; self.ram[p:p+size] = v.to_bytes(size, 'little'); return
        if 0x1F800000 <= p < 0x1F800400: o = p - 0x1F800000; self.sp[o:o+size] = v.to_bytes(size, 'little'); return
        key = p & ~3
        self.io_log.setdefault(key, [0, 0]); self.io_log[key][1] += 1
        if size == 4: self.io[key] = v
    def w(self, i, v):
        if i: self.r[i] = v & M32
    def exc(self, code):
        self.cop0[14] = (self.branch_pc if self.in_delay else self.pc - 0) & M32     # EPC (pc of faulting instr)
        sr = self.cop0[12]; self.cop0[12] = (sr & ~0x3F) | ((sr << 2) & 0x3C)
        self.cop0[13] = (code << 2) | (0x80000000 if self.in_delay else 0)
        vec = 0xBFC00180 if sr & 0x400000 else 0x80000080
        self.pc = vec; self.npc = vec + 4
    def step(self):
        pc = self.pc; ins = self.rd(pc, 4); self.in_delay = False
        pend = self.pend; self.pend = None
        r = self.r; op = ins >> 26; rs = (ins >> 21) & 31; rt = (ins >> 16) & 31; rd = (ins >> 11) & 31; sh = (ins >> 6) & 31
        imm = ins & 0xFFFF; simm = imm - 0x10000 if imm & 0x8000 else imm
        npc2 = (self.npc + 4) & M32; nxt = self.npc; taken = None
        def sx(v): return v - (1 << 32) if v & 0x80000000 else v
        if op == 0:
            f = ins & 63
            if f == 0: self.w(rd, r[rt] << sh)
            elif f == 2: self.w(rd, r[rt] >> sh)
            elif f == 3: self.w(rd, sx(r[rt]) >> sh)
            elif f == 4: self.w(rd, r[rt] << (r[rs] & 31))
            elif f == 6: self.w(rd, r[rt] >> (r[rs] & 31))
            elif f == 7: self.w(rd, sx(r[rt]) >> (r[rs] & 31))
            elif f == 8: taken = r[rs]
            elif f == 9: t = r[rs]; self.w(rd, self.npc + 4); taken = t
            elif f == 12: self.exc(8); self.commit(pend); return
            elif f == 13: self.exc(9); self.commit(pend); return
            elif f == 16: self.w(rd, self.hi)
            elif f == 17: self.hi = r[rs]
            elif f == 18: self.w(rd, self.lo)
            elif f == 19: self.lo = r[rs]
            elif f == 24: p = sx(r[rs]) * sx(r[rt]); self.lo = p & M32; self.hi = (p >> 32) & M32
            elif f == 25: p = r[rs] * r[rt]; self.lo = p & M32; self.hi = (p >> 32) & M32
            elif f == 26:
                a, b = sx(r[rs]), sx(r[rt])
                if b == 0: self.lo = 1 if a < 0 else M32; self.hi = a & M32
                else:
                    q = abs(a) // abs(b); q = -q if (a < 0) != (b < 0) else q; self.lo = q & M32; self.hi = (a - q * b) & M32
            elif f == 27:
                if r[rt] == 0: self.lo = M32; self.hi = r[rs]
                else: self.lo = r[rs] // r[rt]; self.hi = r[rs] % r[rt]
            elif f in (32, 33): self.w(rd, r[rs] + r[rt])
            elif f in (34, 35): self.w(rd, r[rs] - r[rt])
            elif f == 36: self.w(rd, r[rs] & r[rt])
            elif f == 37: self.w(rd, r[rs] | r[rt])
            elif f == 38: self.w(rd, r[rs] ^ r[rt])
            elif f == 39: self.w(rd, ~(r[rs] | r[rt]))
            elif f == 42: self.w(rd, 1 if sx(r[rs]) < sx(r[rt]) else 0)
            elif f == 43: self.w(rd, 1 if r[rs] < r[rt] else 0)
            else: raise RuntimeError('special %d at %08X' % (f, pc))
        elif op == 1:
            cond = (sx(r[rs]) < 0) if (rt & 1) == 0 else (sx(r[rs]) >= 0)
            if rt & 0x10: self.w(31, self.npc + 4)
            if cond: taken = (self.npc + (simm << 2)) & M32
        elif op == 2: taken = (self.npc & 0xF0000000) | ((ins & 0x3FFFFFF) << 2)
        elif op == 3: self.w(31, self.npc + 4); taken = (self.npc & 0xF0000000) | ((ins & 0x3FFFFFF) << 2)
        elif op == 4:
            if r[rs] == r[rt]: taken = (self.npc + (simm << 2)) & M32
        elif op == 5:
            if r[rs] != r[rt]: taken = (self.npc + (simm << 2)) & M32
        elif op == 6:
            if sx(r[rs]) <= 0: taken = (self.npc + (simm << 2)) & M32
        elif op == 7:
            if sx(r[rs]) > 0: taken = (self.npc + (simm << 2)) & M32
        elif op in (8, 9): self.w(rt, r[rs] + simm)
        elif op == 10: self.w(rt, 1 if sx(r[rs]) < simm else 0)
        elif op == 11: self.w(rt, 1 if r[rs] < (simm & M32) else 0)
        elif op == 12: self.w(rt, r[rs] & imm)
        elif op == 13: self.w(rt, r[rs] | imm)
        elif op == 14: self.w(rt, r[rs] ^ imm)
        elif op == 15: self.w(rt, imm << 16)
        elif op == 16:
            if rs == 0: self.w(rt, self.cop0[rd])
            elif rs == 4: self.cop0[rd] = r[rt]
            elif rs == 16 and (ins & 63) == 16: sr = self.cop0[12]; self.cop0[12] = (sr & ~0xF) | ((sr >> 2) & 0xF)
        elif op == 18: pass                                  # COP2 (GTE): ignored
        elif op in (32, 33, 34, 35, 36, 37, 38):
            a = (r[rs] + simm) & M32
            if op == 32: v = self.rd(a, 1); v = v - 256 if v & 128 else v; self.pend = (rt, v & M32)
            elif op == 33: v = self.rd(a, 2); v = v - 65536 if v & 32768 else v; self.pend = (rt, v & M32)
            elif op == 35: self.pend = (rt, self.rd(a, 4))
            elif op == 36: self.pend = (rt, self.rd(a, 1))
            elif op == 37: self.pend = (rt, self.rd(a, 2))
            elif op == 34:                                   # lwl
                al = a & ~3; w = self.rd(al, 4); k = a & 3; cur = r[rt] if not (pend and pend[0] == rt) else pend[1]
                self.pend = (rt, ((cur & (0x00FFFFFF >> (8 * (3 - k)))) | ((w << (8 * (3 - k))) & M32)) & M32)
            elif op == 38:                                   # lwr
                al = a & ~3; w = self.rd(al, 4); k = a & 3; cur = r[rt] if not (pend and pend[0] == rt) else pend[1]
                self.pend = (rt, ((cur & ((0xFFFFFF00 << (8 * (3 - k))) & M32)) | (w >> (8 * k))) & M32)
        elif op in (40, 41, 43, 42, 46):
            a = (r[rs] + simm) & M32
            if op == 40: self.wr(a, 1, r[rt])
            elif op == 41: self.wr(a, 2, r[rt])
            elif op == 43: self.wr(a, 4, r[rt])
            elif op == 42:                                   # swl
                al = a & ~3; k = a & 3; w = self.rd(al, 4); self.wr(al, 4, (w & ((0xFFFFFF00 << (8 * k)) & M32)) | (r[rt] >> (8 * (3 - k))))
            elif op == 46:                                   # swr
                al = a & ~3; k = a & 3; w = self.rd(al, 4); self.wr(al, 4, (w & (0x00FFFFFF >> (8 * (3 - k)))) | ((r[rt] << (8 * k)) & M32))
        elif op in (50, 58): pass                            # lwc2/swc2
        else: raise RuntimeError('op %d at %08X' % (op, pc))
        self.finish(pend, taken)
    def commit(self, pend):
        if pend is not None and not (self.pend is not None and self.pend[0] == pend[0]):
            if pend[0]: self.r[pend[0]] = pend[1]
        self.n += 1
    def finish(self, pend, taken=None):
        if pend is not None and not (self.pend is not None and self.pend[0] == pend[0]):
            if pend[0]: self.r[pend[0]] = pend[1]
        if self.pc != self.last_pc_set if False else True: pass
        nxt = self.npc
        self.pc = nxt
        self.npc = taken if taken is not None else (nxt + 4) & M32
        self.n += 1
