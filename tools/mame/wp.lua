-- Debugger: catch the MIPS store of 0x4113 to 0x1fa0402e and print the CPU state.
local f = 0
local coin, start, armed
local function field(port, name)
  for n, fl in pairs(manager.machine.ioport.ports[port].fields) do if n == name then return fl end end
end
emu.register_frame_done(function()
  f = f + 1
  if f == 1 then
    coin = field(":SWITCH", "Coin 1"); start = field(":PLAYER1", "1 Player Start")
    local dbg = manager.machine.debugger
    dbg:command("focus maincpu")
    dbg:command('wpset 1fa0402c,4,w,wpdata==41130000,{printf "HIT pc=%08X ra=%08X sp=%08X",pc,r31,r29; trace off; go}')
    dbg:command("go")
  end
  if f == 60*40 or f == 60*42 then coin:set_value(1) end
  if f == 60*40+6 or f == 60*42+6 then coin:set_value(0) end
  if f == 60*46 then start:set_value(1) end
  if f == 60*47 then start:set_value(0) end
  if f == 60*48 then manager.machine:exit() end
end)
