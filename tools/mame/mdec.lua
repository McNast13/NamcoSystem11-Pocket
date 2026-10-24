-- MDEC register accesses per second, alongside the game state.
local f, last = 0, nil
local coin, sp
local taps = {}
local nw, nr = 0, 0
local function field(port, name)
  for n, fl in pairs(manager.machine.ioport.ports[port].fields) do if n == name then return fl end end
end
emu.register_frame_done(function()
  f = f + 1
  if f == 1 then
    coin = field(":SWITCH", "Coin 1"); sp = manager.machine.devices[":maincpu"].spaces["program"]
    taps[1] = sp:install_write_tap(0x1f801820, 0x1f801827, "mw", function() nw = nw + 1 end)
    taps[2] = sp:install_read_tap(0x1f801820, 0x1f801827, "mr", function() nr = nr + 1 end)
  end
  local v = sp:read_u32(0x80264880)
  if v ~= last or f % 60 == 0 then
    if nw + nr > 0 or v ~= last then print(string.format("f%5d (%5.1fs) state=%08X mdec w=%d r=%d", f, f / 60, v, nw, nr)) end
    last = v; nw = 0; nr = 0
  end
  if f == 60*70 or f == 60*72 then coin:set_value(1) end
  if f == 60*70+6 or f == 60*72+6 then coin:set_value(0) end
  if f == 60*100 then manager.machine:exit() end
end)
