-- Reference: every MIPS store into C76 shared RAM (offset, data, mem_mask), counted by (address, mask) and logged around the Start press.
local f = 0
local coin, start, tap
local seen = {}
local log_on = false
local function field(port, name)
  for n, fl in pairs(manager.machine.ioport.ports[port].fields) do if n == name then return fl end end
end
emu.register_frame_done(function()
  f = f + 1
  if f == 1 then
    coin = field(":SWITCH", "Coin 1"); start = field(":PLAYER1", "1 Player Start")
    local sp = manager.machine.devices[":maincpu"].spaces["program"]
    tap = sp:install_write_tap(0x1fa04000, 0x1fa0bfff, "shw", function(offset, data, mask)
      local k = string.format("%08X/%08X", offset, mask)
      seen[k] = (seen[k] or 0) + 1
      if log_on and offset >= 0x1fa0bd00 and offset < 0x1fa0bdc0 then
        print(string.format("f%d W %08X = %08X mask %08X", f, offset, data, mask))
      end
    end)
  end
  if f == 60*40 or f == 60*42 then coin:set_value(1) end
  if f == 60*40+6 or f == 60*42+6 then coin:set_value(0) end
  if f == 60*45 then log_on = true end
  if f == 60*46 then start:set_value(1) end
  if f == 60*46+30 then start:set_value(0) end
  if f == 60*46+40 then
    log_on = false
    print("all store (address/mask) kinds into shared RAM:")
    local masks = {}
    for k, n in pairs(seen) do local m = k:sub(10); masks[m] = (masks[m] or 0) + n end
    for m, n in pairs(masks) do print("  mask " .. m .. ": " .. n) end
    manager.machine:exit()
  end
end)
