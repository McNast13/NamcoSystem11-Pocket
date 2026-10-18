-- Probe-only stub of the PSX MDEC (same ports). Reports "idle, output FIFO empty" and
-- never requests DMA, so FMV decoding does nothing. Used to measure area saved.
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
   dmaWriteRequest <= '0';
   dmaReadRequest  <= '0';
   dma_readdata    <= (others => '0');
   SS_DataRead     <= (others => '0');
   SS_Idle         <= '1';
end architecture;
