-- Around Start: C76 + MIPS reads/writes of shared 0x4000-0x40FF (command area).
local f = 0
local coin, start
local on = false
local taps = {}
local function field(port, name)
  for n, fl in pairs(manager.machine.ioport.ports[port].fields) do if n == name then return fl end end
end
emu.register_frame_done(function()
  f = f + 1
  if f == 1 then
    coin = field(":SWITCH", "Coin 1"); start = field(":PLAYER1", "1 Player Start")
    local sp = manager.machine.devices[":maincpu"].spaces["program"]
    taps[1] = sp:install_write_tap(0x1fa04000, 0x1fa040ff, "mw", function(o, d, m) if on then print(string.format("f%d MIPS W %08X=%08X m%08X", f, o, d, m)) end end)
    taps[2] = sp:install_read_tap(0x1fa04000, 0x1fa040ff, "mr", function(o, d, m) if on then print(string.format("f%d MIPS R %08X=%08X m%08X", f, o, d, m)) end end)
    local cp = manager.machine.devices[":c76"].spaces["program"]
    taps[3] = cp:install_write_tap(0x4000, 0x40ff, "cw", function(o, d, m) if on then print(string.format("f%d C76 W %04X=%04X m%04X", f, o, d, m)) end end)
    taps[4] = cp:install_read_tap(0x4000, 0x40ff, "cr", function(o, d, m) if on then print(string.format("f%d C76 R %04X=%04X m%04X", f, o, d, m)) end end)
  end
  if f == 60*40 or f == 60*42 then coin:set_value(1) end
  if f == 60*40+6 or f == 60*42+6 then coin:set_value(0) end
  if f == 60*46-2 then on = true end
  if f == 60*46 then start:set_value(1) end
  if f == 60*47 then start:set_value(0) end
  if f == 60*47+10 then manager.machine:exit() end
end)
