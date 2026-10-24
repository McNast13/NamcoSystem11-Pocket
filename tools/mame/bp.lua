local f = 0
local coin, start
local function field(port, name)
  for n, fl in pairs(manager.machine.ioport.ports[port].fields) do if n == name then return fl end end
end
emu.register_frame_done(function()
  f = f + 1
  if f == 1 then
    coin = field(":SWITCH", "Coin 1"); start = field(":PLAYER1", "1 Player Start")
    local d = manager.machine.debugger
    d:command("focus maincpu")
    d:command('bpset 8002F450,1,{logerror "BP f450 ra=%08X\\n",ra; go}')
    d:command("go")
  end
  if f == 60*40 or f == 60*42 then coin:set_value(1) end
  if f == 60*40+6 or f == 60*42+6 then coin:set_value(0) end
  if f == 60*46 then start:set_value(1) end
  if f == 60*47 then start:set_value(0) end
  if f == 60*47 then manager.machine:exit() end
end)
