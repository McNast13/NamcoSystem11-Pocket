local f = 0
local coin, start, sp
local function field(port, name)
  for n, fl in pairs(manager.machine.ioport.ports[port].fields) do if n == name then return fl end end
end
local function dump(tag)
  local s = tag
  for _, a in ipairs({0x802648D0, 0x80267038, 0x80267040, 0x8013FDDC, 0x8013FDE0, 0x8026488C, 0x80264880}) do
    s = s .. string.format(" [%08X]=%08X", a, sp:read_u32(a))
  end
  print(s)
end
emu.register_frame_done(function()
  f = f + 1
  if f == 1 then coin = field(":SWITCH", "Coin 1"); start = field(":PLAYER1", "1 Player Start"); sp = manager.machine.devices[":maincpu"].spaces["program"] end
  if f == 60*40 or f == 60*42 then coin:set_value(1) end
  if f == 60*40+6 or f == 60*42+6 then coin:set_value(0) end
  if f == 60*39 then dump("before coins") end
  if f == 60*45 then dump("2 coins     ") end
  if f == 60*46 then start:set_value(1) end
  if f >= 60*46 and f <= 60*46+3 then dump(string.format("start +%d    ", f - 60*46)) end
  if f == 60*46+30 then dump("start +30   ") end
  if f == 60*47 then manager.machine:exit() end
end)
