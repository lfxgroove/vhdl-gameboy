library ieee;
use ieee.std_logic_1164.all;

entity Cpu is
  port(Clk, Reset : in std_logic;
       Mem_Write : out std_logic_vector(7 downto 0);
       Mem_Read : in std_logic_vector(7 downto 0);
       Mem_Addr : out std_logic_vector(15 downto 0);
       Mem_Write_Enable : out std_logic);
end Cpu;

architecture Cpu_Implementation of Cpu is
  -- General purpose registers
  signal A, B, C, D, E, F, H, L : std_logic_vector(7 downto 0);
  -- Status register
  signal SR : std_logic_vector(7 downto 0);
  -- Stack pointer and program counter
  signal SP, PC : std_logic_vector(15 downto 0);
  
  
begin
  -- 
  process(Clk)
  begin

  end process;
    

end Cpu_Implementation;
