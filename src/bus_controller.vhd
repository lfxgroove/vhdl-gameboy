library ieee;
use ieee.std_logic_1164.all;
use IEEE.numeric_std.all;

-- This is the bus controller, which abstracts the memory
-- map seen from the CPU. The bus controller also contains
-- the main RAM of the GB.
-- See page 14 in the gb-programming-manual for the memory
-- layout.

entity Bus_Controller is
  port (Clk, Reset : in std_logic;
        Mem_Write : in std_logic_vector(7 downto 0);
        Mem_Read : out std_logic_vector(7 downto 0);
        Mem_Addr : in std_logic_vector(15 downto 0);
        Mem_Write_Enable : in std_logic;
        -- These three signals writes to the large rom.
        -- Note: The addresses 0x0..0x14F can be written to here
        -- but they cannot be read back later. This should be fixed
        -- in the "real" implementation of the rom.
        Rom_Write_Enable : in std_logic;
        Rom_Addr : in std_logic_vector(15 downto 0);
        Rom_Write : in std_logic_vector(7 downto 0));
end Bus_Controller;


architecture Bus_Controller_Behaviour of Bus_Controller is
  type Ram_8KType is array (0 to 8192) of std_logic_vector(7 downto 0);
  type Ram_127Type is array (0 to 126) of std_logic_vector(7 downto 0); 

  signal External_Ram : Ram_8KType := (others => X"00");
  signal Internal_Ram : Ram_8KType := (others => X"00");
  signal Stack_Ram : Ram_127Type := (others => X"00");

  -- TODO: Replace this with the larger external memory!
  signal Rom_Memory : Ram_8KType := (others => X"00");
begin

  -- Writing to the rom
  process (Clk)
  begin
    if rising_edge(Clk) then
      if Rom_Write_Enable = '1' then
        Rom_Memory(to_integer(unsigned(Rom_Addr))) <= Rom_Write;
      end if;
    end if;
  end process;

  process (Clk)
  begin
    if rising_edge(Clk) then
      if Mem_Addr < X"0100" then
        -- Interrupt address
        -- RST address
        -- Not implemented yet
        Mem_Read <= X"00";
      elsif Mem_Addr < X"0150" then
        -- ROM Data area, Nintendo's ROM.
        -- Not implemented yet
        Mem_Read <= X"00";
      elsif Mem_Addr < X"8000" then
        -- User program area. The ROM inserted into the unit.
        -- This implementation only supports the first 8K of the user program area.
        -- Replace with better implementation later.
        Mem_Read <= Rom_Memory(to_integer(unsigned(Mem_Addr(12 downto 0))));
      elsif Mem_Addr < X"9800" then
        -- Character data. Send to GPU.
        Mem_Read <= X"00";
      elsif Mem_Addr < X"9C00" then
        -- Character codes (BG data 1). Send to GPU.
        Mem_Read <= X"00";
      elsif Mem_Addr < X"A000" then
        -- Character codes (BG data 2). Send to GPU.
        Mem_Read <= X"00";
      elsif Mem_Addr < X"C000" then
        -- External expansion working RAM 8KB.
        if Mem_Write_Enable = '1' then
          External_Ram(to_integer(unsigned(Mem_Addr(12 downto 0)))) <= Mem_Write;
        else
          Mem_Read <= External_Ram(to_integer(unsigned(Mem_Addr(12 downto 0))));
        end if;
      elsif Mem_Addr < X"E000" then
        -- Unit working ram 8KB.
        if Mem_Write_Enable = '1' then
          Internal_Ram(to_integer(unsigned(Mem_Addr(12 downto 0)))) <= Mem_Write;
        else
          Mem_Read <= Internal_Ram(to_integer(unsigned(Mem_Addr(12 downto 0))));
        end if;
      elsif Mem_Addr < X"FE00" then
        -- Prohibited. Undefined value!
      elsif Mem_Addr < X"FEA0" then
        -- OAM memory, send to GPU.
        Mem_Read <= X"00";
      elsif Mem_Addr < X"FF00" then
        -- Prohibited. Undefined value!
      elsif Mem_Addr < X"FF80" then
        -- Port mode registers (input).
        -- Control registers.
        -- Sound register.
        Mem_Read <= X"00";
      elsif Mem_Addr < X"FFFE" then
        -- Working stack and RAM.
        if Mem_Write_Enable = '1' then
          External_Ram(to_integer(unsigned(Mem_Addr(6 downto 0)))) <= Mem_Write;
        else
          Mem_Read <= External_Ram(to_integer(unsigned(Mem_Addr(6 downto 0))));
        end if;
      else
        -- Undefined.
      end if;
    end if;
  end process;  
end Bus_Controller_Behaviour;
