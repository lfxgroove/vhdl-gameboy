library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_textio.all;
use ieee.numeric_std.all;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.STD_LOGIC_UNSIGNED.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity Serial is
    Port ( Clk , Rst, RxD, TxD : in  std_logic;
           Led : out std_logic_vector(7 downto 0);
           Rom_Write_Enable : out std_logic;
           Rom_Addr : out std_logic_vector(15 downto 0);
           Rom_Write : out std_logic_vector(7 downto 0);
           Rst_Cpu : out std_logic);
           
end Serial;

architecture Behavioral of Serial is
    signal sreg : std_logic_vector(9 downto 0) := B"0_00000000_0";  -- 10 bit shiftreg
    signal tal : std_logic_vector(15 downto 0) := X"0000";  
    signal rx1,rx2 : std_logic;         
    signal sp : std_logic; -- shiftpulse
    signal lp : std_logic; -- loadpulse
    signal pos : std_logic_vector(1 downto 0) := "00";
    
    signal counter : std_logic_vector(9 downto 0) := B"00_0000_0000";  -- Internal counter in the
                                                                       -- controller unit
    signal rcving : std_logic_vector(4 downto 0) := B"0_0000";  -- How many bits are left?

    type State_Type is (Size1, Size2, Data_State, Checksum_State);
    signal State : State_Type := Size1;
    signal Size : std_logic_vector(15 downto 0);
    signal Checksum : std_logic_vector(7 downto 0);
    signal Data : std_logic_vector(7 downto 0);
    signal Current_Addr : std_logic_vector(15 downto 0) := X"0000";
begin
  process (Clk)
  begin
    if rising_edge(Clk) then
      if rst = '1' then
        rx1 <= '0';
        rx2 <= '0';
      else
        rx1 <= RxD;
        rx2 <= rx1;
      end if;
    end if;
  end process;

  
  
  --process(Clk)
  --begin
  --  if rising_edge(Clk) then
  --  end if;     
  --end process;       
  
  process (Clk)
  begin
    if rising_edge(Clk) then
      sp <= '0';
      lp <= '0';
      if rst = '1' then
        counter <= B"00_0000_0000";
        rcving <= B"00000";
      elsif rx1 = '0' and rx2 = '1' and counter = 0 then
        rcving <= B"01011"; --11
        counter <= B"0110110010"; --434;                 -- 868 / 2
      elsif rcving > 1 and counter = 0 then
        sp <= '1';
        rcving <= rcving - 1;
        counter <= B"1101100100"; --868;
      elsif rcving = 1 and counter = 860 then
        if sreg(9) = '1' and sreg(0) = '0' then
          lp <= '1';
        end if;
        counter <= B"00_0000_0000";
        rcving <= B"00000";--0;
      elsif rcving /= 0 then
        counter <= counter - 1;
      end if;
    end if;
  end process;

  Data <= sreg(8 downto 1);

    -- 10 bit shiftregister
  process (Clk)
  begin  -- process
    if rising_edge(Clk) then
      if rst = '1' then
        sreg <= B"00_0000_0000";
      elsif sp = '1' then
        sreg <= rx2 & sreg(9 downto 1);
      end if;
    end if;
  end process;

  process(Clk)
  begin
    if rising_edge(Clk) then
      if Rst = '1' then
        State <= Size1;
      elsif lp = '1' then
        case (State) is
          when Size1 =>
            Size(7 downto 0) <= Data;
            Rst_Cpu <= '1';
            State <= Size2;
          when Size2 =>
            Checksum <= X"00";
            Size(15 downto 8) <= Data;
            Current_Addr <= X"0000";
            State <= Data_State;
          when Data_State =>
            Led(7 downto 0) <= B"0" & Size(15 downto 9);
            Checksum <= std_logic_vector(unsigned(Checksum) + unsigned(Data));
            Current_Addr <= std_logic_vector(unsigned(Current_Addr) + 1);
            Rom_Addr <= Current_Addr;
            Rom_Write <= Data;
            Rom_Write_Enable <= '1';
            if Size = X"0001" then
              State <= Checksum_State;
            else
              Size <= std_logic_vector(unsigned(Size) - 1);
            end if;
          when Checksum_State =>
            if Checksum = Data then
              Led(7 downto 0) <= B"11111111";
              Rst_Cpu <= '0';
            end if;
            State <= Size1;
        end case;
      else
          Rom_Write_Enable <= '0';
      end if;
    end if;     
  end process;       
  
end Behavioral;

