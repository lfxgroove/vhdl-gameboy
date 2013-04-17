library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_textio.all;
use ieee.numeric_std.all;

library std;
use std.textio.all;

entity Rom_Test is
end Rom_Test;
  
architecture Behavior of Rom_Test is
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

  component Cpu
    port(Clk, Reset : in std_logic;
         Mem_Write : out std_logic_vector(7 downto 0);
         Mem_Read : in std_logic_vector(7 downto 0);
         Mem_Addr : out std_logic_vector(15 downto 0);
         Mem_Write_Enable : out std_logic);
  end component;
  
  signal Clk, Reset, Bus_Reset : std_logic;
  signal Mem_Write : std_logic_vector(7 downto 0) := X"00";
  signal Mem_Read : std_logic_vector(7 downto 0) := X"00";
  signal Mem_Addr, Cpu_Mem_Addr : std_logic_vector(15 downto 0) := X"0000";
  signal Mem_Write_Enable : std_logic := '0';
  signal Rom_Write_Enable : std_logic := '0';
  signal Rom_Addr : std_logic_vector(15 downto 0);
  signal Rom_Write : std_logic_vector(7 downto 0);
  
  signal Cpu_Allowed : std_logic;
  signal Internal_Mem_Addr : std_logic_vector(15 downto 0);
  
begin
-- compnent instantiation
  Bus_Ports : Bus_Controller port map(
    Clk => Clk,
    Reset => Bus_Reset,
    Mem_Write => Mem_Write,
    Mem_Read => Mem_Read,
    Mem_Addr => Mem_Addr,
    Mem_Write_Enable => Mem_Write_Enable,
    Rom_Write_Enable => Rom_Write_Enable,
    Rom_Addr => Rom_Addr,
    Rom_Write => Rom_Write);

  Cpu_Ports : Cpu port map(
    Clk => Clk,
    Reset => Reset,
    Mem_Write => Mem_Write,
    Mem_Read => Mem_Read,
    Mem_Addr => Cpu_Mem_Addr,
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
  
  Mem_Addr <= Cpu_Mem_Addr when Cpu_Allowed = '1' else
              Internal_Mem_Addr;   
              --Internal_Read_Addr;
  
  Stimuli_Generator : process
    variable In_Line, Out_Line : line;
    variable Curr_Addr : std_logic_vector(15 downto 0) := X"0150";
    variable Data_Byte : std_logic_vector(7 downto 0);
    file In_File : text open read_mode is "roms/rom.txt";
    file Out_File : text open write_mode is "roms/result.txt";
  begin
    Cpu_Allowed <= '1';
  
    Reset <= '1';
    wait for 50 ns;
    
    wait until rising_edge(Clk);  
    
    loop
      exit when endfile(In_File);
      readline(In_File, In_Line);
      read(In_Line, Data_Byte);
      
      wait until rising_edge(Clk);
      
      Rom_Write <= std_logic_vector(Data_Byte(7 downto 0));
      Rom_Addr <= Curr_Addr;
      Curr_Addr := std_logic_vector(unsigned(Curr_Addr) + 1);
      Rom_Write_Enable <= '1';
      
      wait until rising_edge(Clk);
    end loop;
    
    Rom_Write_Enable <= '0';
    wait until rising_edge(Clk);
    
    Reset <= '0';
    wait until rising_edge(Clk);
    
    for I in 1 to 400 loop
      wait until rising_edge(Clk);
    end loop; 

    Cpu_Allowed <= '0';
    wait until rising_edge(Clk);
    
    Curr_Addr := X"C000";
    loop
      exit when Curr_Addr = X"C060";
      --wait until rising_edge(Clk);
      
      Internal_Mem_Addr <= std_logic_vector(Curr_Addr);
      
      wait until rising_edge(Clk);
      wait until rising_edge(Clk);
      
      Data_Byte(7 downto 0) := Mem_Read(7 downto 0);
      Curr_Addr := std_logic_vector(unsigned(Curr_Addr) + 1);

      --wait until rising_edge(Clk);
      
      write(Out_Line, Data_Byte);
      writeline(Out_File, Out_Line);
    end  loop;        
    wait;      
  end process;
  
end Behavior;
