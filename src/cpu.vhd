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
                State <= Exec2;
              -- LD A, (DE)
              when X"1A" =>
                Mem_Addr <= D & E;
                State <= Exec2;
              -- LD A, (HL)
              when X"7E" =>
                Mem_Addr <= H & L;
                State <= Exec2;
              -- LD A, (nn), two byte immediate value
              when X"FA" =>
                Mem_Addr <= PC;
                PC <= std_logic_vector(unsigned(PC) + 1);
                State <= Exec2;
              -- LD A, #
              when X"3E" =>
                Mem_Addr <= PC;
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
