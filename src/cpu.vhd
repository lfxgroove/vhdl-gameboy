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
  -- General purpose registers. The F register is the flags register.
  signal A, B, C, D, E, F, H, L : std_logic_vector(7 downto 0) := X"00";
  -- Stack pointer and program counter
  signal SP, PC : std_logic_vector(15 downto 0) := X"0000";

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

  -- ALU instantiation.
  component Alu
    port(A, B : in std_logic_vector(15 downto 0);
         Mode : in std_logic_vector(2 downto 0);
         Flags_In : in std_logic_vector(7 downto 0);
         Result : out std_logic_vector(15 downto 0);
         Flags : out std_logic_vector(7 downto 0));
  end component;

  -- Signals to the ALU
  signal Alu_A, Alu_B, Alu_Result : std_logic_vector(15 downto 0);
  signal Alu_Flags_In : std_logic_vector(7 downto 0);
  signal Alu_Mode : std_logic_vector(2 downto 0);
  signal Alu_Flags : std_logic_vector(7 downto 0);
  -- Modes for the alu.
  constant Alu_Add : std_logic_vector(2 downto 0) := "000";
  constant Alu_Sub : std_logic_vector(2 downto 0) := "001";
  constant Alu_Add_Carry : std_logic_vector(2 downto 0) := "010";
  constant Alu_Sub_Carry : std_logic_vector(2 downto 0) := "011";
  constant Alu_And : std_logic_vector(2 downto 0) := "100";
  constant Alu_Or : std_logic_vector(2 downto 0) := "101";
  constant Alu_Xor : std_logic_vector(2 downto 0) := "110";
