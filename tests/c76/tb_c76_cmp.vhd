-- Dual-DUT comparison: reference c76 (+m37702) in library orig vs patched c76 in library work, same BIOS, same external-bus model, same IRQ stimulus.
-- The BIOS is streamed in from a hex file (one byte per line, 16384 lines). Compares the external bus and dbg_pc every clock.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
library orig;

entity tb_c76_cmp is
   generic (NCLK : integer := 3000000; BIOS : string := "bios.hex"; SPROG : string := "sprog.hex"; SP_MODE : integer := 0; SP_LAT : integer := 0);
end entity;

architecture sim of tb_c76_cmp is
   signal clk   : std_logic := '0';
   signal reset : std_logic := '1';
   signal ce    : std_logic := '0';
   signal bios_wr : std_logic := '0';
   signal bios_addr : std_logic_vector(13 downto 0) := (others => '0');
   signal bios_din  : std_logic_vector(7 downto 0) := (others => '0');
   signal irq0, irq2 : std_logic := '0';

   signal a_addr, b_addr : std_logic_vector(23 downto 0);
   signal a_dout, b_dout : std_logic_vector(7 downto 0);
   signal a_din, b_din   : std_logic_vector(7 downto 0) := (others => '0');
   signal a_rd, b_rd, a_wr, b_wr : std_logic;
   signal a_rdy, b_rdy   : std_logic := '0';
   signal a_pc, b_pc     : std_logic_vector(23 downto 0);
   signal a_op, b_op     : std_logic_vector(7 downto 0);
   signal a_val, b_val, a_hlt, b_hlt : std_logic;
   signal a_x, b_x       : std_logic_vector(15 downto 0);
   signal a_r80, b_r80, a_r83, b_r83 : std_logic_vector(7 downto 0);

   type sp_t is array(0 to 262143) of std_logic_vector(7 downto 0);
   impure function load_sprog return sp_t is
      file f : text open read_mode is SPROG;
      variable l : line; variable v : std_logic_vector(7 downto 0); variable m : sp_t := (others => x"FF"); variable i : integer := 0;
   begin
      while not endfile(f) and i < 262144 loop readline(f, l); hread(l, v); m(i) := v; i := i + 1; end loop;
      return m;
   end function;
   constant sprog_rom : sp_t := load_sprog;
   type shr_t is array(0 to 32767) of std_logic_vector(7 downto 0);

   -- external bus as the System 11 substrate decodes it: inputs 0x1000-7 (idle 0xFF), C352 0x2000-0x2FFF (reads 0), shared RAM 0x4000-0xBFFF (plain RAM),
   -- SPROG 0x080000-0x0FFFFF / 0x200000-0x2FFFFF (offset = addr(18:0), rom image repeats), anything else 0xFF
   function ext_rd_data(a : std_logic_vector(23 downto 0); shr : shr_t) return std_logic_vector is
      variable ua : unsigned(23 downto 0) := unsigned(a);
   begin
      if ua >= x"001000" and ua <= x"001007" then return x"FF";
      elsif ua >= x"002000" and ua <= x"002FFF" then return x"00";
      elsif ua >= x"004000" and ua <= x"00BFFF" then return shr(to_integer(ua) - 16#4000#);
      elsif (ua >= x"080000" and ua <= x"0FFFFF") or (ua >= x"200000" and ua <= x"2FFFFF") then
         if SP_MODE = 1 then return x"00";
         elsif SP_MODE = 2 then return x"FF";
         elsif SP_MODE = 3 then return std_logic_vector(ua(7 downto 0));
         else return sprog_rom(to_integer(ua(17 downto 0))); end if;
      else return x"FF"; end if;
   end function;

   function extword(a : std_logic_vector(23 downto 0)) return std_logic_vector is
      variable x : unsigned(31 downto 0);
   begin
      x := resize(resize(unsigned(a), 32) * unsigned'(x"9E3779B1"), 32);
      return std_logic_vector(x(23 downto 16) xor x(7 downto 0));
   end function;

   signal mismatches : integer := 0;
begin
   clk <= not clk after 5 ns;

   ref : entity orig.c76
      port map (clk => clk, ce => ce, reset => reset, bios_wr => bios_wr, bios_addr => bios_addr, bios_din => bios_din,
                irq0 => irq0, irq1 => '0', irq2 => irq2,
                ext_addr => a_addr, ext_dout => a_dout, ext_din => a_din, ext_rd => a_rd, ext_wr => a_wr, ext_ready => a_rdy,
                dbg_pc => a_pc, dbg_opcode => a_op, dbg_valid => a_val, dbg_halted => a_hlt, dbg_x => a_x, dbg_ram80 => a_r80, dbg_ram83 => a_r83);
   dut : entity work.c76
      port map (clk => clk, ce => ce, reset => reset, bios_wr => bios_wr, bios_addr => bios_addr, bios_din => bios_din,
                irq0 => irq0, irq1 => '0', irq2 => irq2,
                ext_addr => b_addr, ext_dout => b_dout, ext_din => b_din, ext_rd => b_rd, ext_wr => b_wr, ext_ready => b_rdy,
                dbg_pc => b_pc, dbg_opcode => b_op, dbg_valid => b_val, dbg_halted => b_hlt, dbg_x => b_x, dbg_ram80 => b_r80, dbg_ram83 => b_r83);

   -- external bus model: ready one clock after rd/wr is first seen, data = hash of address (deterministic, same for both)
   ext_a : process(clk)
      variable shr : shr_t := (others => x"00");
      variable lat : integer := 0;
      variable is_sp : boolean;
   begin
      if rising_edge(clk) then
         a_rdy <= '0';
         is_sp := (unsigned(a_addr) >= x"080000" and unsigned(a_addr) <= x"0FFFFF") or (unsigned(a_addr) >= x"200000" and unsigned(a_addr) <= x"2FFFFF");
         if a_rd = '1' and a_rdy = '0' and is_sp and lat < SP_LAT then
            lat := lat + 1;
         elsif (a_rd = '1' or a_wr = '1') and a_rdy = '0' then
            lat := 0;
            a_rdy <= '1';
            a_din <= ext_rd_data(a_addr, shr);
            if a_wr = '1' and unsigned(a_addr) >= x"004000" and unsigned(a_addr) <= x"00BFFF" then
               shr(to_integer(unsigned(a_addr)) - 16#4000#) := a_dout;
            end if;
         end if;
      end if;
   end process;
   ext_b : process(clk)
      variable shr : shr_t := (others => x"00");
      variable lat : integer := 0;
      variable is_sp : boolean;
   begin
      if rising_edge(clk) then
         b_rdy <= '0';
         is_sp := (unsigned(b_addr) >= x"080000" and unsigned(b_addr) <= x"0FFFFF") or (unsigned(b_addr) >= x"200000" and unsigned(b_addr) <= x"2FFFFF");
         if b_rd = '1' and b_rdy = '0' and is_sp and lat < SP_LAT then
            lat := lat + 1;
         elsif (b_rd = '1' or b_wr = '1') and b_rdy = '0' then
            lat := 0;
            b_rdy <= '1';
            b_din <= ext_rd_data(b_addr, shr);
            if b_wr = '1' and unsigned(b_addr) >= x"004000" and unsigned(b_addr) <= x"00BFFF" then
               shr(to_integer(unsigned(b_addr)) - 16#4000#) := b_dout;
            end if;
         end if;
      end if;
   end process;

   stim : process
      file f : text;
      variable l : line;
      variable v : std_logic_vector(7 downto 0);
      variable hv : integer;
      variable n : integer := 0;
      variable last_mile : std_logic_vector(23 downto 0) := (others => '0');
      variable cmp_n : integer := 0;
      variable a_c279, b_c279, a_c31f, b_c31f, a_tog, b_tog : integer := 0;
      variable la83, lb83 : std_logic_vector(7 downto 0) := (others => '0');
      variable first_mm : boolean := true;
   begin
      -- load BIOS during reset
      file_open(f, BIOS, read_mode);
      wait until rising_edge(clk);
      while not endfile(f) loop
         readline(f, l);
         hread(l, v);
         bios_wr <= '1'; bios_addr <= std_logic_vector(to_unsigned(n, 14)); bios_din <= v;
         n := n + 1;
         wait until rising_edge(clk);
      end loop;
      bios_wr <= '0';
      file_close(f);
      for i in 1 to 10 loop wait until rising_edge(clk); end loop;
      reset <= '0';

      for c in 1 to NCLK loop
         wait until rising_edge(clk);
         if c mod 2 = 0 then ce <= '1'; else ce <= '0'; end if;   -- C76 ce = clk_1x/2 as in SYSTEM11.sv
         if c mod 100000 = 0 then irq0 <= '1'; irq2 <= '0'; else irq0 <= '0'; end if;   -- slow external INT0 pulse
         if c mod 100000 = 50000 then irq2 <= '1'; else irq2 <= '0'; end if;
         wait for 1 ns;
         if reset = '0' then
            cmp_n := cmp_n + 1;
            if c mod 200000 = 0 then report "t=" & integer'image(c) & " ref pc=" & to_hstring(a_pc) & " dut pc=" & to_hstring(b_pc) & " ram83 ref/dut=" & to_hstring(a_r83) & "/" & to_hstring(b_r83); end if;
            if (a_addr /= b_addr or a_rd /= b_rd or a_wr /= b_wr or (a_wr = '1' and a_dout /= b_dout) or a_pc /= b_pc) and first_mm then
               first_mm := false;
               report "FIRST MISMATCH clk " & integer'image(c) & " ref pc=" & to_hstring(a_pc) & " dut pc=" & to_hstring(b_pc) &
                      " ref addr=" & to_hstring(a_addr) & " dut addr=" & to_hstring(b_addr) & " rd/wr ref=" & std_logic'image(a_rd) & std_logic'image(a_wr) &
                      " dut=" & std_logic'image(b_rd) & std_logic'image(b_wr) severity warning;
            end if;
            if a_pc /= b_pc then mismatches <= mismatches + 1; end if;
            if (a_pc = x"00C098" or a_pc = x"00C151" or a_pc = x"00C1BD" or a_pc = x"00C279" or a_pc = x"00C31F") and a_pc /= last_mile then
               last_mile := a_pc; report "milestone ref pc=" & to_hstring(a_pc) & " at clk " & integer'image(c);
            end if;
            if a_pc = x"00C279" then a_c279 := a_c279 + 1; end if;
            if b_pc = x"00C279" then b_c279 := b_c279 + 1; end if;
            if a_pc = x"00C31F" then a_c31f := a_c31f + 1; end if;
            if b_pc = x"00C31F" then b_c31f := b_c31f + 1; end if;
            if a_r83 /= la83 then a_tog := a_tog + 1; la83 := a_r83; end if;
            if b_r83 /= lb83 then b_tog := b_tog + 1; lb83 := b_r83; end if;
         end if;
      end loop;
      report "DONE compared " & integer'image(cmp_n) & " clocks; pc mismatches=" & integer'image(mismatches) &
             " | ref final pc=" & to_hstring(a_pc) & " dut final pc=" & to_hstring(b_pc) &
             " | TB0-ISR@C279 ref/dut=" & integer'image(a_c279) & "/" & integer'image(b_c279) &
             " mailbox-ISR@C31F ref/dut=" & integer'image(a_c31f) & "/" & integer'image(b_c31f) &
             " ram83 toggles ref/dut=" & integer'image(a_tog) & "/" & integer'image(b_tog);
      std.env.stop;
   end process;
end architecture;
