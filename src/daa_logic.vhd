library ieee;
use ieee.std_logic_1164.all;
use IEEE.numeric_std.all;

-- Logic for the DAA instruction.
-- Input - the register to manipulate
-- Flags - input flags
-- Flags_Out - output flags
-- Output - the result
-- See http://www.z80.info/z80syntx.htm#DAA for info.


-- --------------------------------------------------------------------------------
-- |           | C Flag  | HEX value in | H Flag | HEX value in | Number  | C flag|
-- | Operation | Before  | upper digit  | Before | lower digit  | added   | After |
-- | (example) | DAA     | (bit 7-4)    | DAA    | (bit 3-0)    | to byte | DAA   |
-- |------------------------------------------------------------------------------|
-- |           |    0    |     0-9      |   0    |     0-9      |   00    |   0   |
-- |   ADD     |    0    |     0-8      |   0    |     A-F      |   06    |   0   |
-- |           |    0    |     0-9      |   1    |     0-3      |   06    |   0   |
-- |   ADC     |    0    |     A-F      |   0    |     0-9      |   60    |   1   |
-- |           |    0    |     9-F      |   0    |     A-F      |   66    |   1   |
-- |   INC     |    0    |     A-F      |   1    |     0-3      |   66    |   1   |
-- |           |    1    |     0-2      |   0    |     0-9      |   60    |   1   |
-- |           |    1    |     0-2      |   0    |     A-F      |   66    |   1   |
-- |           |    1    |     0-3      |   1    |     0-3      |   66    |   1   |
-- |------------------------------------------------------------------------------|
-- |   SUB     |    0    |     0-9      |   0    |     0-9      |   00    |   0   |
-- |   SBC     |    0    |     0-8      |   1    |     6-F      |   FA    |   0   |
-- |   DEC     |    1    |     7-F      |   0    |     0-9      |   A0    |   1   |
-- |   NEG     |    1    |     6-F      |   1    |     6-F      |   9A    |   1   |
-- |------------------------------------------------------------------------------|

-- NOT IMPLEMENTED YET!

entity Daa_Logic is
  port (Input : in std_logic_vector(7 downto 0);
        Flags : in std_logic_vector(7 downto 0);
        Flags_Out : out std_logic_vector(7 downto 0);
        Output : out std_logic_vector(7 downto 0));
end Daa_Logic;

architecture Daa_Implementation of Daa_Logic is
  signal C, H, C_Out, Z_Out : std_logic;

  -- Upper and lower 4 bits of the input.
  signal Upper, Lower : std_logic_vector(3 downto 0);

  -- The value to add to Input
  signal To_Add : std_logic_vector(7 downto 0);

  -- Concatenation of the To_Add and C_Out for convenience in the table.
  signal To_Add_C_Out : std_logic_vector(8 downto 0);

  -- Temorary output (to be able to generate the zero flag).
  signal Tmp_Output : std_logic_vector(7 downto 0);
begin
  C <= Flags(4);
  H <= Flags(5);

  Upper <= Input(7 downto 4);
  Lower <= Input(3 downto 0);

  -- Lookup table according to the above table.
  To_Add_C_Out <=
    X"00" & "0" when C = '0' and Upper < X"A" and H = '0' and Lower < X"A" else
    X"06" & "0" when C = '0' and Upper < X"9" and H = '0' and Lower > X"9" else    
    X"06" & "0" when C = '0' and Upper < X"A" and H = '1' and Lower < X"4" else
    X"60" & "1" when C = '0' and Upper > X"9" and H = '0' and Lower < X"A" else
    X"66" & "1" when C = '0' and Upper > X"8" and H = '0' and Lower > X"9" else
    X"66" & "1" when C = '0' and Upper > X"9" and H = '1' and Lower < X"4" else
    X"60" & "1" when C = '1' and Upper < X"3" and H = '0' and Lower < X"A" else
    X"66" & "1" when C = '1' and Upper < X"3" and H = '0' and Lower > X"9" else
    X"66" & "1" when C = '1' and Upper < X"4" and H = '1' and Lower < X"4" else
    X"00" & "0" when C = '0' and Upper < X"A" and H = '0' and Lower < X"A" else
    X"FA" & "0" when C = '0' and Upper < X"9" and H = '1' and Lower > X"5" else
    X"A0" & "1" when C = '1' and Upper > X"6" and H = '0' and Lower < X"A" else
    X"9A" & "1" when C = '1' and Upper > X"5" and H = '1' and Lower > X"5" else
    X"00" & "0";

  To_Add <= To_Add_C_Out(8 downto 1);
  C_Out <= To_Add_C_Out(0);

  -- Calculate the result.
  Tmp_Output <= std_logic_vector(unsigned(Input) + unsigned(To_Add));
  Z_Out <= '1' when Tmp_Output = X"00" else
           '0';
  Output <= Tmp_Output;

  Flags_Out(7) <= Z_Out;
  Flags_Out(6) <= Flags(6);
  Flags_Out(5) <= '0';
  Flags_Out(4) <= C_Out;
  Flags_Out(3 downto 0) <= "0000";
end Daa_Implementation;
