-- Write tap: CPU state when the MIPS stores 0x4113 to 0x1fa0402e.
local f = 0
local coin, start
local taps = {}
local function field(port, name)
  for n, fl in pairs(manager.machine.ioport.ports[port].fields) do if n == name then return fl end end
end
emu.register_frame_done(function()
  f = f + 1
  if f == 1 then
    coin = field(":SWITCH", "Coin 1"); start = field(":PLAYER1", "1 Player Start")
    local cpu = manager.machine.devices[":maincpu"]
    local names = {}
    for k, _ in pairs(cpu.state) do names[#names + 1] = k end
    table.sort(names); print("state: " .. table.concat(names, " "))
    taps[1] = cpu.spaces["program"]:install_write_tap(0x1fa0402c, 0x1fa0402f, "w", function(o, d, m)
      if d == 0x41130000 then
        local s = string.format("HIT f%d", f)
        for _, r in ipairs({"pc", "CURPC", "v0", "v1", "a0", "a1", "a2", "a3", "s0", "s1", "s2", "sp", "ra"}) do
          if cpu.state[r] then s = s .. string.format(" %s=%08X", r, cpu.state[r].value) end
        end
        print(s)
      end
    end)
  end
  if f == 60*40 or f == 60*42 then coin:set_value(1) end
  if f == 60*40+6 or f == 60*42+6 then coin:set_value(0) end
  if f == 60*46 then start:set_value(1) end
  if f == 60*47 then start:set_value(0) end
  if f == 60*48 then manager.machine:exit() end
end)
