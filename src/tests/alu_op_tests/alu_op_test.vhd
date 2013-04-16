library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_textio.all;
use ieee.numeric_std.all;

library std;
use std.textio.all;

entity Sample_Test is
end Sample_Test;
  
architecture Behavior of Sample_Test is
-- Component Decalaration
  component Cpu
  port(Clk, Reset : in std_logic;
       Mem_Write : out std_logic_vector(7 downto 0);
       Mem_Read : in std_logic_vector(7 downto 0);
       Mem_Addr : out std_logic_vector(15 downto 0);
       Mem_Write_Enable : out std_logic);
  end component;

  component Bus_Controller
    port(Clk, Reset : in std_logic;
         Rom_Write_Enable : in std_logic;
         Rom_Addr : in std_logic_vector(15 downto 0);
         Rom_Write : in std_logic_vector(7 downto 0);
         --These are unused but needed to be bound/connected
         Mem_Write : in std_logic_vector(7 downto 0);
         Mem_Addr : in std_logic_vector(15 downto 0);
         Mem_Read : out std_logic_vector(7 downto 0);
         Mem_Write_Enable : in std_logic);
  end component;    
  
  signal Clk, Reset, Bus_Reset : std_logic;
  signal Mem_Write : std_logic_vector(7 downto 0);
  signal Mem_Read : std_logic_vector(7 downto 0);
  signal Mem_Addr : std_logic_vector(15 downto 0);
  signal Mem_Write_Enable : std_logic;
  signal Rom_Write_Enable : std_logic;
  signal Rom_Addr : std_logic_vector(15 downto 0);
  signal Rom_Write : std_logic_vector(7 downto 0);
  
  signal Bus_Mem_Write : std_logic_vector(7 downto 0);
  signal Bus_Mem_Addr : std_logic_vector(15 downto 0);
  signal Bus_Mem_Read : std_logic_vector(7 downto 0);
  signal Bus_Mem_Write_Enable : std_logic;
  
begin
-- compnent instantiation
  Cpu_Ports : Cpu port map(
    Clk => Clk,
    Reset => Reset,
    Mem_Write => Mem_Write,
    Mem_Read => Mem_Read,
    Mem_Addr => Mem_Addr,
    Mem_Write_Enable => Mem_Write_Enable);
  
  Rom_Port : Bus_Controller port map (
    Clk => Clk,
    Reset => Bus_Reset,
    Rom_Write_Enable => Rom_Write_Enable,
    Rom_Addr => Rom_Addr,
    Rom_Write => Rom_Write,
    --These are unused but needed to be bound/connected
    Mem_Read => Bus_Mem_Read,
    Mem_Write => Bus_Mem_Write,
    Mem_Addr => Bus_Mem_Addr,
    Mem_Write_Enable => Bus_Mem_Write_Enable);
  
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
    variable In_Line, Out_Line : line;
    variable Curr_Addr : std_logic_vector(15 downto 0) := X"0150";
    variable Data_Byte : std_logic_vector(7 downto 0);
    file In_File : text open read_mode is "tests/sample_test/stimulus/feed.txt";
    file Out_File : text open write_mode is "tests/sample_test/results/results.txt";
  begin
  --writes one byte at a time to the memory
    --The following line gives this warning:
    --(assertion warning): NUMERIC_STD.TO_INTEGER: metavalue detected, returning 0
    Rom_Write_Enable <= '1';
    Reset <= '1';
    Bus_Reset <= '1';
    wait for 500 ns;
    Bus_Reset <= '0';
    
    loop
      exit when endfile(In_File);
      readline(In_File, In_Line);
      read(In_Line, Data_Byte);
      
      Rom_Addr <= Curr_Addr;
      Rom_Write(7 downto 0) <= std_logic_vector(Data_Byte(7 downto 0));
      Curr_Addr := std_logic_vector(unsigned(Curr_Addr) + 1);
      
      wait until rising_edge(Clk);
    end loop;
    Rom_Write_Enable <= '0';
    
    Reset <= '1';
    wait for 100 ns;
    Reset <= '0';
    for I in 1 to 300 loop
      wait until rising_edge(clk);
    end loop; 
    
    Curr_Addr := X"0150";
    loop
      exit when Curr_Addr = X"0200";
      Bus_Mem_Write_Enable <= '0';
      Bus_Mem_Addr <= Curr_Addr;
      Data_Byte(7 downto 0) := Bus_Mem_Read(7 downto 0);
      Curr_Addr := std_logic_vector(unsigned(Curr_Addr) + 1);
      write(Out_Line, Data_Byte);
      writeline(Out_File, Out_Line);
    end  loop;        
    wait;      
  end process;
  
end Behavior;
