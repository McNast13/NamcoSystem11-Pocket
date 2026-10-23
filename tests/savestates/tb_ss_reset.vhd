-- Reset-only savestates sequencer (savestates_reset_only.apply) with idealized handshakes: checks that a falling reset_in
-- produces an ss_reset pulse, holds reset_out through the scratchpad/SPU RAM/VRAM/main-RAM clear and then releases it.
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_ss_reset is
end entity;

architecture sim of tb_ss_reset is
   signal clk1x          : std_logic := '0';
   signal clk2x          : std_logic := '1';   -- rising edges aligned with clk1x (one PLL on the device)
   signal clk2xIndex     : std_logic := '0';
   signal clk1xToggle, clk1xToggle2x : std_logic := '0';
   signal reset_in       : std_logic := '1';
   signal reset_out, ss_reset, savestate_pause, ddr3_savestate : std_logic;
   signal paused         : std_logic := '0';
   signal ddr3_WE, ddr3_RD : std_logic;
   signal ddr3_ready     : std_logic := '0';
   signal SS_wren, SS_rden : std_logic_vector(16 downto 0);
   signal sdram_done     : std_logic := '0';
   signal spu_req        : std_logic;
   signal spu_done       : std_logic := '0';
   signal done           : boolean := false;
begin
   clk1x <= not clk1x after 14.75 ns when not done;
   clk2x <= not clk2x after 7.375 ns when not done;

   dut : entity work.savestates
   generic map (FASTSIM => '0', Softmap_SaveState_ADDR => 58720256)
   port map (
      clk1x => clk1x, clk2x => clk2x, clk2xIndex => clk2xIndex, ce => '1',
      reset_in => reset_in, reset_out => reset_out, ss_reset => ss_reset,
      hps_busy => '0', loadExe => '0', load_done => open, validSStates => open,
      savestate_number => 0, increaseSSHeaderCount => '0', save => '0', load => '0', savestate_address => 0, savestate_busy => open,
      SS_idle => '1', system_paused => paused, savestate_pause => savestate_pause, ddr3_savestate => ddr3_savestate,
      useSPUSDRAM => '0',
      SS_DataWrite => open, SS_Adr => open, SS_wren => SS_wren, SS_rden => SS_rden,
      sdram_done => sdram_done, loading_savestate => open, saving_savestate => open,
      ddr3_BUSY => '0', ddr3_DOUT => (others => '0'), ddr3_DOUT_READY => ddr3_ready,
      ddr3_BURSTCNT => open, ddr3_ADDR => open, ddr3_DIN => open, ddr3_BE => open, ddr3_WE => ddr3_WE, ddr3_RD => ddr3_RD,
      ram_done => '0', ram_data => (others => '0'),
      SS_SPURAM_dataWrite => open, SS_SPURAM_Adr => open, SS_SPURAM_request => spu_req, SS_SPURAM_rnw => open,
      SS_SPURAM_dataRead => (others => '0'), SS_SPURAM_done => spu_done);

   spu_done <= spu_req;   -- as psx_top.vhd with the SPU stub: SS_SPURAM_done <= SS_SPURAM_request

   -- clk2xIndex exactly as psx_top.vhd generates it
   process (clk1x)
   begin
      if rising_edge(clk1x) then clk1xToggle <= not clk1xToggle; end if;
   end process;
   process (clk2x)
   begin
      if rising_edge(clk2x) then
         clk1xToggle2x <= clk1xToggle;
         clk2xIndex    <= '0';
         if (clk1xToggle2x = clk1xToggle) then clk2xIndex <= '1'; end if;
      end if;
   end process;

   -- idealized system: pauses one clock after asked, SDRAM writes complete next clock (clk1x, like memorymux),
   -- ddr3 reads answer three clk2x cycles after the request (clk2x, like the VRAM port), never busy
   process (clk1x)
   begin
      if rising_edge(clk1x) then
         paused     <= savestate_pause;
         sdram_done <= SS_wren(16);
      end if;
   end process;
   process (clk2x)
      variable rd_d : std_logic_vector(2 downto 0) := "000";
   begin
      if rising_edge(clk2x) then
         ddr3_ready <= rd_d(2);
         rd_d       := rd_d(1 downto 0) & ddr3_RD;
      end if;
   end process;

   -- reset_out and ss_reset are one-clock pulses; the system is held by savestate_pause while the memories are cleared, and a last
   -- reset_out pulse follows the clear. Run until the pause has ended and a reset pulse came after it.
   process
      variable n, ss_pulses, rst_pulses, last_ss, last_rst, pause_on, pause_off : integer := 0;
      variable wr_ram, wr_vram, wr_spu, wr_scp : integer := 0;
   begin
      wait for 1 us;
      wait until rising_edge(clk1x);
      reset_in <= '0';
      for i in 0 to 20_000_000 loop
         wait until rising_edge(clk1x);
         n := n + 1;
         if ss_reset = '1' then ss_pulses := ss_pulses + 1; last_ss := n; end if;
         if reset_out = '1' then rst_pulses := rst_pulses + 1; last_rst := n; end if;
         if savestate_pause = '1' and pause_on = 0 then pause_on := n; end if;
         if savestate_pause = '0' and pause_on /= 0 and pause_off = 0 then pause_off := n; end if;
         if SS_wren(16) = '1' then wr_ram := wr_ram + 1; end if;
         if SS_wren(12) = '1' then wr_scp := wr_scp + 1; end if;
         if ddr3_WE = '1' and ddr3_savestate = '1' then wr_vram := wr_vram + 1; end if;
         if spu_req = '1' then wr_spu := wr_spu + 1; end if;
         exit when pause_off /= 0 and last_rst >= pause_off - 2 and n > pause_off + 1000;
      end loop;
      report "clk " & integer'image(n) & ": ss_reset pulses=" & integer'image(ss_pulses) & " (last " & integer'image(last_ss) &
             "), reset_out pulses=" & integer'image(rst_pulses) & " (last " & integer'image(last_rst) &
             "), pause " & integer'image(pause_on) & ".." & integer'image(pause_off) &
             ", writes: scratchpad " & integer'image(wr_scp) & " SPU " & integer'image(wr_spu) &
             " VRAM " & integer'image(wr_vram) & " RAM " & integer'image(wr_ram);
      assert ss_pulses >= 1 report "FAIL: ss_reset never pulsed" severity failure;
      assert pause_off /= 0 report "FAIL: sequencer never finished (pause not released)" severity failure;
      assert last_ss < last_rst report "FAIL: no reset_out pulse after the last ss_reset" severity failure;
      assert last_rst >= pause_off - 2 report "FAIL: no reset_out pulse at the end of the clear" severity failure;
      report "PASS";
      done <= true;
      wait;
   end process;
end architecture;
