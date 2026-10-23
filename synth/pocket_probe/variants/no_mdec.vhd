-- Stand-in for the PSX MDEC when it does not fit (S11_NO_MDEC=1; same ports, ~600 ALMs saved). It decodes nothing but keeps both
-- MDEC DMA channels flowing: input words are accepted and dropped, output words read as 0, so a movie plays as black frames and
-- ends on time. The first version never requested DMA, so the game's movie player waited forever on the transfers: Tekken (tekkenac)
-- then sat in a state MAME never enters (game state 0x80264880 = 00020001, intro movie is 00010001) and ignored Start although
-- coins, credits and the Start flag were all right (probes 9-13). MAME shows the game never reads the MDEC registers during a movie,
-- only the DMA. Channels 3 and 6 in dma.vhd already hold their request at '1' the same way.
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity mdec is
   port
   (
      clk1x, clk2x, clk2xIndex, ce, reset : in std_logic;
      bus_addr        : in  unsigned(3 downto 0);
      bus_dataWrite   : in  std_logic_vector(31 downto 0);
      bus_read        : in  std_logic;
      bus_write       : in  std_logic;
      bus_dataRead    : out std_logic_vector(31 downto 0);
      dmaWriteRequest : out std_logic;
      dmaReadRequest  : out std_logic;
      dma_write       : in  std_logic;
      dma_writedata   : in  std_logic_vector(31 downto 0);
      dma_read        : in  std_logic;
      dma_readdata    : out std_logic_vector(31 downto 0);
      SS_reset        : in  std_logic;
      SS_DataWrite    : in  std_logic_vector(31 downto 0);
      SS_Adr          : in  unsigned(6 downto 0);
      SS_wren         : in  std_logic;
      SS_rden         : in  std_logic;
      SS_DataRead     : out std_logic_vector(31 downto 0);
      SS_Idle         : out std_logic
   );
end entity;

architecture arch of mdec is
begin
   bus_dataRead    <= x"80000000";
   dmaWriteRequest <= '1';   -- always ready for input (dropped)
   dmaReadRequest  <= '1';   -- always has output (zeros)
   dma_readdata    <= (others => '0');
   SS_DataRead     <= (others => '0');
   SS_Idle         <= '1';
end architecture;
