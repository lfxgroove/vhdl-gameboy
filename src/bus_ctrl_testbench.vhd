library ieee;
use ieee.std_logic_1164.all;

entity Bus_Test is
end Bus_Test;

architecture Behavior_Bus of Bus_Test is
-- Component Decalaration
  component Bus_Controller
  port(Clk, Reset : in std_logic;
       Mem_Write : in std_logic_vector(7 downto 0);
       Mem_Read : out std_logic_vector(7 downto 0);
       Mem_Addr : in std_logic_vector(15 downto 0);
       Mem_Write_Enable : in std_logic;
       Rom_Write_Enable : in std_logic;
       Rom_Addr : in std_logic_vector(15 downto 0);
       Rom_Write : in std_logic_vector(7 downto 0));

  end component;
  signal Clk, Reset : std_logic;
  signal Mem_Write : std_logic_vector(7 downto 0) := X"00";
  signal Mem_Read : std_logic_vector(7 downto 0) := X"00";
  signal Mem_Addr : std_logic_vector(15 downto 0) := X"0000";
  signal Mem_Write_Enable : std_logic := '0';
  signal Rom_Write_Enable : std_logic := '0';
  signal Rom_Addr : std_logic_vector(15 downto 0);
  signal Rom_Write : std_logic_vector(7 downto 0);

  
begin
-- compnent instantiation
  Bus_Ports : Bus_Controller port map(
    Clk => Clk,
    Reset => Reset,
    Mem_Write => Mem_Write,
    Mem_Read => Mem_Read,
    Mem_Addr => Mem_Addr,
    Mem_Write_Enable => Mem_Write_Enable,
    Rom_Write_Enable => Rom_Write_Enable,
    Rom_Addr => Rom_Addr,
    Rom_Write => Rom_Write);

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
    wait for 50 ns;

    wait until rising_edge(Clk);
    Reset <= '0';


    Rom_Write <= X"FF";
    Rom_Write_Enable <= '1';
    Rom_Addr <= X"0150";
    Mem_Addr <= X"0150";
    wait until rising_edge(Clk);

    Rom_Write_Enable <= '0';
    wait until rising_edge(Clk);
    wait until rising_edge(Clk);
    wait until rising_edge(Clk);

    Mem_Addr <= X"C000";
    wait until rising_edge(Clk);
    Mem_Write_Enable <= '1';
    Mem_Write <= X"FE";
    wait until rising_edge(Clk);
    Mem_Write_Enable <= '0';

    wait until rising_edge(Clk);
    wait until rising_edge(Clk);

  end process;
  
end Behavior_Bus;

