local f, last = 0, nil
local coin, start, sp
local function field(port, name)
  for n, fl in pairs(manager.machine.ioport.ports[port].fields) do if n == name then return fl end end
end
emu.register_frame_done(function()
  f = f + 1
  if f == 1 then coin = field(":SWITCH", "Coin 1"); start = field(":PLAYER1", "1 Player Start"); sp = manager.machine.devices[":maincpu"].spaces["program"] end
  local v = sp:read_u32(0x80264880)
  if v ~= last then print(string.format("f%5d (%5.1fs) state=%08X", f, f / 60, v)); last = v end
  if f == 60*70 or f == 60*72 then coin:set_value(1) end
  if f == 60*70+6 or f == 60*72+6 then coin:set_value(0) end
  if f == 60*120 then manager.machine:exit() end
end)
