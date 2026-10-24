-- Reference: C76 shared RAM 0xBD00-0xBDBF before/while/after Start, after two coins.
local f = 0
local coin, start, mcu
local function field(port, name)
  for n, fl in pairs(manager.machine.ioport.ports[port].fields) do if n == name then return fl end end
end
local function dump(tag)
  local s = tag .. ":"
  for a = 0xbd00, 0xbdbf do
    if a % 16 == 0 then s = s .. string.format("\n  %04X:", a) end
    s = s .. string.format(" %02X", mcu:read_u8(a))
  end
  print(s)
end
emu.register_frame_done(function()
  f = f + 1
  if f == 1 then
    coin = field(":SWITCH", "Coin 1"); start = field(":PLAYER1", "1 Player Start")
    mcu = manager.machine.devices[":c76"].spaces["program"]
  end
  if f == 60*40 or f == 60*42 then coin:set_value(1) end
  if f == 60*40+6 or f == 60*42+6 then coin:set_value(0) end
  if f == 60*45 then dump("idle, 2 coins") end
  if f == 60*46 then start:set_value(1) end
  if f == 60*46+2 then dump("start held 2 frames") end
  if f == 60*46+20 then dump("start held 20 frames") end
  if f == 60*46+30 then start:set_value(0) end
  if f == 60*46+32 then dump("released 2 frames") end
  if f == 60*48 then manager.machine:exit() end
end)
