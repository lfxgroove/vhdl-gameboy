library ieee;
use ieee.std_logic_1164.all;
use IEEE.numeric_std.all;

-- This entity takes care of controller/joypad input and forwards it to the bus
-- where it is instatiated

entity Input is
  port (Clk, Reset : in std_logic;
        Controller_Data_Select : in std_logic_vector(1 downto 0);
        Controller_Input : out std_logic_vector(3 downto 0);
        Pulse, Latch  : out std_logic;
        Data : in std_logic);
end Input;

architecture Input_Behaviour of Input is

  --Goes to FFFF, gives ~1.5kHz
  signal Clock_Ctr : std_logic_vector(15 downto 0) := X"0000";
  signal Internal_Clock : std_logic := '0';
  type State_Type is (Latching, Reading, Waiting, Pulsing);
  signal State : State_Type := Waiting;
  signal Read_Counter : std_logic_vector(3 downto 0) := X"0";
  signal Read_Buffer : std_logic_vector(7 downto 0) := X"00";
  signal Current_Buttons : std_logic_vector(7 downto 0) := X"00";

begin
  
  Controller_Input <=
    Current_Buttons(4) & Current_Buttons(5) & Current_Buttons(6) & Current_Buttons(7)
    when Controller_Data_Select = "01" else
    Current_Buttons(2) & Current_Buttons(3) & Current_Buttons(1) & Current_Buttons(0)
    when Controller_Data_Select = "10" else
    X"0";
  
  -- Creates an internal clock for us that's slower than the bastardous 100MHz
  process (Clk)
  begin
    if rising_edge(Clk) then
      Internal_Clock <= '0';
      if Clock_Ctr = X"FFFF" then
        Clock_Ctr <= X"0000";
        Internal_Clock <= '1';
    else
        Clock_Ctr <= std_logic_vector(unsigned(Clock_Ctr) + 1);
      end if;
    end if;   
  end process;

  -- Process to read data that is available from the controller, the states
  -- that we go through are: waiting, latching, reading and pulsing. We start with
  -- latching to tell the NES-controller to save what buttons are being pressed
  -- to it's shift-register. After that we read 8 bits by pulsing and then reading
  -- one bit. Totally we send 7 pulses since we get the first bit "for free" directly.
  process (Clk)
  begin
    if rising_edge(Clk) then
      if Internal_Clock = '1' then
        Latch <= '0';
        Pulse <= '0';
        case State is
          when Waiting =>
            State <= Latching;
          when Latching =>
            Latch <= '1';
            Read_Buffer <= X"00";
            Read_Counter <= X"0";
            state <= Reading;
          when Reading =>
            if Read_Counter = X"8" then
              State <= Waiting;
              Current_Buttons <= Read_Buffer;
            else
              Read_Buffer <= Read_Buffer(6 downto 0) & Data;
              Read_Counter <= std_logic_vector(unsigned(Read_Counter) + 1);
              State <= Pulsing;
            end if;
          when Pulsing =>
            Pulse <= '1';
            State <= Reading;
        end case;
      end if;
    end if;   
  end process;

end Input_Behaviour;
