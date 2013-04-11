library ieee;
use ieee.std_logic_1164.all;
use IEEE.numeric_std.all;

entity Cpu is
  port(Clk, Reset : in std_logic;
       Mem_Write : out std_logic_vector(7 downto 0);
       Mem_Read : in std_logic_vector(7 downto 0);
       Mem_Addr : out std_logic_vector(15 downto 0);
       Mem_Write_Enable : out std_logic);
end Cpu;

architecture Cpu_Implementation of Cpu is
  -- General purpose registers
  signal A, B, C, D, E, F, H, L : std_logic_vector(7 downto 0) := X"00";
  -- Status register. Look at the ALU below.
  signal SR : std_logic_vector(7 downto 0) := X"00";
  -- Stack pointer and program counter
  signal SP, PC : std_logic_vector(15 downto 0);

  -- Exec2, 3 is used when an instruction requires more than one clock cycle.
  type State_Type is (Waiting, Fetch, Exec, Exec2, Exec3, Exec4);
  -- current state of the interpreter
  signal State : State_Type := Waiting;
  -- how long have we been waiting?
  signal Waited_Clks : std_logic_vector(15 downto 0) := X"0000";
  -- tmp variable for calculations on full addresses
  signal Tmp_Addr : std_logic_vector(15 downto 0);
  -- tmp variable for calculations on 8-bit stuff
  signal Tmp_8bit : std_logic_vector(7 downto 0);
  -- Instruction Register
  signal IR : std_logic_vector(7 downto 0);

