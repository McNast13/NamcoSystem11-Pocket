-- Reference run: attract, two coins, Start; snapshots along the way.
local f = 0
local function field(port, name)
  local p = manager.machine.ioport.ports[port]
  for n, fl in pairs(p.fields) do if n == name then return fl end end
  print("missing field " .. port .. " " .. name)
  for n, _ in pairs(p.fields) do print("  have: " .. n) end
end
local coin, start
local events = {
  [60*40] = "snap", [60*45] = "coin_on", [60*45+6] = "coin_off", [60*47] = "snap",
  [60*49] = "coin_on", [60*49+6] = "coin_off", [60*51] = "snap",
  [60*53] = "start_on", [60*53+10] = "start_off", [60*56] = "snap", [60*60] = "snap", [60*62] = "exit",
}
emu.register_frame_done(function()
  f = f + 1
  if f == 1 then coin = field(":SWITCH", "Coin 1"); start = field(":PLAYER1", "1 Player Start") end
  local e = events[f]
  if e == "snap" then manager.machine.video:snapshot(); print("snap at frame " .. f)
  elseif e == "coin_on" then coin:set_value(1)
  elseif e == "coin_off" then coin:set_value(0)
  elseif e == "start_on" then start:set_value(1)
  elseif e == "start_off" then start:set_value(0)
  elseif e == "exit" then manager.machine:exit() end
end)