begin

  Alu_Ports : Alu port map(
    A => Alu_A,
    B => Alu_B,
    Mode => Alu_Mode,
    Flags_In => Alu_Flags_In,
    Result => Alu_Result,
    Flags => Alu_Flags);

  -- 
  process(Clk)
    variable Tmp : std_logic_vector(15 downto 0);
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
              -- LD A, A -t
              when X"7F" =>
              -- LD A, B -t
              when X"78" =>
                B <= A;
              -- LD A, C -t
              when X"79" =>
                A <= C;
              --LD A, D -t
              when X"7A" =>
                A <= D;
              --LD A, E -t
              when X"7B" =>
                A <= E;
              -- LD A, H -t
              when X"7C" =>
                A <= H;
              -- LD A, L -t
              when X"7D" =>
                A <= L;
              -- LD A, (BC) -t
              when X"0A" =>
                Mem_Addr <= B & C;
                IR <= Mem_Read;
                State <= Exec2;
              -- LD A, (DE) -t
              when X"1A" =>
                Mem_Addr <= D & E;
                IR <= Mem_Read;
                State <= Exec2;
              -- LD A, (HL) -t
              when X"7E" =>
                Mem_Addr <= H & L;
                IR <= Mem_Read;
                State <= Exec2;
              -- LD A, (nn) -t
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
              -- LD (DE), A -t
              when X"12" =>
                Mem_Addr <= D & E;
                Mem_Write <= A;
                Mem_Write_Enable <= '1';
              -- LD (HL), A -t
              when X"77" =>
                Mem_Addr <= H & L;
                Mem_Write <= A;
                Mem_Write_Enable <= '1';
                -- LD (nn), A -t
              when X"EA" =>
                Mem_Addr <= PC;
                IR <= Mem_Read;
                PC <= std_logic_vector(unsigned(PC) + 1);
                State <= Exec2;
                -- END op-codes from page 69 --
                -- OP-codes from page 70
                -- LD A,(C+$FF00) -t
              when X"F2" =>
                IR <= Mem_Read;
                Mem_Addr <= std_logic_vector(unsigned (C) + X"FF00");
                State <= Exec2;
                -- LD(C+$FF00),A
              when X"E2" =>
                Mem_Addr <= std_logic_vector(unsigned (C) + X"FF00");
                Mem_Write <= A;
                Mem_Write_Enable <= '1';
                -- LD A,(HL-) -t
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
                -- LD, H, (HL) -t
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
                -- LD (HL), H -t
              when X"74" =>
                Mem_Addr <= H & L;
                Mem_Write <= B;
                Mem_Write_Enable <= '1';
                -- LD (HL), L -t
              when X"75" =>
                Mem_Addr <= H & L;
                Mem_Write <= B;
                Mem_Write_Enable <= '1';
                -- LD (HL), n -t
              when X"76" =>
                Mem_Addr <= PC;
                PC <= std_logic_vector(unsigned(PC) + 1);
                State <= Exec2;
                -- END op-codes from page 66-67
                -- OP-code from page 73
                -- LD A, (HL+) -t
              when X"2A" =>
                Mem_Addr <= H & L;
                State <= Exec2;
                Tmp := std_logic_vector(unsigned(H & L) + 1);
                H <= Tmp(15 downto 8);
                L <= Tmp(7 downto 0);
                -- OP-code from page 74
                -- LD (HL+), A -t
              when X"22" =>
                Mem_Addr <= H & L;
                Mem_Write_Enable <= '1';
                Tmp := std_logic_vector(unsigned(H & L) + 1);
                Mem_Write <= A;
                -- OP-codes from page 75
                -- LD ($FF00+n), A -t
              when X"E0" =>
                Mem_Addr <= PC;
                PC <= std_logic_vector(unsigned(PC) + 1);
                State <= Exec2;
                -- LD A, ($FF00+n) -t
              when X"F0" =>
                Mem_Addr <= PC;
                PC <= std_logic_vector(unsigned(PC) + 1);
                State <= Exec2;
                -- END op-codes from page 75
                -- OP-codes from page 76
                -- LD BC,nn -t
              when X"01" =>
                Mem_Addr <= PC;
                PC <= std_logic_vector(unsigned(PC) + 1);
                State <= Exec2;
                -- LD DE,nn -t
              when X"11" =>
                Mem_Addr <= PC;
                PC <= std_logic_vector(unsigned(PC) + 1);
                State <= Exec2;
                -- LD HL,nn -t
              when X"21" =>
                Mem_Addr <= PC;
                PC <= std_logic_vector(unsigned(PC) + 1);
                State <= Exec2;
                -- LD SP,nn -t
              when X"31" =>
                Mem_Addr <= PC;
                PC <= std_logic_vector(unsigned(PC) + 1);
                State <= Exec2;
                -- LD SP, HL -t
              when X"F9" =>
                SP <= H & L;
                -- END op-codes from page 76
                -- OP code from page 77
                -- LD HL, SP+n -t
              when X"F8" =>
                Mem_Addr <= PC;
                PC <= std_logic_vector(unsigned(PC) + 1);
                State <= Exec2;
                -- OP codes from page 78
                -- LD (nn), SP -t
              when X"08" =>
                Mem_Addr <= PC;
                PC <= std_logic_vector(unsigned(PC) + 1);
                State <= Exec2;
                -- PUSH AF
              when X"F5" =>
                Tmp := std_logic_vector(unsigned(SP) - 1);
                Mem_Write <= A;
                Mem_Addr <= Tmp;
                SP <= Tmp;
                State <= Exec2;
                -- PUSH BC -t
              when X"C5" =>
                Tmp := std_logic_vector(unsigned(SP) - 1);
                Mem_Write <= B;
                Mem_Addr <= Tmp;
                SP <= Tmp;
                State <= Exec2;
                -- PUSH DE -t
              when X"D5" =>
                Tmp := std_logic_vector(unsigned(SP) - 1);
                Mem_Write <= D;
                Mem_Addr <= Tmp;
                SP <= Tmp;
                State <= Exec2;
                -- PUSH HL -t
              when X"E5" =>
                Tmp := std_logic_vector(unsigned(SP) - 1);
                Mem_Write <= H;
                Mem_Addr <= Tmp;
                SP <= Tmp;
                State <= Exec2;
                -- END op-codes from page 78
                -- OP-codes from page 79
                -- POP AF
              when X"F1" =>
                Mem_Addr <= SP;
                SP <= std_logic_vector(unsigned(SP) + 1);
                State <= Exec2;
                -- POP BC -t
              when X"C1" =>
                Mem_Addr <= SP;
                SP <= std_logic_vector(unsigned(SP) + 1);
                State <= Exec2;
                -- POP DE -t
              when X"D1" =>
                Mem_Addr <= SP;
                SP <= std_logic_vector(unsigned(SP) + 1);
                State <= Exec2;
                -- POP HL -t
              when X"E1" =>
                Mem_Addr <= SP;
                SP <= std_logic_vector(unsigned(SP) + 1);
                State <= Exec2;
                -- END op-codes from page 79
                -- OP-codes from page 80
                -- ADD A, A -t
              when X"87" =>
                Alu_A <= X"00" & A;
                Alu_B <= X"00" & A;
                Alu_Mode <= Alu_Add;
                State <= Exec2;
                -- ADD A, B -t
              when X"80" =>
                Alu_A <= X"00" & A;
                Alu_B <= X"00" & B;
                Alu_Mode <= Alu_Add;
                State <= Exec2;
                -- ADD A, C -t
              when X"81" =>
                Alu_A <= X"00" & A;
                Alu_B <= X"00" & C;
                Alu_Mode <= Alu_Add;
                State <= Exec2;
                -- ADD A, D -t
              when X"82" =>
                Alu_A <= X"00" & A;
                Alu_B <= X"00" & D;
                Alu_Mode <= Alu_Add;
                State <= Exec2;
                -- ADD A, E -t
              when X"83" =>
                Alu_A <= X"00" & A;
                Alu_B <= X"00" & E;
                Alu_Mode <= Alu_Add;
                State <= Exec2;
                -- ADD A, H -t
              when X"84" =>
                Alu_A <= X"00" & A;
                Alu_B <= X"00" & H;
                Alu_Mode <= Alu_Add;
                State <= Exec2;
                -- ADD A, L -t
              when X"85" =>
                Alu_A <= X"00" & A;
                Alu_B <= X"00" & L;
                Alu_Mode <= Alu_Add;
                State <= Exec2;
                -- Add A, (HL) -t
              when X"86" =>
                Mem_Addr <= H & L;
                State <= Exec2;
                -- Add A, # -t
              when X"C6" =>
                Mem_Addr <= PC;
                PC <= std_logic_vector(unsigned(PC) + 1);
                State <= Exec2;
                -- END op-codes from page 80
                -- OP-codes from page 81
                -- ADC A, A -t
              when X"8F" =>
                Alu_A <= X"00" & A;
                Alu_B <= X"00" & A;
                Alu_Mode <= Alu_Add_Carry;
                Alu_Flags_In <= F;
                State <= Exec2;
                -- ADC A, B -tested - tested more in detail than 89-8f
              when X"88" =>
                Alu_A <= X"00" & A;
                Alu_B <= X"00" & B;
                Alu_Mode <= Alu_Add_Carry;
                Alu_Flags_In <= F;
                State <= Exec2;
                -- ADC A, C -t
              when X"89" =>
                Alu_A <= X"00" & A;
                Alu_B <= X"00" & C;
                Alu_Mode <= Alu_Add_Carry;
                Alu_Flags_In <= F;
                State <= Exec2;
                -- ADC A, D -t
              when X"8A" =>
                Alu_A <= X"00" & A;
                Alu_B <= X"00" & D;
                Alu_Mode <= Alu_Add_Carry;
                Alu_Flags_In <= F;
                State <= Exec2;
                -- ADC A, E -t
              when X"8B" =>
                Alu_A <= X"00" & A;
                Alu_B <= X"00" & E;
                Alu_Mode <= Alu_Add_Carry;
                Alu_Flags_In <= F;
                State <= Exec2;
                -- ADC A, H -t
              when X"8C" =>
                Alu_A <= X"00" & A;
                Alu_B <= X"00" & H;
                Alu_Mode <= Alu_Add_Carry;
                Alu_Flags_In <= F;
                State <= Exec2;
                -- ADC A, L -t
              when X"8D" =>
                Alu_A <= X"00" & A;
                Alu_B <= X"00" & L;
                Alu_Mode <= Alu_Add_Carry;
                Alu_Flags_In <= F;
                State <= Exec2;
                -- ADC A, (HL) -t
              when X"8E" =>
                Mem_Addr <= H & L;
                State <= Exec2;
                -- ADC A, # -t
              when X"CE" =>
                Mem_Addr <= PC;
                PC <= std_logic_vector(unsigned(PC) + 1);
                State <= Exec2;
                -- END op-codes from page 81
                -- OP-codes from page 82
                -- SUB A, A -t
              when X"97" =>
                Alu_A <= X"00" & A;
                Alu_B <= X"00" & A;
                Alu_Mode <= Alu_Sub;
                State <= Exec2;
                -- SUB A, B -t
              when X"90" =>
                Alu_A <= X"00" & A;
                Alu_B <= X"00" & B;
                Alu_Mode <= Alu_Sub;
                State <= Exec2;
                -- SUB A, C -t
              when X"91" =>
                Alu_A <= X"00" & A;
                Alu_B <= X"00" & C;
                Alu_Mode <= Alu_Sub;
                State <= Exec2;
                -- SUB A, D -t
              when X"92" =>
                Alu_A <= X"00" & A;
                Alu_B <= X"00" & D;
                Alu_Mode <= Alu_Sub;
                State <= Exec2;
                -- SUB A, E -t
              when X"93" =>
                Alu_A <= X"00" & A;
                Alu_B <= X"00" & E;
                Alu_Mode <= Alu_Sub;
                State <= Exec2;
                -- SUB A, H -t
              when X"94" =>
                Alu_A <= X"00" & A;
                Alu_B <= X"00" & H;
                Alu_Mode <= Alu_Sub;
                State <= Exec2;
                -- SUB A, L -t
              when X"95" =>
                Alu_A <= X"00" & A;
                Alu_B <= X"00" & L;
                Alu_Mode <= Alu_Sub;
                State <= Exec2;
                -- SUB A, (HL) -t
              when X"96" =>
                Mem_Addr <= H & L;
                State <= Exec2;
                -- SUB A, # -t
              when X"D6" =>
                Mem_Addr <= PC;
                PC <= std_logic_vector(unsigned(PC) + 1);
                State <= Exec2;
                -- END op-codes from page 82
                -- OP-codes from page 83
                -- SBC A, A
              when X"9F" =>
                Alu_A <= X"00" & A;
                Alu_B <= X"00" & A;
                Alu_Mode <= Alu_Sub_Carry;
                Alu_Flags_In <= F;
                State <= Exec2;
                -- SBC A, B
              when X"98" =>
                Alu_A <= X"00" & A;
                Alu_B <= X"00" & B;
                Alu_Mode <= Alu_Sub_Carry;
                Alu_Flags_In <= F;
                State <= Exec2;
                -- SBC A, C
              when X"99" =>
                Alu_A <= X"00" & A;
                Alu_B <= X"00" & C;
                Alu_Mode <= Alu_Sub_Carry;
                Alu_Flags_In <= F;
                State <= Exec2;
                -- SBC A, D
              when X"9A" =>
                Alu_A <= X"00" & A;
                Alu_B <= X"00" & D;
                Alu_Mode <= Alu_Sub_Carry;
                Alu_Flags_In <= F;
                State <= Exec2;
                -- SBC A, E
              when X"9B" =>
                Alu_A <= X"00" & A;
                Alu_B <= X"00" & E;
                Alu_Mode <= Alu_Sub_Carry;
                Alu_Flags_In <= F;
                State <= Exec2;
                -- SBC A, H
              when X"9C" =>
                Alu_A <= X"00" & A;
                Alu_B <= X"00" & H;
                Alu_Mode <= Alu_Sub_Carry;
                Alu_Flags_In <= F;
                State <= Exec2;
                -- SBC A, L
              when X"9D" =>
                Alu_A <= X"00" & A;
                Alu_B <= X"00" & L;
                Alu_Mode <= Alu_Sub_Carry;
                Alu_Flags_In <= F;
                State <= Exec2;
                -- SBC A, (HL)
              when X"9E" =>
                Mem_Addr <= H & L;
                State <= Exec2;
                -- SBC A, #
              when X"DE" =>
                Mem_Addr <= PC;
                PC <= std_logic_vector(unsigned(PC) + 1);
                State <= Exec2;
                -- END op-codes from page 83
                -- OP-codes from page 84
                -- AND A, A
              when X"A7" =>
                Alu_A <= X"00" & A;
                Alu_B <= X"00" & A;
                Alu_Mode <= Alu_And;
                State <= Exec2;
                -- AND A, B
              when X"A0" =>
                Alu_A <= X"00" & A;
                Alu_B <= X"00" & B;
                Alu_Mode <= Alu_And;
                State <= Exec2;
                -- AND A, C
              when X"A1" =>
                Alu_A <= X"00" & A;
                Alu_B <= X"00" & C;
                Alu_Mode <= Alu_And;
                State <= Exec2;
                -- AND A, D
              when X"A2" =>
                Alu_A <= X"00" & A;
                Alu_B <= X"00" & D;
                Alu_Mode <= Alu_And;
                State <= Exec2;
                -- AND A, E
              when X"A3" =>
                Alu_A <= X"00" & A;
                Alu_B <= X"00" & E;
                Alu_Mode <= Alu_And;
                State <= Exec2;
                -- AND A, H
              when X"A4" =>
                Alu_A <= X"00" & A;
                Alu_B <= X"00" & H;
                Alu_Mode <= Alu_And;
                State <= Exec2;
                -- AND A, L
              when X"A5" =>
                Alu_A <= X"00" & A;
                Alu_B <= X"00" & L;
                Alu_Mode <= Alu_And;
                State <= Exec2;
                -- AND A, (HL)
              when X"A6" =>
                Mem_Addr <= H & L;
                State <= Exec2;
                -- AND A, #
              when X"E6" =>
                Mem_Addr <= PC;
                PC <= std_logic_vector(unsigned(PC) + 1);
                State <= Exec2;
                -- END op-codes from page 84
                -- OP-codes from page 85
                -- OR A, A
              when X"B7" =>
                Alu_A <= X"00" & A;
                Alu_B <= X"00" & A;
                Alu_Mode <= Alu_Or;
                State <= Exec2;
                -- OR A, B
              when X"B0" =>
                Alu_A <= X"00" & A;
                Alu_B <= X"00" & B;
                Alu_Mode <= Alu_Or;
                State <= Exec2;
                -- OR A, C
              when X"B1" =>
                Alu_A <= X"00" & A;
                Alu_B <= X"00" & C;
                Alu_Mode <= Alu_Or;
                State <= Exec2;
                -- OR A, D
              when X"B2" =>
                Alu_A <= X"00" & A;
                Alu_B <= X"00" & D;
                Alu_Mode <= Alu_Or;
                State <= Exec2;
                -- OR A, E
              when X"B3" =>
                Alu_A <= X"00" & A;
                Alu_B <= X"00" & E;
                Alu_Mode <= Alu_Or;
                State <= Exec2;
                -- OR A, H
              when X"B4" =>
                Alu_A <= X"00" & A;
                Alu_B <= X"00" & H;
                Alu_Mode <= Alu_Or;
                State <= Exec2;
                -- OR A, L
              when X"B5" =>
                Alu_A <= X"00" & A;
                Alu_B <= X"00" & L;
                Alu_Mode <= Alu_Or;
                State <= Exec2;
                -- OR A, (HL)
              when X"B6" =>
                Mem_Addr <= H & L;
                State <= Exec2;
                -- OR A, #
              when X"F6" =>
                Mem_Addr <= PC;
                PC <= std_logic_vector(unsigned(PC) + 1);
                State <= Exec2;
                -- END op-codes from page 85
                -- OP-codes from page 86
                -- XOR A, A
              when X"AF" =>
                Alu_A <= X"00" & A;
                Alu_B <= X"00" & A;
                Alu_Mode <= Alu_Xor;
                State <= Exec2;
                -- XOR A, B
              when X"A8" =>
                Alu_A <= X"00" & A;
                Alu_B <= X"00" & B;
                Alu_Mode <= Alu_Xor;
                State <= Exec2;
                -- XOR A, C
              when X"A9" =>
                Alu_A <= X"00" & A;
                Alu_B <= X"00" & C;
                Alu_Mode <= Alu_Xor;
                State <= Exec2;
                -- XOR A, D
              when X"AA" =>
                Alu_A <= X"00" & A;
                Alu_B <= X"00" & D;
                Alu_Mode <= Alu_Xor;
                State <= Exec2;
                -- XOR A, E
              when X"AB" =>
                Alu_A <= X"00" & A;
                Alu_B <= X"00" & E;
                Alu_Mode <= Alu_Xor;
                State <= Exec2;
                -- XOR A, H
              when X"AC" =>
                Alu_A <= X"00" & A;
                Alu_B <= X"00" & H;
                Alu_Mode <= Alu_Xor;
                State <= Exec2;
                -- XOR A, L
              when X"AD" =>
                Alu_A <= X"00" & A;
                Alu_B <= X"00" & L;
                Alu_Mode <= Alu_Xor;
                State <= Exec2;
                -- XOR A, (HL)
              when X"AE" =>
                Mem_Addr <= H & L;
                State <= Exec2;
                -- XOR A, #
              when X"EE" =>
                Mem_Addr <= PC;
                PC <= std_logic_vector(unsigned(PC) + 1);
                State <= Exec2;
                -- END op-codes from page 86
                -- OP-codes from page 87
                -- CP A, A
              when X"BF" =>
                Alu_A <= X"00" & A;
                Alu_B <= X"00" & A;
                Alu_Mode <= Alu_Sub;
                State <= Exec2;
                -- CP A, B
              when X"B8" =>
                Alu_A <= X"00" & A;
                Alu_B <= X"00" & B;
                Alu_Mode <= Alu_Sub;
                State <= Exec2;
                -- CP A, C
              when X"B9" =>
                Alu_A <= X"00" & A;
                Alu_B <= X"00" & C;
                Alu_Mode <= Alu_Sub;
                State <= Exec2;
                -- CP A, D
              when X"BA" =>
                Alu_A <= X"00" & A;
                Alu_B <= X"00" & D;
                Alu_Mode <= Alu_Sub;
                State <= Exec2;
                -- CP A, E
              when X"BB" =>
                Alu_A <= X"00" & A;
                Alu_B <= X"00" & E;
                Alu_Mode <= Alu_Sub;
                State <= Exec2;
                -- CP A, H
              when X"BC" =>
                Alu_A <= X"00" & A;
                Alu_B <= X"00" & H;
                Alu_Mode <= Alu_Sub;
                State <= Exec2;
                -- CP A, L
              when X"BD" =>
                Alu_A <= X"00" & A;
                Alu_B <= X"00" & L;
                Alu_Mode <= Alu_Sub;
                State <= Exec2;
                -- CP A, (HL)
              when X"BE" =>
                Mem_Addr <= H & L;
                State <= Exec2;
                -- CP A, #
              when X"FE" =>
                Mem_Addr <= PC;
                PC <= std_logic_vector(unsigned(PC) + 1);
                State <= Exec2;
                -- END op-codes from page 82



              when others =>
                --FAKKA UR TOTALT OCH D
            end case; -- End case (Mem_Read)
          when Exec2 =>
            State <= Waiting;
            case (IR) is
              -- LD A,(C+$FF00)
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
                -- LD HL, SP+n
              when X"F8" =>
                Alu_A <= SP;
                Alu_B <= X"00" & Mem_Read;
                Alu_Mode <= Alu_Add;
                State <= Exec3;
                -- LD (nn), SP
              when X"08" =>
                Tmp_Addr(7 downto 0) <= Mem_Read;
                Mem_Addr <= PC;
                PC <= std_logic_vector(unsigned(PC) + 1);
                State <= Exec3;
                -- PUSH AF
              when X"F5" =>
                Tmp := std_logic_vector(unsigned(SP) + 1);
                Mem_Write <= F;
                Mem_Addr <= Tmp;
                SP <= Tmp;
                State <= Exec2;
                -- PUSH BC
              when X"C5" =>
                Tmp := std_logic_vector(unsigned(SP) - 1);
                Mem_Write <= C;
                Mem_Addr <= Tmp;
                SP <= Tmp;
                -- PUSH DE
              when X"D5" =>
                Tmp := std_logic_vector(unsigned(SP) - 1);
                Mem_Write <= E;
                Mem_Addr <= Tmp;
                SP <= Tmp;
                -- PUSH HL
              when X"E5" =>
                Tmp := std_logic_vector(unsigned(SP) - 1);
                Mem_Write <= L;
                Mem_Addr <= Tmp;
                SP <= Tmp;
                -- POP AF
              when X"F1" =>
                F <= Mem_Read;
                Mem_Addr <= SP;
                SP <= std_logic_vector(unsigned(SP) - 1);
                State <= Exec3;
                -- POP BC
              when X"C1" =>
                C <= Mem_Read;
                Mem_Addr <= SP;
                SP <= std_logic_vector(unsigned(SP) - 1);
                State <= Exec3;
                -- POP DE
              when X"D1" =>
                E <= Mem_Read;
                Mem_Addr <= SP;
                SP <= std_logic_vector(unsigned(SP) - 1);
                State <= Exec3;
                -- POP HL
              when X"E1" =>
                L <= Mem_Read;
                Mem_Addr <= SP;
                SP <= std_logic_vector(unsigned(SP) - 1);
                State <= Exec3;
                -- ADD A, A
              when X"87" =>
                A <= Alu_Result(7 downto 0);
                F <= Alu_Flags;
                -- ADD A, B
              when X"80" =>
                A <= Alu_Result(7 downto 0);
                F <= Alu_Flags;
                -- ADD A, C
              when X"81" =>
                A <= Alu_Result(7 downto 0);
                F <= Alu_Flags;
                -- ADD A, D
              when X"82" =>
                A <= Alu_Result(7 downto 0);
                F <= Alu_Flags;
                -- ADD A, E
              when X"83" =>
                A <= Alu_Result(7 downto 0);
                F <= Alu_Flags;
                -- ADD A, H
              when X"84" =>
                A <= Alu_Result(7 downto 0);
                F <= Alu_Flags;
                -- ADD A, L
              when X"85" =>
                A <= Alu_Result(7 downto 0);
                F <= Alu_Flags;
                -- Add A, (HL)
              when X"86" =>
                Alu_A <= X"00" & A;
                Alu_B <= X"00" & Mem_Read;
                Alu_Mode <= Alu_Add;
                State <= Exec3;
                -- Add A, #
              when X"C6" =>
                Alu_A <= X"00" & A;
                Alu_B <= X"00" & Mem_Read;
                Alu_Mode <= Alu_Add;
                State <= Exec3;

                -- ADC A, A
              when X"8F" =>
                A <= Alu_Result(7 downto 0);
                F <= Alu_Flags;
                -- ADC A, B
              when X"88" =>
                A <= Alu_Result(7 downto 0);
                F <= Alu_Flags;
                -- ADC A, C
              when X"89" =>
                A <= Alu_Result(7 downto 0);
                F <= Alu_Flags;
                -- ADC A, D
              when X"8A" =>
                A <= Alu_Result(7 downto 0);
                F <= Alu_Flags;
                -- ADC A, E
              when X"8B" =>
                A <= Alu_Result(7 downto 0);
                F <= Alu_Flags;
                -- ADC A, H
              when X"8C" =>
                A <= Alu_Result(7 downto 0);
                F <= Alu_Flags;
                -- ADC A, L
              when X"8D" =>
                A <= Alu_Result(7 downto 0);
                F <= Alu_Flags;
                -- ADC A, (HL)
              when X"8E" =>
                Alu_A <= X"00" & A;
                Alu_B <= X"00" & Mem_Read;
                Alu_Mode <= Alu_Add_Carry;
                Alu_Flags_In <= F;
                State <= Exec3;
                -- ADC A, #
              when X"CE" =>
                Alu_A <= X"00" & A;
                Alu_B <= X"00" & Mem_Read;
                Alu_Mode <= Alu_Add_Carry;
                Alu_Flags_In <= F;
                State <= Exec3;

                -- SUB A, A
              when X"97" =>
                A <= Alu_Result(7 downto 0);
                F <= Alu_Flags;
                -- SUB A, B
              when X"90" =>
                A <= Alu_Result(7 downto 0);
                F <= Alu_Flags;
                -- SUB A, C
              when X"91" =>
                A <= Alu_Result(7 downto 0);
                F <= Alu_Flags;
                -- SUB A, D
              when X"92" =>
                A <= Alu_Result(7 downto 0);
                F <= Alu_Flags;
                -- SUB A, E
              when X"93" =>
                A <= Alu_Result(7 downto 0);
                F <= Alu_Flags;
                -- SUB A, H
              when X"94" =>
                A <= Alu_Result(7 downto 0);
                F <= Alu_Flags;
                -- SUB A, L
              when X"95" =>
                A <= Alu_Result(7 downto 0);
                F <= Alu_Flags;
                -- SUB A, (HL)
              when X"96" =>
                Alu_A <= X"00" & A;
                Alu_B <= X"00" & Mem_Read;
                Alu_Mode <= Alu_Sub;
                State <= Exec3;
                -- SUB A, #
              when X"D6" =>
                Alu_A <= X"00" & A;
                Alu_B <= X"00" & Mem_Read;
                Alu_Mode <= Alu_Sub;
                State <= Exec3;

                -- SBC A, A
              when X"9F" =>
                A <= Alu_Result(7 downto 0);
                F <= Alu_Flags;
                -- SBC A, B
              when X"98" =>
                A <= Alu_Result(7 downto 0);
                F <= Alu_Flags;
                -- SBC A, C
              when X"99" =>
                A <= Alu_Result(7 downto 0);
                F <= Alu_Flags;
                -- SBC A, D
              when X"9A" =>
                A <= Alu_Result(7 downto 0);
                F <= Alu_Flags;
                -- SBC A, E
              when X"9B" =>
                A <= Alu_Result(7 downto 0);
                F <= Alu_Flags;
                -- SBC A, H
              when X"9C" =>
                A <= Alu_Result(7 downto 0);
                F <= Alu_Flags;
                -- SBC A, L
              when X"9D" =>
                A <= Alu_Result(7 downto 0);
                F <= Alu_Flags;
                -- SBC A, (HL)
              when X"9E" =>
                Alu_A <= X"00" & A;
                Alu_B <= X"00" & Mem_Read;
                Alu_Mode <= Alu_Sub_Carry;
                Alu_Flags_In <= F;
                State <= Exec3;
                -- SBC A, #
              when X"DE" =>
                Alu_A <= X"00" & A;
                Alu_B <= X"00" & Mem_Read;
                Alu_Mode <= Alu_Sub_Carry;
                Alu_Flags_In <= F;
                State <= Exec3;

                -- AND A, A
              when X"A7" =>
                A <= Alu_Result(7 downto 0);
                F <= Alu_Flags;
                -- AND A, B
              when X"A0" =>
                A <= Alu_Result(7 downto 0);
                F <= Alu_Flags;
                -- AND A, C
              when X"A1" =>
                A <= Alu_Result(7 downto 0);
                F <= Alu_Flags;
                -- AND A, D
              when X"A2" =>
                A <= Alu_Result(7 downto 0);
                F <= Alu_Flags;
                -- AND A, E
              when X"A3" =>
                A <= Alu_Result(7 downto 0);
                F <= Alu_Flags;
                -- AND A, H
              when X"A4" =>
                A <= Alu_Result(7 downto 0);
                F <= Alu_Flags;
                -- AND A, L
              when X"A5" =>
                A <= Alu_Result(7 downto 0);
                F <= Alu_Flags;
                -- AND A, (HL)
              when X"A6" =>
                Alu_A <= X"00" & A;
                Alu_B <= X"00" & Mem_Read;
                Alu_Mode <= Alu_And;
                State <= Exec3;
                -- AND A, #
              when X"E6" =>
                Alu_A <= X"00" & A;
                Alu_B <= X"00" & Mem_Read;
                Alu_Mode <= Alu_And;
                State <= Exec3;

                -- OR A, A
              when X"B7" =>
                A <= Alu_Result(7 downto 0);
                F <= Alu_Flags;
                -- OR A, B
              when X"B0" =>
                A <= Alu_Result(7 downto 0);
                F <= Alu_Flags;
                -- OR A, C
              when X"B1" =>
                A <= Alu_Result(7 downto 0);
                F <= Alu_Flags;
                -- OR A, D
              when X"B2" =>
                A <= Alu_Result(7 downto 0);
                F <= Alu_Flags;
                -- OR A, E
              when X"B3" =>
                A <= Alu_Result(7 downto 0);
                F <= Alu_Flags;
                -- OR A, H
              when X"B4" =>
                A <= Alu_Result(7 downto 0);
                F <= Alu_Flags;
                -- OR A, L
              when X"B5" =>
                A <= Alu_Result(7 downto 0);
                F <= Alu_Flags;
                -- OR A, (HL)
              when X"B6" =>
                Alu_A <= X"00" & A;
                Alu_B <= X"00" & Mem_Read;
                Alu_Mode <= Alu_Or;
                State <= Exec3;
                -- OR A, #
              when X"F6" =>
                Alu_A <= X"00" & A;
                Alu_B <= X"00" & Mem_Read;
                Alu_Mode <= Alu_Or;
                State <= Exec3;

                -- XOR A, A
              when X"AF" =>
                A <= Alu_Result(7 downto 0);
                F <= Alu_Flags;
                -- XOR A, B
              when X"A8" =>
                A <= Alu_Result(7 downto 0);
                F <= Alu_Flags;
                -- XOR A, C
              when X"A9" =>
                A <= Alu_Result(7 downto 0);
                F <= Alu_Flags;
                -- XOR A, D
              when X"AA" =>
                A <= Alu_Result(7 downto 0);
                F <= Alu_Flags;
                -- XOR A, E
              when X"AB" =>
                A <= Alu_Result(7 downto 0);
                F <= Alu_Flags;
                -- XOR A, H
              when X"AC" =>
                A <= Alu_Result(7 downto 0);
                F <= Alu_Flags;
                -- XOR A, L
              when X"AD" =>
                A <= Alu_Result(7 downto 0);
                F <= Alu_Flags;
                -- XOR A, (HL)
              when X"AE" =>
                Alu_A <= X"00" & A;
                Alu_B <= X"00" & Mem_Read;
                Alu_Mode <= Alu_Xor;
                State <= Exec3;
                -- XOR A, #
              when X"EE" =>
                Alu_A <= X"00" & A;
                Alu_B <= X"00" & Mem_Read;
                Alu_Mode <= Alu_Xor;
                State <= Exec3;

                -- CP A, A
              when X"BF" =>
                F <= Alu_Flags;
                -- CP A, B
              when X"B8" =>
                F <= Alu_Flags;
                -- CP A, C
              when X"B9" =>
                F <= Alu_Flags;
                -- CP A, D
              when X"BA" =>
                F <= Alu_Flags;
                -- CP A, E
              when X"BB" =>
                F <= Alu_Flags;
                -- CP A, H
              when X"BC" =>
                F <= Alu_Flags;
                -- CP A, L
              when X"BD" =>
                F <= Alu_Flags;
                -- CP A, (HL)
              when X"BE" =>
                Alu_A <= X"00" & A;
                Alu_B <= X"00" & Mem_Read;
                Alu_Mode <= Alu_Sub;
                State <= Exec3;
                -- CP A, #
              when X"FE" =>
                Alu_A <= X"00" & A;
                Alu_B <= X"00" & Mem_Read;
                Alu_Mode <= Alu_Sub;
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
                -- LD HL, SP+n
              when X"F8" =>
                H <= Alu_Result(15 downto 8);
                L <= Alu_Result(7 downto 0);
                F <= Alu_Flags;
                F(7 downto 6) <= "00"; --Always zero
                -- LD (nn), SP
              when X"08" =>
                Tmp_Addr(15 downto 8) <= Mem_Read;
                -- Tmp_Addr has not been updated yet...
                Mem_Addr <= Mem_Read & Tmp_Addr(7 downto 0);
                Mem_Write <= SP(7 downto 0);
                Mem_Write_Enable <= '1';
                State <= Exec4;
                -- POP AF
              when X"F1" =>
                A <= Mem_Read;
                -- POP BC
              when X"C1" =>
                B <= Mem_Read;
                -- POP DE
              when X"D1" =>
                D <= Mem_Read;
                -- POP HL
              when X"E1" =>
                H <= Mem_Read;
              when X"85" =>
                -- ADD A, (HL)
              when X"86" =>
                A <= Alu_Result(7 downto 0);
                F <= Alu_Flags;
                -- ADD A, #
              when X"C6" =>
                A <= Alu_Result(7 downto 0);
                F <= Alu_Flags;

                -- ADC A, (HL)
              when X"8E" =>
                A <= Alu_Result(7 downto 0);
                F <= Alu_Flags;
                -- ADC A, #
              when X"CE" =>
                A <= Alu_Result(7 downto 0);
                F <= Alu_Flags;

                -- SUB A, (HL)
              when X"96" =>
                A <= Alu_Result(7 downto 0);
                F <= Alu_Flags;
                -- SUB A, #
              when X"D6" =>
                A <= Alu_Result(7 downto 0);
                F <= Alu_Flags;

                -- SBC A, (HL)
              when X"9E" =>
                A <= Alu_Result(7 downto 0);
                F <= Alu_Flags;
                -- SBC A, #
              when X"DE" =>
                A <= Alu_Result(7 downto 0);
                F <= Alu_Flags;

                -- AND A, (HL)
              when X"A6" =>
                A <= Alu_Result(7 downto 0);
                F <= Alu_Flags;
                -- AND A, #
              when X"E6" =>
                A <= Alu_Result(7 downto 0);
                F <= Alu_Flags;

                -- OR A, (HL)
              when X"B6" =>
                A <= Alu_Result(7 downto 0);
                F <= Alu_Flags;
                -- OR A, #
              when X"F6" =>
                A <= Alu_Result(7 downto 0);
                F <= Alu_Flags;

                -- XOR A, (HL)
              when X"AE" =>
                A <= Alu_Result(7 downto 0);
                F <= Alu_Flags;
                -- XOR A, #
              when X"EE" =>
                A <= Alu_Result(7 downto 0);
                F <= Alu_Flags;

                -- CP A, (HL)
              when X"BE" =>
                F <= Alu_Flags;
                -- CP A, #
              when X"FE" =>
                F <= Alu_Flags;


              when others =>
            end case; -- End case Exec3

          when Exec4 =>
            State <= Waiting;
            case (IR) is
              -- LD A, nn, two byte immediate value
              when X"FA" =>
                A <= Mem_Read;
                -- LD (nn), SP
              when X"08" =>
                Mem_Addr <= std_logic_vector(unsigned(Tmp_Addr) + 1);
                Mem_Write <= SP(15 downto 8);
                Mem_Write_Enable <= '1';
              when others =>
            end case;
          when others =>
        end case; -- End case State 
      end if;
    end if;
  end process;
  

end Cpu_Implementation;
