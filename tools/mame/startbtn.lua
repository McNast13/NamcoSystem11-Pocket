-- After 2 coins: hold Start 1 s at 46 s, snapshots at 48/52/58 s; then Button 1 at 60 s, snapshots at 62/68 s.
local f = 0
local coin, start, b1
local function field(port, name)
  for n, fl in pairs(manager.machine.ioport.ports[port].fields) do if n == name then return fl end end
  for n, _ in pairs(manager.machine.ioport.ports[port].fields) do print(port .. " has " .. n) end
end
emu.register_frame_done(function()
  f = f + 1
  if f == 1 then coin = field(":SWITCH", "Coin 1"); start = field(":PLAYER1", "1 Player Start"); b1 = field(":PLAYER1", "P1 Button 1") end
  if f == 60*40 or f == 60*42 then coin:set_value(1) end
  if f == 60*40+6 or f == 60*42+6 then coin:set_value(0) end
  if f == 60*44 then manager.machine.video:snapshot() end
  if f == 60*46 then start:set_value(1) end
  if f == 60*47 then start:set_value(0) end
  if f == 60*48 or f == 60*52 or f == 60*58 then manager.machine.video:snapshot() end
  if f == 60*60 then b1:set_value(1) end
  if f == 60*60+10 then b1:set_value(0) end
  if f == 60*62 or f == 60*68 then manager.machine.video:snapshot() end
  if f == 60*69 then manager.machine:exit() end
end)
