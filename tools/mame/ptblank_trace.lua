local f = 0
local sp, cpu, coin, start, trig
local cnt = {}
local function inc(k) cnt[k] = (cnt[k] or 0) + 1 end
local taps = {}
local function field(port, name)
  for n, fl in pairs(manager.machine.ioport.ports[port].fields) do if n == name then return fl end end
end
local kp1, kp2 = 0, 0
emu.register_frame_done(function()
  f = f + 1
  if f == 1 then
    cpu = manager.machine.devices[":maincpu"]; sp = cpu.spaces["program"]
    for n, _ in pairs(manager.machine.ioport.ports[":PLAYER1"].fields) do print("P1 field: " .. n) end
    coin = field(":SWITCH", "Coin 1"); start = field(":PLAYER1", "1 Player Start"); trig = field(":PLAYER1", "P1 Button 1")
    taps[#taps+1] = sp:install_write_tap(0x1fa20000, 0x1fa2001f, "kw", function(o, d, m)
      if m & 0xffff ~= 0 then kp1 = d & 0xffff end
      if m & 0xffff0000 ~= 0 then kp2 = (d >> 16) & 0xffff end
      inc(string.format("keycus W %08x m%08x d%08x", o, m, d)) end)
    taps[#taps+1] = sp:install_read_tap(0x1fa20000, 0x1fa2001f, "kr", function(o, d, m)
      inc(string.format("keycus R %08x m%08x p1=%04x p2=%04x -> %08x", o, m, kp1, kp2, d)) end)
    taps[#taps+1] = sp:install_write_tap(0x1fa30000, 0x1fa30fff, "ew", function(o, d, m) inc("eeprom W") end)
    taps[#taps+1] = sp:install_read_tap(0x1fa30000, 0x1fa30fff, "er", function(o, d, m) inc("eeprom R") end)
    taps[#taps+1] = sp:install_write_tap(0x1f788000, 0x1f788003, "gw", function(o, d, m) inc(string.format("gun W %08x", d)) end)
    taps[#taps+1] = sp:install_read_tap(0x1f780000, 0x1f78000f, "gr", function(o, d, m) inc(string.format("gun R %08x", o)) end)
    taps[#taps+1] = sp:install_write_tap(0x1f080000, 0x1f080003, "uw", function(o, d, m) inc(string.format("upper W %08x m%08x", o, m)) end)
    taps[#taps+1] = sp:install_write_tap(0x1fa10020, 0x1fa1002f, "bw", function(o, d, m) inc("bank W") end)
    taps[#taps+1] = sp:install_write_tap(0x1f801820, 0x1f801827, "mw", function(o, d, m) inc("mdec W") end)
  end
  local t = f / 60
  if f == 60*15 or f == 60*16 then coin:set_value(1) end
  if f == 60*15+6 or f == 60*16+6 then coin:set_value(0) end
  if f == 60*18 then start:set_value(1) end
  if f == 60*18+6 then start:set_value(0) end
  if f > 60*20 then trig:set_value(((f // 8) % 2 == 0) and 1 or 0) end
  if f % 300 == 0 then
    print(string.format("=== %5.1fs", t))
    local ks = {}
    for k, v in pairs(cnt) do ks[#ks+1] = k end
    table.sort(ks)
    for _, k in ipairs(ks) do print(string.format("   %6d %s", cnt[k], k)) end
    cnt = {}
  end
  if f == 60*150 then manager.machine:exit() end
end)
