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
  -- Status register
  signal SR : std_logic_vector(7 downto 0);
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
    variable tmp : std_logic_vector(15 downto 0);
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

            case (Mem_Read) is
              -- OP-codes from page 69 in GBCPUman.
              -- LD A, A (empty implementation since it does not do anything
              -- LD A, A
              when X"7F" =>
              -- LD A, B
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
              -- LD A, H
              when X"7C" =>
                A <= H;
              -- LD A, L
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
              -- LD A, (HL)
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
              -- LD A, #
              when X"3E" =>
                Mem_Addr <= PC;
                IR <= Mem_Read;
                PC <= std_logic_vector(unsigned(PC) + 1);
                State <= Exec2;
              -- LD B, A
              when X"47" =>
                B <= A;
              -- LD C, A
              when X"4F" =>
                C <= A;
              -- LD D, A
              when X"57" =>
                D <= A;
              -- LD E, A
              when X"5F" =>
                E <= A;
              -- LD H, A
              when X"67" =>
                H <= A;
              -- LD L, A
              when X"6F" =>
                L <= A;
              -- LD (BC), A
              when X"02" =>
                Mem_Addr <= B & C;
                Mem_Write <= A;
                Mem_Write_Enable <= '1';
              -- LD (DE), A
              when X"12" =>
                Mem_Addr <= D & E;
                Mem_Write <= A;
                Mem_Write_Enable <= '1';
              -- LD (HL), A
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
                -- LD B, B
              when X"40" =>
                null;
                -- LD B, C
              when X"41" =>
                B <= C;
                -- LD B, D
              when X"42" =>
                B <= D;
                -- LD B, E
              when X"43" =>
                B <= E;
                -- LD B, H
              when X"44" =>
                B <= H;
                -- LD B, L
              when X"45" =>
                B <= L;
                -- LD B, (HL)
              when X"46" =>
                Mem_Addr <= H & L;
                State <= Exec2;
                -- LD C, B
              when X"48" =>
                C <= B;
                -- LD C, C
              when X"49" =>
                null;
                -- LD C, D
              when X"4A" =>
                C <= D;
                -- LD C, E
              when X"4B" =>
                C <= E;
                -- LD C, H
              when X"4C" =>
                C <= H;
                -- LD C, L
              when X"4D" =>
                C <= L;
                -- LD C, (HL)
              when X"4E" =>
                Mem_Addr <= H & L;
                State <= Exec2;
                -- LD D, B
              when X"50" =>
                D <= B;
                -- LD D, C
              when X"51" =>
                D <= C;
                -- LD D, D
              when X"52" =>
                null;
                -- LD D, E
              when X"53" =>
                D <= E;
                -- LD D, H
              when X"54" =>
                D <= H;
                -- LD D, L
              when X"55" =>
                D <= L;
                -- LD D, (HL)
              when X"56" =>
                Mem_Addr <= H & L;
                State <= Exec2;
                -- LD E, B
              when X"58" =>
                E <= B;
                -- LD E, C
              when X"59" =>
                E <= C;
                -- LD E, D
              when X"5A" =>
                E <= D;
                -- LD E, E
              when X"5B" =>
                null;
                -- LD E, H
              when X"5C" =>
                E <= H;
                -- LD E, L
              when X"5D" =>
                E <= L;
                -- LD E, (HL)
              when X"5E" =>
                Mem_Addr <= H & L;
                State <= Exec2;
                -- LD H, B
              when X"60" =>
                H <= B;
                -- LD H, C
              when X"61" =>
                H <= C;
                -- LD H, D
              when X"62" =>
                H <= D;
                -- LD H, E
              when X"63" =>
                H <= E;
                -- LD H, H
              when X"64" =>
                null;
                -- LD H, L
              when X"65" =>
                H <= L;
                -- LD, H, (HL)
              when X"66" =>
                Mem_Addr <= H & L;
                State <= Exec2;
                -- LD L, B
              when X"68" =>
                L <= B;
                -- LD L, C
              when X"69" =>
                L <= C;
                -- LD L, D
              when X"6A" =>
                L <= D;
                -- LD L, E
              when X"6B" =>
                L <= E;
                -- LD L, H
              when X"6C" =>
                L <= H;
                -- LD L, L
              when X"6D" =>
                null;
                -- LD L, (HL)
              when X"6E" =>
                Mem_Addr <= H & L;
                State <= Exec2;
                -- LD (HL), B
              when X"70" =>
                Mem_Addr <= H & L;
                Mem_Write <= B;
                Mem_Write_Enable <= '1';
                -- LD (HL), C
              when X"71" =>
                Mem_Addr <= H & L;
                Mem_Write <= C;
                Mem_Write_Enable <= '1';
                -- LD (HL), D
              when X"72" =>
                Mem_Addr <= H & L;
                Mem_Write <= B;
                Mem_Write_Enable <= '1';
                -- LD (HL), E
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
                -- LD B, (HL)
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
                -- LD, H, (HL)
              when X"66" =>
                H <= Mem_Read;
                -- LD L, (HL)
              when X"6E" =>
                L <= Mem_Read;
                -- LD (HL), n
              when X"76" =>
                Mem_Write <= Mem_Read;
                Mem_Addr <= H & L;
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
