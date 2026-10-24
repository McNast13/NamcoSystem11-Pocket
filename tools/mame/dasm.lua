local f = 0
emu.register_frame_done(function()
  f = f + 1
  if f == 60*20 then
    local d = manager.machine.debugger
    d:command("focus maincpu")
    d:command("dasm " .. os.getenv("OUTD") .. "/fn.asm,8002DB80,100")
    d:command("dasm " .. os.getenv("OUTD") .. "/fn2.asm,8002DB00,32")
  end
  if f == 60*20+5 then manager.machine:exit() end
end)
