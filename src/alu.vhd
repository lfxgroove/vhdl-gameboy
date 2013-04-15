library ieee;
use ieee.std_logic_1164.all;
use IEEE.numeric_std.all;

-- This is a totally async alu, to simplify the work
-- needed in the actual CPU. Especially when updating
-- the flags.
-- This is a 16-bit ALU to provide support for 16-bit
-- modes sometimes needed when manipulating addresses.
-- The flags output signal have the same meaning as the
-- flags register in the cpu, ie:
-- Bit 7: Z - Set when the result is zero.
-- Bit 6: N - Set if a subtraction was performed.
-- Bit 5: H - Set if a carry occurred from the lower nibble.
-- Bit 4: C - Set if a carry occurred from the last byte.
--
-- Mode: The modes accepted by the ALU is:
-- 00: Addition
-- 01: Subtraction
-- 10: Not implemented yet
-- 11: Not implemented yet
entity Alu is
  port(A, B : in std_logic_vector(15 downto 0);
       Mode : in std_logic_vector(1 downto 0);
       Result : out std_logic_vector(15 downto 0);
       Flags : out std_logic_vector(7 downto 0));
end Alu;

architecture Alu_Implementation of Alu is
  -- The lower nibbles of A and B, filled with a leading zero.
  signal A_Nibble, B_Nibble, Result_Nibble : std_logic_vector(4 downto 0);
  -- The lower bytes of A and B, filled with a leading zero.
  signal A_Byte, B_Byte, Result_Byte : std_logic_vector(8 downto 0);

  -- Temporary result
  signal Tmp_Result : std_logic_vector(15 downto 0);
begin
  A_Nibble <= "0" & A(3 downto 0);
  B_Nibble <= "0" & B(3 downto 0);
  Result_Nibble <=
    std_logic_vector(unsigned(A_Nibble) + unsigned(B_Nibble)) when Mode = "00" else
    std_logic_vector(unsigned(A_Nibble) - unsigned(B_Nibble)) when Mode = "01" else
    "00000";

  A_Byte <= "0" & A(7 downto 0);
  B_Byte <= "0" & B(7 downto 0);
  Result_Byte <=
    std_logic_vector(unsigned(A_Byte) + unsigned(B_Byte)) when Mode = "00" else
    std_logic_vector(unsigned(A_Byte) - unsigned(B_Byte)) when Mode = "01" else
    "000000000";

  Tmp_Result <=
    std_logic_vector(unsigned(A) + unsigned(B)) when Mode = "00" else
    std_logic_vector(unsigned(A) - unsigned(B)) when Mode = "01" else
    X"0000";
  Result <= Tmp_Result;

  Flags(3 downto 0) <= "0000";
  Flags(4) <= Result_Byte(8);
  Flags(5) <= Result_Nibble(4);
  Flags(6) <= '1' when Mode = "01" else
              '0';
  Flags(7) <= '1' when Tmp_Result = X"0000" else
              '0';
end Alu_Implementation;
