-- Behavioural stand-in for the Altera altsyncram dpram wrapper (nvc has no altera_mf). Registered read on both ports, port-A/B write.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity dpram is
   generic (addr_width : integer := 8; data_width : integer := 8);
   port (
      clock_a : in std_logic; clken_a : in std_logic := '1';
      address_a : in std_logic_vector(addr_width-1 downto 0); data_a : in std_logic_vector(data_width-1 downto 0);
      wren_a : in std_logic := '0'; q_a : out std_logic_vector(data_width-1 downto 0);
      clock_b : in std_logic; clken_b : in std_logic := '1';
      address_b : in std_logic_vector(addr_width-1 downto 0); data_b : in std_logic_vector(data_width-1 downto 0) := (others => '0');
      wren_b : in std_logic := '0'; q_b : out std_logic_vector(data_width-1 downto 0));
end entity;

architecture sim of dpram is
   type mem_t is array(0 to 2**addr_width-1) of std_logic_vector(data_width-1 downto 0);
   shared variable mem : mem_t := (others => (others => '0'));
begin
   pa : process(clock_a)
   begin
      if rising_edge(clock_a) then
         if clken_a = '1' then
            if wren_a = '1' then mem(to_integer(unsigned(address_a))) := data_a; end if;
            q_a <= mem(to_integer(unsigned(address_a)));
         end if;
      end if;
   end process;
   pb : process(clock_b)
   begin
      if rising_edge(clock_b) then
         if clken_b = '1' then
            if wren_b = '1' then mem(to_integer(unsigned(address_b))) := data_b; end if;
            q_b <= mem(to_integer(unsigned(address_b)));
         end if;
      end if;
   end process;
end architecture;
