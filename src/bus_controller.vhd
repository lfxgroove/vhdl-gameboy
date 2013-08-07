--Copyright (c) 2013, Filip Strömbäck, Anton Sundblad, Alex Telon
--All rights reserved.

--Redistribution and use in source and binary forms, with or without
--modification, are permitted provided that the following conditions are met:
--    * Redistributions of source code must retain the above copyright
--      notice, this list of conditions and the following disclaimer.
--    * Redistributions in binary form must reproduce the above copyright
--      notice, this list of conditions and the following disclaimer in the
--      documentation and/or other materials provided with the distribution.
--    * The names of the contributors may not be used to endorse or promote products
--      derived from this software without specific prior written permission.

--THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
--ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
--WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
--DISCLAIMED. IN NO EVENT SHALL FILIP STRÖMBÄCK, ANTON SUNDBLAD OR ALEX TELON 
--BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR 
--CONSEQUENTIAL DAMAGES(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF 
--SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS 
--INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
--STRICT LIABILITY, OR TORT(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
--OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

library ieee;
use ieee.std_logic_1164.all;
use IEEE.numeric_std.all;

-- This is the bus controller, which abstracts the memory
-- map seen from the CPU. The bus controller also contains
-- the main RAM of the GB.
-- See page 14 in the gb-programming-manual for the memory
-- layout.
-- This also incorporates timer logic

-- The layout looks like this:
-- 0x0000-0x3999 - Static ROM bank. Mapped to 0x0000-0x3999 in the rom
-- 0x4000-0x7999 - Switchable ROM bank. Initially mapped to 0x4000-0x7999
-- 0x8000-0x9FFF - Read BG, Sprite data from the GPU
-- 0xA000-0xBFFF - External expansion working ram (8K)
-- 0xC000-0xDFFF - Internal working ram (8K)
-- 0xE000-0xFDFF - (Undefined in manual) Echo of 0xC000-0xDFFF
-- 0xFE00-0xFE9F - OAM memory. Sent to GPU
-- 0xFEA0-0xFEFF - Empty
-- 0xFF00-0xFF7F - Port mode registers, control registers, sound registers
-- 0xFF80-0xFFFD - Working stack and RAM.
-- 0xFFFE-0xFFFF - Undefined. Implemented as extension of working stack and RAM.

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
        Rom_Write : in std_logic_vector(7 downto 0);
        -- Timer interrupts
        Timer_Interrupt : out std_logic;
        Pulse, Latch  : out std_logic;
        Data : in std_logic;
        Current_Interrupts : in std_logic_vector(7 downto 0));
  end Bus_Controller;

architecture Bus_Controller_Behaviour of Bus_Controller is
  component Input
    port(Clk, Reset : in std_logic;
         Controller_Data_Select : in std_logic_vector(1 downto 0);
         Controller_Input : out std_logic_vector(3 downto 0);
         Pulse, Latch  : out std_logic;
         -- Data comes in inverted, 1 mean the button is not pressed.
         Data : in std_logic);
  end component;
  
  type Ram_8KType is array (0 to 8191) of std_logic_vector(7 downto 0);
  type Ram_128Type is array (0 to 127) of std_logic_vector(7 downto 0);
  type Rom_32KType is array (0 to 32767) of std_logic_vector(7 downto 0);

  signal External_Ram : Ram_8KType := (others => X"00");
  signal Internal_Ram : Ram_8KType := (others => X"00");
  signal Stack_Ram : Ram_128Type := (others => X"00");

  signal Rom_Memory : Rom_32KType := (others => X"76");  --filled with HALT to
                                                         --begin with

  --Timer signals
  --Always increases at specific rate, 16384Hz, reg: 0xFF04
  signal Timer_Divider : std_logic_vector(7 downto 0) := X"00";
  --Counter increases at rate specified by Timer_Speed, reg: 0xFF05
  signal Timer_Counter : std_logic_vector(7 downto 0) := X"00";
  signal Timer_Counter_Reset_Val : std_logic_vector(7 downto 0) := X"00";
  signal Timer_Counter_Reset : std_logic := '0';
  --When counter overflows, the counter starts at modulo, reg: 0xFF06
  signal Timer_Modulo : std_logic_vector(7 downto 0) := X"00";
  --Register for controlling various settings in the timer, reg: 0xFF07
  signal Timer_Control : std_logic_vector(7 downto 0) := X"00";
  --4 different modes, 00 4096Hz, 01, 262144Hz, 10, 65536Hz, 11 16384Hz
  alias Timer_Speed : std_logic_vector(1 downto 0) is Timer_Control(1 downto 0);
  alias Timer_Running : std_logic is Timer_Control(2);  --1 to run, 0 to stop

  --Will count to: Hz_Variable_To(3)
  signal Hz_16384_Counter : std_logic_vector(15 downto 0);
  signal Hz_Reset_Divider : std_logic := '0';
  signal Hz_Variable_Counter : std_logic_vector(15 downto 0);
  type Clock_Intervals is array(0 to 3) of std_logic_vector(15 downto 0);
  --Ordering: 4096Hz, 262144Hz, 65536Hz, 16384Hz
  constant Hz_Variable_To : Clock_Intervals := (X"5F5F", X"017E", X"05F6", X"17D8");

  -- Input signals
  signal Controller_Data_Select : std_logic_vector(1 downto 0) := "00";
  signal Controller_Input : std_logic_vector(3 downto 0) := X"0";
  
  
begin
  Input_Port : Input port map (
    Clk => Clk,
    Reset => Reset,
    Controller_Data_Select => Controller_Data_Select,
    Controller_Input => Controller_Input,
    Pulse => Pulse,
    Latch => Latch,
    Data => Data);
  
  --Generates a static clock, 16384 Hz
  process (Clk)
  begin
    if rising_edge(Clk) then
      if Hz_Reset_Divider = '1' then
        Timer_Divider <= X"00";
      elsif Hz_16384_Counter = Hz_Variable_To(3) then
        Hz_16384_Counter <= X"0000";
        Timer_Divider <= std_logic_vector(unsigned(Timer_Divider) + 1);
      else
        Hz_16384_Counter <= std_logic_vector(unsigned(Hz_16384_Counter) + 1);
      end if;
    end if;   
  end process;
  
  --The variable clock which can be changed between
  --4096Hz, 262144Hz, 65536Hz and 16384Hz
  process (Clk)
  begin
    if rising_edge(Clk) then
      Timer_Interrupt <= '0';
      if Timer_Running = '1' then
        if Timer_Counter_Reset = '1' then
          Timer_Counter <= Timer_Counter_Reset_Val;
        end if; 
        if Hz_Variable_Counter = Hz_Variable_to(to_integer(unsigned(Timer_Speed))) then
          if Timer_Counter = X"FF" then
            Timer_Counter <= Timer_Modulo;
            Timer_Interrupt <= '1';
          else
            Timer_Counter <= std_logic_vector(unsigned(Timer_Counter) + 1);
          end if;
          Hz_Variable_Counter <= X"0000";
        else
          Hz_Variable_Counter <= std_logic_vector(unsigned(Hz_Variable_Counter) + 1);
        end if;
      end if;
    end if;
  end process;
  
  -- Writing to the rom
  process (Clk)
  begin
    if rising_edge(Clk) then
      if Rom_Write_Enable = '1' then
        Rom_Memory(to_integer(unsigned(Rom_Addr))) <= Rom_Write;
      end if;
    end if;
  end process;
  
  -- Writing to the RAM and other registers that are acessible
  -- through the bus, also forwards the data sometime to the GPU
  -- if necessary.
  process (Clk)
  begin
    if rising_edge(Clk) then
      Hz_Reset_Divider <= '0';           
      Timer_Counter_Reset <= '0';      
      if Mem_Write_Enable = '1' then
        if Mem_Addr(15 downto 14) = "00" then  -- 0x0000-0x3900
          -- Addresses 0-100 contains interrupt vectors.
          -- User program area. The ROM inserted into the unit.
          -- NOTE: Address X100 is the actual starting address, but
          -- since it is only three bytes before some data required
          -- by the boot-loader, it usually only contains the instruction
          -- JMP 0x150, which is where the predefined things end.
          -- No writing allowed here!
        elsif Mem_Addr(15 downto 14) = "01" then  -- 0x4000-0x7FFF
          -- The addresses 4000-7FFF is switchable in som ROMS, implement!
          -- No writing allowed here!
        elsif Mem_Addr(15 downto 13) = "100" then -- 0x8000-0x9FFF
          -- Character data. Send to GPU.
          -- Character codes (BG data 1). Send to GPU.
          -- Character codes (BG data 2). Send to GPU.
          -- Writes are handled below.
        elsif Mem_Addr(15 downto 13) = "101" then -- 0xA000-0xBFFF
          -- External expansion working RAM 8KB.
          External_Ram(to_integer(unsigned(Mem_Addr(12 downto 0)))) <= Mem_Write;
        elsif Mem_Addr(15 downto 13) = "110" then  -- 0xC000-0xDFFF
          -- Unit working ram 8KB.
          Internal_Ram(to_integer(unsigned(Mem_Addr(12 downto 0)))) <= Mem_Write;
          -- Addresses 0xE000-0xFDFF are handled by the "else" case.
        elsif Mem_Addr(15 downto 8) = "11111110" then  -- 0xFE00-0xFE9F
          -- OAM memory, send to GPU.
          -- Writes are handled below.
        elsif Mem_Addr(15 downto 0) = X"FF00" then
          Controller_Data_Select <= Mem_Write(5 downto 4);
        elsif Mem_Addr(15 downto 0) = X"FF04" then
          --Timer writes
          Hz_Reset_Divider <= '1';
        elsif Mem_Addr(15 downto 0) = X"FF05" then
          Timer_Counter_Reset_Val <= Mem_Write;
          Timer_Counter_Reset <= '1';
        elsif Mem_Addr(15 downto 0) = X"FF06" then
          Timer_Modulo <= Mem_Write;
        elsif Mem_Addr(15 downto 0) = X"FF07" then
          Timer_Control <= Mem_Write;
        elsif Mem_Addr(15 downto 7) = "111111110" then  -- 0xFF00-0xFF7F
          -- Port mode registers (input).
          -- Control registers.
          -- Sound register.
        elsif Mem_Addr(15 downto 7) = "111111111" then  -- 0xFF80-0xFFFF
          -- Working stack and RAM.
          Stack_Ram(to_integer(unsigned(Mem_Addr(6 downto 0)))) <= Mem_Write;
        else
          -- Undefined.
        end if;
      end if;
    end if;
  end process;

  -- Ensure GPU addr is correct
  Gpu_Addr <= Mem_Addr;
  Gpu_Write <= Mem_Write;

  -- Writing to GPU. Must be in an async process since we need to
  -- write in one cp.
  Gpu_Write_Enable <=
    Mem_Write_Enable when Mem_Addr(15 downto 14) = "10" else  -- 0x8000-0x9FFF
    Mem_Write_Enable when Mem_Addr(15 downto 8) = "11111110" else  -- 0xFE00-0xFE9F
                                                      -- (actually to 0xFEFF)
    Mem_Write_Enable when Mem_Addr(15 downto 4) = X"FF4" else  -- Gpu Stuff :), see
                                                  -- gpu_logic for more info
    --'1' when Mem_Addr(15 downto 0) = X"FF42" else  -- Scroll register Y
    --'1' when Mem_Addr(15 downto 0) = X"FF43" else  -- Scroll register X
    --'1' when Mem_Addr(15 downto 0) = X"FF40" else  -- LCD register
    '0';

  -- This takes care of reading from RAM and some registers,
  -- also forwards signals to the GPU if necessary.
  process (Clk)
  begin
    if rising_edge(Clk) then
      if Mem_Write_Enable = '0' then
        if Mem_Addr(15 downto 14) = "00" then  -- 0x0000-0x3FFF
          -- Addresses 0-100 contains interrupt vectors.
          -- User program area. The ROM inserted into the unit.
          -- NOTE: Address X100 is the actual starting address, but
          -- since it is only three bytes before some data required
          -- by the boot-loader, it usually only contains the instruction
          -- JMP 0x150, which is where the predefined things end.
          -- No writing allowed here!
          Mem_Read <= Rom_Memory(to_integer(unsigned(Mem_Addr(14 downto 0))));
        elsif Mem_Addr(15 downto 14) = "01" then  -- 0x4000-0x7FFF
          -- The addresses 4000-7FFF is switchable in som ROMS, implement!
          -- No writing allowed here!
          Mem_Read <= Rom_Memory(to_integer(unsigned(Mem_Addr(14 downto 0))));
        elsif Mem_Addr(15 downto 13) = "100" then -- 0x8000-0x9FFF
          -- Character data. Send to GPU.
          -- Character codes (BG data 1). Send to GPU.
          -- Character codes (BG data 2). Send to GPU.
          -- Writes are handled below.
          --Mem_Read <= Gpu_Read;
          Mem_Read <= X"00";
        elsif Mem_Addr(15 downto 13) = "101" then -- 0xA000-0xBFFF
          -- External expansion working RAM 8KB.
          Mem_Read <= External_Ram(to_integer(unsigned(Mem_Addr(12 downto 0))));
        elsif Mem_Addr(15 downto 13) = "110" then  -- 0xC000-0xDFFF
          -- Unit working ram 8KB.
          Mem_Read <= Internal_Ram(to_integer(unsigned(Mem_Addr(12 downto 0))));
          -- Addresses 0xE000-0xFDFF are handled by the "else" case.
        elsif Mem_Addr(15 downto 8) = "11111110" then  -- 0xFE00-0xFE9F
          -- OAM memory, send to GPU.
          -- Writes are handled below
          --Mem_Read <= Gpu_Read;
          Mem_Read <= X"00";
        elsif Mem_Addr(15 downto 0) = X"FF00" then
          Mem_Read <= "00" & Controller_Data_Select & Controller_Input;
        elsif Mem_Addr(15 downto 0) = X"FF04" then
          --Timer reads
          Mem_Read <= Timer_Divider;
        elsif Mem_Addr(15 downto 0) = X"FF05" then
          Mem_Read <= Timer_Counter;
        elsif Mem_Addr(15 downto 0) = X"FF06" then
          Mem_Read <= Timer_Modulo;
        elsif Mem_Addr(15 downto 0) = X"FF07" then
          Mem_Read <= Timer_Control;
        elsif Mem_Addr(15 downto 0) = X"FF0F" then
          Mem_Read <= Current_Interrupts;
        elsif Mem_Addr(15 downto 4) = X"FF4" then
          --Read from GPU, for Stat reg right now
          Mem_Read <= Gpu_Read;
        elsif Mem_Addr(15 downto 7) = "111111110" then  -- 0xFF00-0xFF7F
          -- Port mode registers (input).
          -- Control registers.
          -- Sound register.
          Mem_Read <= X"00";
        elsif Mem_Addr(15 downto 7) = "111111111" then  -- 0xFF80-0xFFFF
          -- Working stack and RAM.
          Mem_Read <= Stack_Ram(to_integer(unsigned(Mem_Addr(6 downto 0))));
        else
          -- Undefined value (mirror of internal ram).
          Mem_Read <= Internal_Ram(to_integer(unsigned(Mem_Addr(12 downto 0))));
        end if;
      end if;
    end if;
  end process;

end Bus_Controller_Behaviour;