begin

  -- 
  process(Clk)
    variable Tmp : std_logic_vector(15 downto 0);
    variable Tmp_Nibble : std_logic_vector(3 downto 0);
    variable Tmp_Byte : std_logic_vector(7 downto 0);
  begin
    if rising_edge(Clk) then
      if (Reset = '1') then
        Waited_Clks <= X"0000";
        State <= Waiting;
        Mem_Write_Enable <= '0';
        PC <= X"0150"; -- the first adress that we can work with
        SP <= X"FFFE"; -- see 3.2.4 at page 64
        A <= X"03";
        B <= X"00";
      else
        
        Waited_Clks <= std_logic_vector(unsigned(Waited_Clks) + 1);
        -- Each cycle, clear the write flag to the memory, to avoid
        -- unintentional writes to the memory.
        Mem_Write_Enable <= '0';

        case (State) is
          when Waiting =>
            if (unsigned(Waited_Clks) > 5) then
              State <= Fetch;
              Waited_Clks <= X"0000";
            end if;
          when Fetch =>
            Mem_Addr <= PC;
            State <= Exec;
            PC <= std_logic_vector(unsigned(PC) + 1);
          when Exec =>
            -- Set the state to Waiting first, so that
            -- if any instruction needs the Exec2 or Exec3 states
            -- they can safely set them anyway.
            State <= Waiting;
            IR <= Mem_Read;

            case (Mem_Read) is
              -- OP-codes from page 69 in GBCPUman.
              -- LD A, A (empty implementation since it does not do anything
              -- LD A, A
              when X"7F" =>
              -- LD A, B -t
              when X"78" =>
                B <= A;
              -- LD A, C
              when X"79" =>
                A <= C;
              --LD A, D
              when X"7A" =>
                A <= D;
              --LD A, E
              when X"7B" =>
                A <= E;
              -- LD A, H -t
              when X"7C" =>
                A <= H;
              -- LD A, L -t
              when X"7D" =>
                A <= L;
              -- LD A, (BC)
              when X"0A" =>
                Mem_Addr <= B & C;
                IR <= Mem_Read;
                State <= Exec2;
              -- LD A, (DE)
              when X"1A" =>
                Mem_Addr <= D & E;
                IR <= Mem_Read;
                State <= Exec2;
              -- LD A, (HL) -t
              when X"7E" =>
                Mem_Addr <= H & L;
                IR <= Mem_Read;
                State <= Exec2;
              -- LD A, (nn), two byte immediate value
              when X"FA" =>
                Mem_Addr <= PC;
                IR <= Mem_Read;
                PC <= std_logic_vector(unsigned(PC) + 1);
                State <= Exec2;
              -- LD A, # -t
              when X"3E" =>
                Mem_Addr <= PC;
                IR <= Mem_Read;
                PC <= std_logic_vector(unsigned(PC) + 1);
                State <= Exec2;
              -- LD B, A -t
              when X"47" =>
                B <= A;
              -- LD C, A -t
              when X"4F" =>
                C <= A;
              -- LD D, A -t
              when X"57" =>
                D <= A;
              -- LD E, A -t
              when X"5F" =>
                E <= A;
              -- LD H, A -t
              when X"67" =>
                H <= A;
              -- LD L, A -t
              when X"6F" =>
                L <= A;
              -- LD (BC), A -t
              when X"02" =>
                Mem_Addr <= B & C;
                Mem_Write <= A;
                Mem_Write_Enable <= '1';
              -- LD (DE), A
              when X"12" =>
                Mem_Addr <= D & E;
                Mem_Write <= A;
                Mem_Write_Enable <= '1';
              -- LD (HL), A -t
              when X"77" =>
                Mem_Addr <= H & L;
                Mem_Write <= A;
                Mem_Write_Enable <= '1';
                -- LD (nn), A
              when X"EA" =>
                Mem_Addr <= PC;
                IR <= Mem_Read;
                PC <= std_logic_vector(unsigned(PC) + 1);
                State <= Exec2;
                -- END op-codes from page 69 --
                -- OP-codes from page 70
                -- LD A,(C)
              when X"F2" =>
                IR <= Mem_Read;
                Mem_Addr <= std_logic_vector(unsigned (C) + X"FF00");
                State <= Exec2;
                -- LD(C),A
              when X"E2" =>
                Mem_Addr <= std_logic_vector(unsigned (C) + X"FF00");
                Mem_Write <= A;
                Mem_Write_Enable <= '1';
                -- LD A,(HL-)
              when X"3A" =>
                IR <= Mem_Read;
                Mem_Addr <= H & L;
                State <= Exec2;
                -- END of-codes from page 71

                -- OP-codes from page 66-67
                -- LD B, B -t
              when X"40" =>
                null;
                -- LD B, C -t
              when X"41" =>
                B <= C;
                -- LD B, D -t
              when X"42" =>
                B <= D;
                -- LD B, E -t
              when X"43" =>
                B <= E;
                -- LD B, H -t
              when X"44" =>
                B <= H;
                -- LD B, L -t
              when X"45" =>
                B <= L;
                -- LD B, (HL) -t
              when X"46" =>
                Mem_Addr <= H & L;
                State <= Exec2;
                -- LD C, B -t
              when X"48" =>
                C <= B;
                -- LD C, C -t
              when X"49" =>
                null;
                -- LD C, D -t
              when X"4A" =>
                C <= D;
                -- LD C, E -t
              when X"4B" =>
                C <= E;
                -- LD C, H -t
              when X"4C" =>
                C <= H;
                -- LD C, L -t
              when X"4D" =>
                C <= L;
                -- LD C, (HL) -t
              when X"4E" =>
                Mem_Addr <= H & L;
                State <= Exec2;
                -- LD D, B -t
              when X"50" =>
                D <= B;
                -- LD D, C -t
              when X"51" =>
                D <= C;
                -- LD D, D -t
              when X"52" =>
                null;
                -- LD D, E -t
              when X"53" =>
                D <= E;
                -- LD D, H -t
              when X"54" =>
                D <= H;
                -- LD D, L -t
              when X"55" =>
                D <= L;
                -- LD D, (HL) -t
              when X"56" =>
                Mem_Addr <= H & L;
                State <= Exec2;
                -- LD E, B -t
              when X"58" =>
                E <= B;
                -- LD E, C -t
              when X"59" =>
                E <= C;
                -- LD E, D -t
              when X"5A" =>
                E <= D;
                -- LD E, E -t
              when X"5B" =>
                null;
                -- LD E, H -t
              when X"5C" =>
                E <= H;
                -- LD E, L -t
              when X"5D" =>
                E <= L;
                -- LD E, (HL) -t
              when X"5E" =>
                Mem_Addr <= H & L;
                State <= Exec2;
                -- LD H, B -t
              when X"60" =>
                H <= B;
                -- LD H, C -t
              when X"61" =>
                H <= C;
                -- LD H, D -t
              when X"62" =>
                H <= D;
                -- LD H, E -t
              when X"63" =>
                H <= E;
                -- LD H, H -t
              when X"64" =>
                null;
                -- LD H, L -t
              when X"65" =>
                H <= L;
                -- LD, H, (HL)
              when X"66" =>
                Mem_Addr <= H & L;
                State <= Exec2;
                -- LD L, B -t
              when X"68" =>
                L <= B;
                -- LD L, C -t
              when X"69" =>
                L <= C;
                -- LD L, D -t
              when X"6A" =>
                L <= D;
                -- LD L, E -t
              when X"6B" =>
                L <= E;
                -- LD L, H -t
              when X"6C" =>
                L <= H;
                -- LD L, L -t
              when X"6D" =>
                null;
                -- LD L, (HL) -t
              when X"6E" =>
                Mem_Addr <= H & L;
                State <= Exec2;
                -- LD (HL), B -t
              when X"70" =>
                Mem_Addr <= H & L;
                Mem_Write <= B;
                Mem_Write_Enable <= '1';
                -- LD (HL), C -t
              when X"71" =>
                Mem_Addr <= H & L;
                Mem_Write <= C;
                Mem_Write_Enable <= '1';
                -- LD (HL), D -t
              when X"72" =>
                Mem_Addr <= H & L;
                Mem_Write <= B;
                Mem_Write_Enable <= '1';
                -- LD (HL), E -t
              when X"73" =>
                Mem_Addr <= H & L;
                Mem_Write <= B;
                Mem_Write_Enable <= '1';
                -- LD (HL), H
              when X"74" =>
                Mem_Addr <= H & L;
                Mem_Write <= B;
                Mem_Write_Enable <= '1';
                -- LD (HL), L
              when X"75" =>
                Mem_Addr <= H & L;
                Mem_Write <= B;
                Mem_Write_Enable <= '1';
                -- LD (HL), n
              when X"76" =>
                Mem_Addr <= PC;
                PC <= std_logic_vector(unsigned(PC) + 1);
                State <= Exec2;
                -- END op-codes from page 66-67
                -- OP-code from page 73
                -- LD A, (HL+)
              when X"2A" =>
                Mem_Addr <= H & L;
                State <= Exec2;
                Tmp := std_logic_vector(unsigned(H & L) + 1);
                H <= Tmp(15 downto 8);
                L <= Tmp(7 downto 0);
                -- OP-code from page 74
                -- LD (HL+), A
              when X"22" =>
                Mem_Addr <= H & L;
                Mem_Write_Enable <= '1';
                Tmp := std_logic_vector(unsigned(H & L) + 1);
                Mem_Write <= A;
                -- OP-codes from page 75
                -- LD ($FF00+n), A
              when X"E0" =>
                Mem_Addr <= PC;
                PC <= std_logic_vector(unsigned(PC) + 1);
                State <= Exec2;
                -- LD A, ($FF00+n)
              when X"F0" =>
                Mem_Addr <= PC;
                PC <= std_logic_vector(unsigned(PC) + 1);
                State <= Exec2;
                -- END op-codes from page 75
                -- OP-codes from page 76
                -- LD BC,nn
              when X"01" =>
                Mem_Addr <= PC;
                PC <= std_logic_vector(unsigned(PC) + 1);
                State <= Exec2;
                -- LD DE,nn
              when X"11" =>
                Mem_Addr <= PC;
                PC <= std_logic_vector(unsigned(PC) + 1);
                State <= Exec2;
                -- LD HL,nn
              when X"21" =>
                Mem_Addr <= PC;
                PC <= std_logic_vector(unsigned(PC) + 1);
                State <= Exec2;
                -- LD SP,nn
              when X"31" =>
                Mem_Addr <= PC;
                PC <= std_logic_vector(unsigned(PC) + 1);
                State <= Exec2;
                -- LD SP, HL
              when X"F9" =>
                SP <= H & L;
                -- END op-codes from page 76
                
              when others =>
                --FAKKA UR TOTALT OCH D
            end case; -- End case (Mem_Read)
          when Exec2 =>
            State <= Waiting;
            case (IR) is
              -- LD A,(C)
              when X"F2" =>
                A <= Mem_Read;
              -- LD A, (BC)
              when X"0A" =>
                A <= Mem_Read;
              -- LD A, (DE)
              when X"1A" =>
                A <= Mem_Read;
              -- LD A, (HL)
              when X"7E" =>
                A <= Mem_Read;
              -- LD A, (nn), two byte immediate value
              when X"FA" =>
                Tmp_Addr(7 downto 0) <= Mem_Read;
                Mem_Addr <= PC;
                IR <= X"FA";
                PC <= std_logic_vector(unsigned(PC) + 1);
                State <= Exec3;
              -- LD A, #
              when X"3E" =>
                A <= Mem_Read;
              -- LD A,(HL-)
              when X"3A" =>
                A <= Mem_Read;
                tmp := std_logic_vector(unsigned(H & L) - X"0001");
                H <= tmp(15 downto 8);
                L <= tmp(7 downto 0);
              -- LD (nn), A
              when X"EA" =>
                Tmp_8Bit <= Mem_Read;
                Mem_Addr <= PC;
                PC <= std_logic_vector(unsigned(PC) + 1);
                State <= Exec3;
                -- LD B, (HL) -t
              when X"46" =>
                B <= Mem_Read;
                -- LD C, (HL)
              when X"4E" =>
                C <= Mem_Read;
                -- LD D, (HL)
              when X"56" =>
                D <= Mem_Read;
                -- LD E, (HL)
              when X"5E" =>
                E <= Mem_Read;
                -- LD, H, (HL) -t
              when X"66" =>
                H <= Mem_Read;
                -- LD L, (HL)
              when X"6E" =>
                L <= Mem_Read;
                -- LD (HL), n
              when X"76" =>
                Mem_Write <= Mem_Read;
                Mem_Addr <= H & L;
                -- LD A, (HL+)
              when X"2A" =>
                A <= Mem_Read;
                -- LD ($FF00+n), A
              when X"E0" =>
                Mem_Write_Enable <= '1';
                Mem_Write <= A;
                Mem_Addr <= std_logic_vector(unsigned(Mem_Read) + X"FF00");
                -- LD A, ($FF00+n)
              when X"F0" =>
                Mem_Addr <= std_logic_vector(unsigned(Mem_Read) + X"FF00");
                State <= Exec3;
                -- LD BC, nn
              when X"01" =>
                C <= Mem_Read;
                Mem_Addr <= PC;
                PC <= std_logic_vector(unsigned(PC) + 1);
                State <= Exec3;
                -- LD DE, nn
              when X"11" =>
                E <= Mem_Read;
                Mem_Addr <= PC;
                PC <= std_logic_vector(unsigned(PC) + 1);
                State <= Exec3;
                -- LD HL, nn
              when X"21" =>
                L <= Mem_Read;
                Mem_Addr <= PC;
                PC <= std_logic_vector(unsigned(PC) + 1);
                State <= Exec3;
                -- LD SP, nn
              when X"31" =>
                SP(7 downto 0) <= Mem_Read;
                Mem_Addr <= PC;
                PC <= std_logic_vector(unsigned(PC) + 1);
                State <= Exec3;
              when others =>
            end case; -- End case Exec2
          when Exec3 =>
            State <= Waiting;
            case (IR) is
              -- LD A, (nn), two byte immediate value
              when X"FA" =>
                Mem_Addr <= Mem_Read & Tmp_Addr(7 downto 0);
                State <= Exec4;
              -- LD (nn), A
              when X"EA" =>
                Mem_Addr <= Mem_Read & Tmp_8Bit;
                Mem_Write <= A;
                Mem_Write_Enable <= '1';
                -- LD A, ($FF00+n)
              when X"F0" =>
                A <= Mem_Read;
                -- LD BC, nn
              when X"01" =>
                B <= Mem_Read;
                -- LD DE, nn
              when X"11" =>
                D <= Mem_Read;
                -- LD HL, nn
              when X"21" =>
                H <= Mem_Read;
                -- LD SP, nn
              when X"31" =>
                SP(15 downto 8) <= Mem_Read;

              when others =>
            end case; -- End case Exec3

          when Exec4 =>
            State <= Waiting;
            case (IR) is
              -- LD A, nn, two byte immediate value
              when X"FA" =>
                A <= Mem_Read;
              when others =>
            end case;
          when others =>
        end case; -- End case State 
      end if;
    end if;
  end process;
  

end Cpu_Implementation;
