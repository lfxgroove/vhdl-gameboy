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
-- The High_Flags signal specified if the C and H flags should
-- be calculated from the high-order byte instead of the low-order.
--
-- Mode: The modes accepted by the ALU is:
-- 0000: Addition
-- 0001: Subtraction
-- 0010: Addition with carry from Flags_In
-- 0011: Subtraction with carry from Flags_In
-- 0100: And (bitwise)
-- 0101: Or (bitwise)
-- 0110: Xor (bitwise)
-- 0111: Increase A (does not affect C flag).
-- 1000: Decrease A (does not affect C flag).
entity Alu is
  port(A, B : in std_logic_vector(15 downto 0);
       Mode : in std_logic_vector(3 downto 0);
       Flags_In : in std_logic_vector(7 downto 0);
       Result : out std_logic_vector(15 downto 0);
       Flags : out std_logic_vector(7 downto 0);
       High_Flags : in std_logic);
end Alu;

architecture Alu_Implementation of Alu is
  -- The lower nibbles of A and B, filled with a leading zero.
  signal A_Half, B_Half, Result_Half : std_logic_vector(16 downto 0);
  -- The lower bytes of A and B, filled with a leading zero.
  signal A_Carry, B_Carry, Result_Carry : std_logic_vector(16 downto 0);

  -- Easier access to the carry flag.
  signal Carry_Flag : std_logic_vector(0 downto 0) := "0";

  -- Temporary result
  signal Tmp_Result : std_logic_vector(15 downto 0);

  -- Temp flags
  signal Z, N, H, C : std_logic;
begin
  Carry_Flag <= Flags_In(4 downto 4);

  A_Half <= X"000" & "0" & A(3 downto 0) when High_Flags = '0' else
            "00000" & A(11 downto 0);
  B_Half <= X"000" & "0" & B(3 downto 0) when High_Flags = '0' else
            "00000" & B(11 downto 0);
  Result_Half <=
    std_logic_vector(unsigned(A_Half) + unsigned(B_Half)) when Mode = "0000" else
    std_logic_vector(unsigned(A_Half) - unsigned(B_Half)) when Mode = "0001" else
    std_logic_vector(unsigned(A_Half) + unsigned(B_Half) + unsigned(Carry_Flag)) when Mode = "0010" else
    std_logic_vector(unsigned(A_Half) - unsigned(B_Half) - unsigned(Carry_Flag)) when Mode = "0011" else
    -- H should be set when AND-ing.
    (others => '1') when Mode = "0100" else
    (others => '0') when Mode = "0101" else
    (others => '0') when Mode = "0110" else
    std_logic_vector(unsigned(A_Half) + 1) when Mode = "0111" else
    std_logic_vector(unsigned(A_Half) - 1) when Mode = "1000" else
    (others => '0');

  A_Carry <= "000000000" & A(7 downto 0) when High_Flags = '0' else
             "0" & A(15 downto 0);
  B_Carry <= "000000000" & B(7 downto 0) when High_Flags = '0' else
             "0" & B(15 downto 0);
  Result_Carry <=
    std_logic_vector(unsigned(A_Carry) + unsigned(B_Carry)) when Mode = "0000" else
    std_logic_vector(unsigned(A_Carry) - unsigned(B_Carry)) when Mode = "0001" else
    std_logic_vector(unsigned(A_Carry) + unsigned(B_Carry) + unsigned(Carry_Flag)) when Mode = "0010" else
    std_logic_vector(unsigned(A_Carry) - unsigned(B_Carry) - unsigned(Carry_Flag)) when Mode = "0011" else
    (others => '0') when Mode = "0100" else
    (others => '0') when Mode = "0101" else
    (others => '0') when Mode = "0110" else
    -- Inc does not affect C. Insert it into MSB
    (others => Carry_Flag(0)) when Mode = "0111" else
    -- Dec does not affect C. Insert it into MSB
    (others => Carry_Flag(0)) when Mode = "1000" else
    (others => '0');

  Tmp_Result <=
    std_logic_vector(unsigned(A) + unsigned(B)) when Mode = "0000" else
    std_logic_vector(unsigned(A) - unsigned(B)) when Mode = "0001" else
    std_logic_vector(unsigned(A) + unsigned(B) + unsigned(Carry_Flag)) when Mode = "0010" else
    std_logic_vector(unsigned(A) - unsigned(B) - unsigned(Carry_Flag)) when Mode = "0011" else
    A and B when Mode = "0100" else
    A or B when Mode = "0101" else
    A xor B when Mode = "0110" else
    std_logic_vector(unsigned(A) + 1) when Mode = "0111" else
    std_logic_vector(unsigned(A) - 1) when Mode = "1000" else
    X"0000";
  Result <= Tmp_Result;

  C <= Result_Carry(8) when High_Flags = '0' else
       Result_Carry(16);
  H <= Result_Half(4) when High_Flags = '0' else
       Result_Half(12);
  N <= '1' when Mode = "0001" else
       '0';
  Z <= '1' when Tmp_Result(7 downto 0) = X"00" and High_Flags = '0' else
       '1' when Tmp_Result = X"0000" and High_Flags = '1' else
       '0';

  Flags(3 downto 0) <= "0000";
  Flags(4) <= C;
  Flags(5) <= H;
  Flags(6) <= N;
  Flags(7) <= Z;
end Alu_Implementation;
