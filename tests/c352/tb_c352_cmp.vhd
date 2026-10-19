-- Dual-DUT comparison: reference c352 (library orig) vs patched c352 (library work), same MCU writes, same wave-ROM model.
-- Compares the stereo output at the end of every sample period. Usage: see run.sh
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library orig;

entity tb_c352_cmp is
   generic (ROM_LAT : integer := 10; NSAMP : integer := 300);
end entity;

architecture sim of tb_c352_cmp is
   signal clk       : std_logic := '0';
   signal reset     : std_logic := '1';
   signal sample_ce : std_logic := '0';
   signal cs_addr   : std_logic_vector(11 downto 0) := (others => '0');
   signal cs_din    : std_logic_vector(7 downto 0)  := (others => '0');
   signal cs_wr     : std_logic := '0';

   signal a_rom_addr, b_rom_addr : std_logic_vector(23 downto 0);
   signal a_rom_rd, b_rom_rd     : std_logic;
   signal a_rom_data, b_rom_data : std_logic_vector(31 downto 0) := (others => '0');
   signal a_rom_rdy, b_rom_rdy   : std_logic := '0';
   signal a_l, a_r, b_l, b_r     : std_logic_vector(15 downto 0);
   signal a_rd, b_rd             : std_logic_vector(7 downto 0);
   signal a_busy, b_busy         : std_logic_vector(5 downto 0);

   function romword(a : std_logic_vector(23 downto 0)) return std_logic_vector is
      variable x : unsigned(31 downto 0);
   begin
      x := resize(resize(unsigned(a(23 downto 2)), 32) * unsigned'(x"9E3779B1"), 32);
      return std_logic_vector(x xor shift_right(x, 15));
   end function;

   signal mismatches : integer := 0;
   signal rd_mism    : integer := 0;
begin
   clk <= not clk after 5 ns;

   ref : entity orig.c352
      port map (clk => clk, reset => reset, sample_ce => sample_ce, cs_addr => cs_addr, cs_din => cs_din, cs_wr => cs_wr,
                cs_rdata => a_rd, rom_addr => a_rom_addr, rom_rd => a_rom_rd, rom_data => a_rom_data, rom_ready => a_rom_rdy,
                dbg_busy_cnt => a_busy, audio_l => a_l, audio_r => a_r);
   dut : entity work.c352
      port map (clk => clk, reset => reset, sample_ce => sample_ce, cs_addr => cs_addr, cs_din => cs_din, cs_wr => cs_wr,
                cs_rdata => b_rd, rom_addr => b_rom_addr, rom_rd => b_rom_rd, rom_data => b_rom_data, rom_ready => b_rom_rdy,
                dbg_busy_cnt => b_busy, audio_l => b_l, audio_r => b_r);

   -- wave ROM model: ROM_LAT clocks after rom_rd is seen, one-cycle ready pulse with the word
   rom_a : process(clk)
      variable cnt : integer := 0;
   begin
      if rising_edge(clk) then
         a_rom_rdy <= '0';
         if a_rom_rd = '1' and a_rom_rdy = '0' then
            if cnt = ROM_LAT then cnt := 0; a_rom_rdy <= '1'; a_rom_data <= romword(a_rom_addr);
            else cnt := cnt + 1; end if;
         else cnt := 0; end if;
      end if;
   end process;
   rom_b : process(clk)
      variable cnt : integer := 0;
   begin
      if rising_edge(clk) then
         b_rom_rdy <= '0';
         if b_rom_rd = '1' and b_rom_rdy = '0' then
            if cnt = ROM_LAT then cnt := 0; b_rom_rdy <= '1'; b_rom_data <= romword(b_rom_addr);
            else cnt := cnt + 1; end if;
         else cnt := 0; end if;
      end if;
   end process;

   stim : process
      procedure wr(a : integer; d : integer) is
      begin
         wait until rising_edge(clk);
         cs_addr <= std_logic_vector(to_unsigned(a, 12));
         cs_din  <= std_logic_vector(to_unsigned(d, 8));
         cs_wr   <= '1';
         wait until rising_edge(clk);
         cs_wr   <= '0';
         for i in 1 to 3 loop wait until rising_edge(clk); end loop;
      end procedure;
      procedure wr16(a : integer; d : integer) is
      begin
         wr(a, d mod 256); wr(a + 1, (d / 256) mod 256);
      end procedure;
      variable seed : integer := 4321;
      impure function rnd(m : integer) return integer is
      begin
         seed := (seed * 75 + 74) mod 65537;
         return (seed * 7 + seed / 3) mod m;
      end function;
      variable base : integer;
      variable flg  : integer;
   begin
      for i in 1 to 20 loop wait until rising_edge(clk); end loop;
      reset <= '0';
      for i in 1 to 200 loop wait until rising_edge(clk); end loop;
      -- program all 32 voices
      for v in 0 to 31 loop
         base := v * 16;
         wr16(base + 0, 16#4040# + rnd(16#3000#));              -- vol_f  (c0 = hi byte, c1 = lo)
         wr16(base + 2, 16#4040# + rnd(16#3000#));              -- vol_r
         wr16(base + 4, 16#0200# + rnd(16#3800#));              -- freq
         wr16(base + 8, rnd(3));                                -- wave_bank
         wr16(base + 10, rnd(16#2000#));                        -- wave_start
         wr16(base + 12, 16#2400# + rnd(16#1000#));             -- wave_end
         wr16(base + 14, rnd(16#2000#));                        -- wave_loop
         flg := 16#4000# + 2 * rnd(2) + 8 * (rnd(3) / 2);       -- KEYON | LOOP? | MULAW?
         wr16(base + 6, flg);
      end loop;
      wr(16#405#, 0);                                           -- keyon commit
      wait;
   end process;

   tick : process
   begin
      wait until reset = '0';
      for i in 1 to 400 loop wait until rising_edge(clk); end loop;
      for s in 1 to NSAMP loop
         wait until rising_edge(clk);
         sample_ce <= '1';
         wait until rising_edge(clk);
         sample_ce <= '0';
         for i in 1 to 381 loop wait until rising_edge(clk); end loop;
         if a_l /= b_l or a_r /= b_r then
            mismatches <= mismatches + 1;
            if mismatches < 10 then
               report "MISMATCH sample " & integer'image(s) & " ref=" & to_hstring(a_l) & "/" & to_hstring(a_r) &
                      " dut=" & to_hstring(b_l) & "/" & to_hstring(b_r) severity warning;
            end if;
         end if;
         if a_busy /= b_busy then rd_mism <= rd_mism + 1; end if;
      end loop;
      report "DONE samples=" & integer'image(NSAMP) & " mismatches=" & integer'image(mismatches) &
             " busy_mism=" & integer'image(rd_mism) & " ref_last=" & to_hstring(a_l) & "/" & to_hstring(a_r) &
             " busy=" & integer'image(to_integer(unsigned(a_busy)));
      std.env.finish;
   end process;
end architecture;
