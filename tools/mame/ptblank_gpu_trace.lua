-- Point Blank 2 GPU/IO profile, played by hand: per-second histogram of GP0 commands (DMA2 linked lists walked from RAM,
-- block DMA and direct GP0 writes), GP1 writes, MDEC use and gun reads. Lines go to stdout and to ptblank_gpu_trace.log.
-- Save states (Shift+F7) are marked in the log so a stage can be lined up with its numbers.
-- mame -rompath roms ptblank2a -window -autoboot_script ptblank_gpu_trace.lua
local f = 0
local sp
local cnt = {}
local taps = {}
local madr, bcr = 0, 0
local log = io.open("ptblank_gpu_trace.log", "w")
local function out(s) print(s); log:write(s .. "\n"); log:flush() end
local function inc(k, n) cnt[k] = (cnt[k] or 0) + (n or 1) end

local function cmd_words(op)
  if op >= 0x20 and op < 0x40 then
    local verts = (op & 0x08) ~= 0 and 4 or 3
    local tex = (op & 0x04) ~= 0 and 1 or 0
    local gour = (op & 0x10) ~= 0 and 1 or 0
    return 1 + verts * (1 + tex) + (verts - 1) * gour
  elseif op >= 0x60 and op < 0x80 then
    local tex = (op & 0x04) ~= 0 and 1 or 0
    local var = (op & 0x18) == 0 and 1 or 0
    return 2 + tex + var
  elseif op == 0x02 then return 3
  elseif op >= 0x80 and op < 0xa0 then return 4
  elseif op >= 0xa0 and op < 0xe0 then return 3
  elseif op >= 0x40 and op < 0x60 then return nil   -- lines: polyline lengths vary, stop parsing the packet
  else return 1 end
end

local function name(op)
  if op >= 0x20 and op < 0x40 then
    return string.format("poly%d%s%s%s", (op & 8) ~= 0 and 4 or 3, (op & 0x10) ~= 0 and "G" or "F",
      (op & 4) ~= 0 and "T" or "", (op & 2) ~= 0 and "s" or "")
  elseif op >= 0x40 and op < 0x60 then return string.format("line%02x", op & 0xfc)
  elseif op >= 0x60 and op < 0x80 then return string.format("rect%02x", op & 0xfc)
  elseif op >= 0x80 and op < 0xa0 then return "vram2vram"
  elseif op >= 0xa0 and op < 0xc0 then return "cpu2vram"
  elseif op >= 0xc0 and op < 0xe0 then return "vram2cpu"
  else return string.format("op%02x", op) end
end

local function walk_list(a)
  local packets, words, n = 0, 0, 0
  while n < 200000 do
    n = n + 1
    a = a & 0xfffffc
    local hdr = sp:read_u32(a)
    local len = hdr >> 24
    packets = packets + 1
    words = words + len
    local i = 0
    while i < len do
      local w = sp:read_u32((a + 4 + i * 4) & 0xfffffc)
      local op = w >> 24
      inc("gp0 " .. name(op))
      local l = cmd_words(op)
      if not l then break end
      i = i + l
    end
    local nxt = hdr & 0xffffff
    if (nxt & 0x800000) ~= 0 then break end
    if nxt == a then inc("LIST LOOPS TO ITSELF") break end
    a = nxt
  end
  if n >= 200000 then inc("LIST TOO LONG") end
  inc("dma2 lists"); inc("dma2 list packets", packets); inc("dma2 list words", words)
end

emu.register_frame_done(function()
  f = f + 1
  if f == 1 then
    sp = manager.machine.devices[":maincpu"].spaces["program"]
    taps[#taps+1] = sp:install_write_tap(0x1f8010a0, 0x1f8010af, "dma2", function(o, d, m)
      if o == 0x1f8010a0 then madr = d
      elseif o == 0x1f8010a4 then bcr = d
      elseif o == 0x1f8010a8 and (d & 0x01000000) ~= 0 then
        local sync = (d >> 9) & 3
        local dir = d & 1
        if sync == 2 then walk_list(madr)
        elseif dir == 1 then inc("dma2 block to gpu words", (bcr & 0xffff) * math.max(bcr >> 16, 1))
        else inc("dma2 block from gpu") end
      end
    end)
    taps[#taps+1] = sp:install_write_tap(0x1f801810, 0x1f801817, "gpu", function(o, d, m)
      if o == 0x1f801810 then inc("direct gp0 " .. name(d >> 24))
      else inc(string.format("gp1 %02x", d >> 24)) end
    end)
    taps[#taps+1] = sp:install_write_tap(0x1f801820, 0x1f801827, "mdec", function(o, d, m) inc("mdec W") end)
    taps[#taps+1] = sp:install_read_tap(0x1f780000, 0x1f78000f, "gun", function(o, d, m)
      inc(string.format("gun R %02x", o & 0xf)) end)
    pcall(function() emu.add_machine_pre_save_notifier(function(n) out(string.format("##### SAVE STATE %s at %.1fs", tostring(n), f / 60)) end) end)
  end
  if f % 60 == 0 then
    local ks = {}
    for k, _ in pairs(cnt) do ks[#ks+1] = k end
    table.sort(ks)
    local parts = {}
    for _, k in ipairs(ks) do parts[#parts+1] = string.format("%s=%d", k, cnt[k]) end
    out(string.format("[%5ds] %s", f // 60, table.concat(parts, " ")))
    cnt = {}
  end
end)
