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
-- 000: Addition
-- 001: Subtraction
-- 010: Addition with carry from Flags_In
-- 011: Subtraction with carry from Flags_In
-- 100: And (bitwise)
entity Alu is
  port(A, B : in std_logic_vector(15 downto 0);
       Mode : in std_logic_vector(2 downto 0);
       Flags_In : in std_logic_vector(7 downto 0);
       Result : out std_logic_vector(15 downto 0);
       Flags : out std_logic_vector(7 downto 0));
end Alu;

architecture Alu_Implementation of Alu is
  -- The lower nibbles of A and B, filled with a leading zero.
  signal A_Nibble, B_Nibble, Result_Nibble : std_logic_vector(4 downto 0);
  -- The lower bytes of A and B, filled with a leading zero.
  signal A_Byte, B_Byte, Result_Byte : std_logic_vector(8 downto 0);

  -- Easier access to the carry flag.
  signal Carry_Flag : std_logic_vector(0 downto 0) := "0";

  -- Temporary result
  signal Tmp_Result : std_logic_vector(15 downto 0);

  -- Temp flags
  signal Z, N, H, C : std_logic;
begin
  Carry_Flag <= Flags_In(4 downto 4);

  A_Nibble <= "0" & A(3 downto 0);
  B_Nibble <= "0" & B(3 downto 0);
  Result_Nibble <=
    std_logic_vector(unsigned(A_Nibble) + unsigned(B_Nibble)) when Mode = "000" else
    std_logic_vector(unsigned(A_Nibble) - unsigned(B_Nibble)) when Mode = "001" else
    std_logic_vector(unsigned(A_Nibble) + unsigned(B_Nibble) + unsigned(Carry_Flag)) when Mode = "010" else
    std_logic_vector(unsigned(A_Nibble) - unsigned(B_Nibble) - unsigned(Carry_Flag)) when Mode = "011" else
    A_Nibble and B_Nibble when Mode = "100" else
    "00000";

  A_Byte <= "0" & A(7 downto 0);
  B_Byte <= "0" & B(7 downto 0);
  Result_Byte <=
    std_logic_vector(unsigned(A_Byte) + unsigned(B_Byte)) when Mode = "000" else
    std_logic_vector(unsigned(A_Byte) - unsigned(B_Byte)) when Mode = "001" else
    std_logic_vector(unsigned(A_Byte) + unsigned(B_Byte) + unsigned(Carry_Flag)) when Mode = "010" else
    std_logic_vector(unsigned(A_Byte) - unsigned(B_Byte) - unsigned(Carry_Flag)) when Mode = "011" else
    A_Byte and B_Byte when Mode = "100" else
    "000000000";

  Tmp_Result <=
    std_logic_vector(unsigned(A) + unsigned(B)) when Mode = "000" else
    std_logic_vector(unsigned(A) - unsigned(B)) when Mode = "001" else
    std_logic_vector(unsigned(A) + unsigned(B) + unsigned(Carry_Flag)) when Mode = "010" else
    std_logic_vector(unsigned(A) - unsigned(B) - unsigned(Carry_Flag)) when Mode = "011" else
    A and B when Mode = "100" else
    X"0000";
  Result <= Tmp_Result;

  C <= Result_Byte(8);
  H <= Result_Nibble(4);
  N <= '1' when Mode = "001" else
       '0';
  Z <= '1' when Tmp_Result = X"0000" else
       '0';

  Flags(3 downto 0) <= "0000";
  Flags(4) <= C;
  Flags(5) <= H;
  Flags(6) <= N;
  Flags(7) <= Z;
end Alu_Implementation;
