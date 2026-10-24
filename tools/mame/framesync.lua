-- How the game paces drawing against the display: per frame, log GPU DMA starts (DMA2 CHCR writes with the start bit),
-- display-area flips (GP1 0x05), and polls of GPUSTAT / DMA2 CHCR (DrawSync-style waits), with the CPU cycle of each event.
local f = 0
local cpu, sp
local taps = {}
local on = false
local polls_stat, polls_chcr = 0, 0
local function cyc() return manager.machine.time:as_double() end
local t0 = 0
emu.register_frame_done(function()
  f = f + 1
  if f == 1 then
    cpu = manager.machine.devices[":maincpu"]; sp = cpu.spaces["program"]
    taps[1] = sp:install_write_tap(0x1f8010a8, 0x1f8010ab, "chcr2", function(o, d, m)
      if on and (d & 0x01000000) ~= 0 then print(string.format("f%d +%.2fms DMA2 start chcr=%08X madr=%08X", f, (cyc()-t0)*1000, d, sp:read_u32(0x1f8010a0))) end end)
    taps[2] = sp:install_write_tap(0x1f801814, 0x1f801817, "gp1", function(o, d, m)
      local cmd = (d >> 24) & 0xff
      if on and (cmd == 0x05 or cmd == 0x06 or cmd == 0x07 or cmd == 0x08) then print(string.format("f%d +%.2fms GP1 %02X %06X", f, (cyc()-t0)*1000, cmd, d & 0xffffff)) end end)
    taps[3] = sp:install_read_tap(0x1f801814, 0x1f801817, "stat", function(o, d, m) if on then polls_stat = polls_stat + 1; print(string.format("f%d +%.2fms read GPUSTAT=%08X pc=%08X", f, (cyc()-t0)*1000, d, cpu.state["pc"].value)) end end)
    taps[4] = sp:install_read_tap(0x1f8010a8, 0x1f8010ab, "chcrr", function(o, d, m) if on then polls_chcr = polls_chcr + 1; print(string.format("f%d +%.2fms read DMA2 CHCR=%08X pc=%08X", f, (cyc()-t0)*1000, d, cpu.state["pc"].value)) end end)
  end
  if on then print(string.format("f%d frame end: GPUSTAT reads %d, DMA2 CHCR reads %d", f, polls_stat, polls_chcr)) end
  polls_stat, polls_chcr = 0, 0
  t0 = cyc()
  if f == 1320 then on = true end      -- attract demo fight (mode 2) starts ~f1270 in tekkenac
  if f == 1322 then manager.machine:exit() end
end)
