library ieee;
use ieee.std_logic_1164.all;

entity Cpu_Testbench is
end Cpu_Testbench;

architecture Behavior of Cpu_Testbench is
-- Component Decalaration
  component Cpu
  port(Clk, Reset : in std_logic;
       Mem_Write : out std_logic_vector(7 downto 0);
       Mem_Read : in std_logic_vector(7 downto 0);
       Mem_Addr : out std_logic_vector(15 downto 0);
       Mem_Write_Enable : out std_logic);
  end component;
  signal Clk, Reset : std_logic;
  signal Mem_Write : std_logic_vector(7 downto 0);
  signal Mem_Read : std_logic_vector(7 downto 0);
  signal Mem_Addr : std_logic_vector(15 downto 0);
  signal Mem_Write_Enable : std_logic;
  
begin
-- compnent instantiation
  Cpu_Ports : Cpu port map(
    Clk => Clk,
    Reset => Reset,
    Mem_Write => Mem_Write,
    Mem_Read => Mem_Read,
    Mem_Addr => Mem_Addr,
    Mem_Write_Enable => Mem_Write_Enable);

  Clk_Gen : process
  begin
    while (true) loop
      Clk <= '0';
      wait for 5 ns;
      Clk <= '1';
      wait for 5 ns;
    end loop;
  end process;

  Stimuli_Generator : process

  begin
    Reset <= '1';
    wait for 500 ns;

    wait until rising_edge(Clk);
    Reset <= '0';

    Mem_Read <= X"78";
    wait;      
  end process;
  
end Behavior;
