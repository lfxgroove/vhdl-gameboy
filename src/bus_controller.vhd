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
        -- Output to the GPU
        Gpu_Write : out std_logic_vector(7 downto 0);
        Gpu_Read : in std_logic_vector(7 downto 0);
        Gpu_Addr : out std_logic_vector(15 downto 0);
        Gpu_Write_Enable : out std_logic;
        -- These three signals writes to the large rom.
        Rom_Write_Enable : in std_logic;
        Rom_Addr : in std_logic_vector(15 downto 0);
        Rom_Write : in std_logic_vector(7 downto 0));
end Bus_Controller;


architecture Bus_Controller_Behaviour of Bus_Controller is
  type Ram_8KType is array (0 to 8191) of std_logic_vector(7 downto 0);
  type Ram_127Type is array (0 to 126) of std_logic_vector(7 downto 0);
  type Rom_32KType is array (0 to 32767) of std_logic_vector(7 downto 0);

  signal External_Ram : Ram_8KType := (others => X"00");
  signal Internal_Ram : Ram_8KType := (others => X"00");
  signal Stack_Ram : Ram_127Type := (others => X"00");

  signal Rom_Memory : Rom_32KType := (others => X"00");
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

  -- Process for writing to ram and other things...
  process (Clk)
  begin
    if rising_edge(Clk) then
      if Mem_Write_Enable = '1' then
        if Mem_Addr < X"4000" then
          -- Addresses 0-100 contains interrupt vectors.
          -- User program area. The ROM inserted into the unit.
          -- NOTE: Address X100 is the actual starting address, but
          -- since it is only three bytes before some data required
          -- by the boot-loader, it usually only contains the instruction
          -- JMP 0x150, which is where the predefined things end.
          -- No writing allowed here!
        elsif Mem_Addr < X"8000" then
          -- The addresses 4000-7FFF is switchable in som ROMS, implement!
          -- No writing allowed here!
        elsif Mem_Addr < X"A000" then
          -- Character data. Send to GPU.
          -- Character codes (BG data 1). Send to GPU.
          -- Character codes (BG data 2). Send to GPU.
          Gpu_Write_Enable <= '1';
          Gpu_Write <= Mem_Write;
        elsif Mem_Addr < X"C000" then
          -- External expansion working RAM 8KB.
          External_Ram(to_integer(unsigned(Mem_Addr(12 downto 0)))) <= Mem_Write;
        elsif Mem_Addr < X"E000" then
          -- Unit working ram 8KB.
          Internal_Ram(to_integer(unsigned(Mem_Addr(12 downto 0)))) <= Mem_Write;
        elsif Mem_Addr < X"FE00" then
          -- Prohibited. Undefined value!
        elsif Mem_Addr < X"FEA0" then
          -- OAM memory, send to GPU.
        elsif Mem_Addr < X"FF00" then
          -- Prohibited. Undefined value!
        elsif Mem_Addr < X"FF80" then
          -- Port mode registers (input).
          -- Control registers.
          -- Sound register.
        elsif Mem_Addr < X"FFFE" then
          -- Working stack and RAM.
          Stack_Ram(to_integer(unsigned(Mem_Addr(6 downto 0)))) <= Mem_Write;
        else
          -- Undefined.
        end if;
      else
        Gpu_Write_Enable <= '0';
      end if;
    end if;
  end process;

  -- Ensure GPU addr is correct
  Gpu_Addr <= Mem_Addr;

  -- Reading memory:
  Mem_Read <=
    -- Addresses 0-100 contains interrupt vectors.
    -- User program area. The ROM inserted into the unit.
    -- NOTE: Address X100 is the actual starting address, but
    -- since it is only three bytes before some data required
    -- by the boot-loader, it usually only contains the instruction
    -- JMP 0x150, which is where the predefined things end.
    Rom_Memory(to_integer(unsigned(Mem_Addr(12 downto 0))))
    when Mem_Addr < X"4000" else

    -- The addresses 4000-7FFF is switchable in som ROMS, implement!
    Rom_Memory(to_integer(unsigned(Mem_Addr(12 downto 0))))
    when Mem_Addr < X"8000" else

    -- Character data. Send to GPU.
    -- Character codes (BG data 1). Send to GPU.
    -- Character codes (BG data 2). Send to GPU.
    Gpu_Read
    when Mem_Addr < X"A000" else

    -- External expansion working RAM 8KB.
    External_Ram(to_integer(unsigned(Mem_Addr(12 downto 0))))
    when Mem_Addr < X"C000" else

    -- Unit working RAM 8KB.
    Internal_Ram(to_integer(unsigned(Mem_Addr(12 downto 0))))
    when Mem_Addr < X"E000" else

    -- Prohibited. Undefined value (mirror of internal ram!).
    X"00"
    when Mem_Addr < X"FE00" else

    -- OAM memory, sent to GPU
    X"00"
    when Mem_Addr < X"FEA0" else

    -- Prohibited, undefined value!
    X"00"
    when Mem_Addr < X"FF00" else

    -- Port mode registers (input).
    -- Control registers.
    -- Sound registers.
    X"00"
    when Mem_Addr < X"FF80" else

    -- Working stack and RAM.
    Stack_Ram(to_integer(unsigned(Mem_Addr(6 downto 0))))
    when Mem_Addr < X"FFFE" else

    -- Undefined. (0xFFFE-0xFFFF)
    X"FF";

end Bus_Controller_Behaviour;
