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
  -- Halted is a state used when the CPU should wait for interrupts.
  -- Mb_Exec is the execution stages for multi-byte op-codes.
  type State_Type is (Waiting, Fetch, Exec, Exec2, Exec3, Exec4, Mb_Exec, Mb_Exec2, Halted);
  -- current state of the interpreter
  signal State : State_Type := Waiting;
  -- how long have we been waiting?
  signal Waited_Clks : std_logic_vector(15 downto 0) := X"0000";
  -- tmp variable for calculations on full addresses
  signal Tmp_Addr : std_logic_vector(15 downto 0);
  -- tmp variable for calculations on 8-bit stuff
  signal Tmp_8bit : std_logic_vector(7 downto 0);
  -- Instruction Register. MB_IR is the second byte of multi-byte instructions.
  signal IR, MB_IR : std_logic_vector(7 downto 0);
  -- Interrupts enabled.
  signal Interrupts_Enabled : std_logic := '0';

  -- ALU instantiation.
  component Alu
    port(A, B : in std_logic_vector(15 downto 0);
         Mode : in std_logic_vector(3 downto 0);
         Flags_In : in std_logic_vector(7 downto 0);
         Result : out std_logic_vector(15 downto 0);
         Flags : out std_logic_vector(7 downto 0);
         High_Flags : in std_logic);
  end component;

  -- Signals to the ALU
  signal Alu_A, Alu_B, Alu_Result : std_logic_vector(15 downto 0);
  signal Alu_Flags_In : std_logic_vector(7 downto 0);
  signal Alu_Mode : std_logic_vector(3 downto 0);
  signal Alu_Flags : std_logic_vector(7 downto 0);
  signal Alu_High_Flags : std_logic;
  -- Modes for the alu.
  constant Alu_Add : std_logic_vector(3 downto 0) := "0000";
  constant Alu_Sub : std_logic_vector(3 downto 0) := "0001";
  constant Alu_Add_Carry : std_logic_vector(3 downto 0) := "0010";
  constant Alu_Sub_Carry : std_logic_vector(3 downto 0) := "0011";
  constant Alu_And : std_logic_vector(3 downto 0) := "0100";
  constant Alu_Or : std_logic_vector(3 downto 0) := "0101";
  constant Alu_Xor : std_logic_vector(3 downto 0) := "0110";
  constant Alu_Inc : std_logic_vector(3 downto 0) := "0111";
  constant Alu_Dec : std_logic_vector(3 downto 0) := "1000";

  -- DAA instantiation
  component Daa_Logic is
    port (Input : in std_logic_vector(7 downto 0);
          Flags : in std_logic_vector(7 downto 0);
          Flags_Out : out std_logic_vector(7 downto 0);
          Output : out std_logic_vector(7 downto 0));
  end component;

  signal Daa_Flags : std_logic_vector(7 downto 0);
  signal Daa_Output : std_logic_vector(7 downto 0);

begin

  Alu_Ports : Alu port map(
    A => Alu_A,
    B => Alu_B,
    Mode => Alu_Mode,
    Flags_In => Alu_Flags_In,
    Result => Alu_Result,
    Flags => Alu_Flags,
    High_Flags => Alu_High_Flags);

  Daa_Ports : Daa_Logic port map(
    Input => A,
    Flags => F,
    Flags_Out => Daa_Flags,
    Output => Daa_Output);

  -- 
  process (Clk)
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
        Mem_Addr <= X"0000";
        Interrupts_Enabled <= '0';      -- Assumed value.
      else
        -- Reset the high flags, since most instructions assume it is set to zero.
        Alu_High_Flags <= '0';
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
          when Halted =>
            -- TODO: Wait for interrupt.
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
                Mem_Write <= D;
                Mem_Write_Enable <= '1';
                -- LD (HL), E -t
              when X"73" =>
                Mem_Addr <= H & L;
                Mem_Write <= E;
                Mem_Write_Enable <= '1';
                -- LD (HL), H -t
              when X"74" =>
                Mem_Addr <= H & L;
                Mem_Write <= H;
                Mem_Write_Enable <= '1';
                -- LD (HL), L -t
              when X"75" =>
                Mem_Addr <= H & L;
                Mem_Write <= L;
                Mem_Write_Enable <= '1';
                -- LD (HL), n -t
              when X"36" =>
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
                -- ADC A, B   more in detail than 89-8f -t
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
                -- SBC A, A -t
              when X"9F" =>
                Alu_A <= X"00" & A;
                Alu_B <= X"00" & A;
                Alu_Mode <= Alu_Sub_Carry;
                Alu_Flags_In <= F;
                State <= Exec2;
                -- SBC A, B - tested more in detail than 99-9F -t
              when X"98" =>
                Alu_A <= X"00" & A;
                Alu_B <= X"00" & B;
                Alu_Mode <= Alu_Sub_Carry;
                Alu_Flags_In <= F;
                State <= Exec2;
                -- SBC A, C -t
              when X"99" =>
                Alu_A <= X"00" & A;
                Alu_B <= X"00" & C;
                Alu_Mode <= Alu_Sub_Carry;
                Alu_Flags_In <= F;
                State <= Exec2;
                -- SBC A, D -t
              when X"9A" =>
                Alu_A <= X"00" & A;
                Alu_B <= X"00" & D;
                Alu_Mode <= Alu_Sub_Carry;
                Alu_Flags_In <= F;
                State <= Exec2;
                -- SBC A, E -t
              when X"9B" =>
                Alu_A <= X"00" & A;
                Alu_B <= X"00" & E;
                Alu_Mode <= Alu_Sub_Carry;
                Alu_Flags_In <= F;
                State <= Exec2;
                -- SBC A, H -t
              when X"9C" =>
                Alu_A <= X"00" & A;
                Alu_B <= X"00" & H;
                Alu_Mode <= Alu_Sub_Carry;
                Alu_Flags_In <= F;
                State <= Exec2;
                -- SBC A, L -t
              when X"9D" =>
                Alu_A <= X"00" & A;
                Alu_B <= X"00" & L;
                Alu_Mode <= Alu_Sub_Carry;
                Alu_Flags_In <= F;
                State <= Exec2;
                -- SBC A, (HL) -t
              when X"9E" =>
                Mem_Addr <= H & L;
                State <= Exec2;
                -- SBC A, # -t
              when X"DE" =>
                Mem_Addr <= PC;
                PC <= std_logic_vector(unsigned(PC) + 1);
                State <= Exec2;
                -- END op-codes from page 83
                -- OP-codes from page 84
                -- AND A, A -t
              when X"A7" =>
                Alu_A <= X"00" & A;
                Alu_B <= X"00" & A;
                Alu_Mode <= Alu_And;
                State <= Exec2;
                -- AND A, B  - tested in more detail than A1-A7 -t
              when X"A0" =>
                Alu_A <= X"00" & A;
                Alu_B <= X"00" & B;
                Alu_Mode <= Alu_And;
                State <= Exec2;
                -- AND A, C -t
              when X"A1" =>
                Alu_A <= X"00" & A;
                Alu_B <= X"00" & C;
                Alu_Mode <= Alu_And;
                State <= Exec2;
                -- AND A, D -t
              when X"A2" =>
                Alu_A <= X"00" & A;
                Alu_B <= X"00" & D;
                Alu_Mode <= Alu_And;
                State <= Exec2;
                -- AND A, E -t
              when X"A3" =>
                Alu_A <= X"00" & A;
                Alu_B <= X"00" & E;
                Alu_Mode <= Alu_And;
                State <= Exec2;
                -- AND A, H -t
              when X"A4" =>
                Alu_A <= X"00" & A;
                Alu_B <= X"00" & H;
                Alu_Mode <= Alu_And;
                State <= Exec2;
                -- AND A, L -t
              when X"A5" =>
                Alu_A <= X"00" & A;
                Alu_B <= X"00" & L;
                Alu_Mode <= Alu_And;
                State <= Exec2;
                -- AND A, (HL) -t
              when X"A6" =>
                Mem_Addr <= H & L;
                State <= Exec2;
                -- AND A, # -t
              when X"E6" =>
                Mem_Addr <= PC;
                PC <= std_logic_vector(unsigned(PC) + 1);
                State <= Exec2;
                -- END op-codes from page 84
                -- OP-codes from page 85
                -- OR A, A -t
              when X"B7" =>
                Alu_A <= X"00" & A;
                Alu_B <= X"00" & A;
                Alu_Mode <= Alu_Or;
                State <= Exec2;
                -- OR A, B   - tested in more detail than B1-B7 -t
              when X"B0" =>
                Alu_A <= X"00" & A;
                Alu_B <= X"00" & B;
                Alu_Mode <= Alu_Or;
                State <= Exec2;
                -- OR A, C -t
              when X"B1" =>
                Alu_A <= X"00" & A;
                Alu_B <= X"00" & C;
                Alu_Mode <= Alu_Or;
                State <= Exec2;
                -- OR A, D -t
              when X"B2" =>
                Alu_A <= X"00" & A;
                Alu_B <= X"00" & D;
                Alu_Mode <= Alu_Or;
                State <= Exec2;
                -- OR A, E -t
              when X"B3" =>
                Alu_A <= X"00" & A;
                Alu_B <= X"00" & E;
                Alu_Mode <= Alu_Or;
                State <= Exec2;
                -- OR A, H -t
              when X"B4" =>
                Alu_A <= X"00" & A;
                Alu_B <= X"00" & H;
                Alu_Mode <= Alu_Or;
                State <= Exec2;
                -- OR A, L -t
              when X"B5" =>
                Alu_A <= X"00" & A;
                Alu_B <= X"00" & L;
                Alu_Mode <= Alu_Or;
                State <= Exec2;
                -- OR A, (HL) -t
              when X"B6" =>
                Mem_Addr <= H & L;
                State <= Exec2;
                -- OR A, # -t
              when X"F6" =>
                Mem_Addr <= PC;
                PC <= std_logic_vector(unsigned(PC) + 1);
                State <= Exec2;
                -- END op-codes from page 85
                -- OP-codes from page 86
                -- XOR A, A -t
              when X"AF" =>
                Alu_A <= X"00" & A;
                Alu_B <= X"00" & A;
                Alu_Mode <= Alu_Xor;
                State <= Exec2;
                -- XOR A, B - tested in more detail than A9-AF -t
              when X"A8" =>
                Alu_A <= X"00" & A;
                Alu_B <= X"00" & B;
                Alu_Mode <= Alu_Xor;
                State <= Exec2;
                -- XOR A, C -t
              when X"A9" =>
                Alu_A <= X"00" & A;
                Alu_B <= X"00" & C;
                Alu_Mode <= Alu_Xor;
                State <= Exec2;
                -- XOR A, D -t
              when X"AA" =>
                Alu_A <= X"00" & A;
                Alu_B <= X"00" & D;
                Alu_Mode <= Alu_Xor;
                State <= Exec2;
                -- XOR A, E -t
              when X"AB" =>
                Alu_A <= X"00" & A;
                Alu_B <= X"00" & E;
                Alu_Mode <= Alu_Xor;
                State <= Exec2;
                -- XOR A, H -t
              when X"AC" =>
                Alu_A <= X"00" & A;
                Alu_B <= X"00" & H;
                Alu_Mode <= Alu_Xor;
                State <= Exec2;
                -- XOR A, L -t
              when X"AD" =>
                Alu_A <= X"00" & A;
                Alu_B <= X"00" & L;
                Alu_Mode <= Alu_Xor;
                State <= Exec2;
                -- XOR A, (HL) -t
              when X"AE" =>
                Mem_Addr <= H & L;
                State <= Exec2;
                -- XOR A, # -t
              when X"EE" =>
                Mem_Addr <= PC;
                PC <= std_logic_vector(unsigned(PC) + 1);
                State <= Exec2;
                -- END op-codes from page 86
                -- OP-codes from page 87
                -- CP A, A - (only tested if this does not destory A) -t
              when X"BF" =>
                Alu_A <= X"00" & A;
                Alu_B <= X"00" & A;
                Alu_Mode <= Alu_Sub;
                State <= Exec2;
                -- CP A, B - (only tested if this does not destory A) -t
              when X"B8" =>
                Alu_A <= X"00" & A;
                Alu_B <= X"00" & B;
                Alu_Mode <= Alu_Sub;
                State <= Exec2;
                -- CP A, C - (only tested if this does not destory A) -t
              when X"B9" =>
                Alu_A <= X"00" & A;
                Alu_B <= X"00" & C;
                Alu_Mode <= Alu_Sub;
                State <= Exec2;
                -- CP A, D - (only tested if this does not destory A) -t
              when X"BA" =>
                Alu_A <= X"00" & A;
                Alu_B <= X"00" & D;
                Alu_Mode <= Alu_Sub;
                State <= Exec2;
                -- CP A, E - (only tested if this does not destory A) -t
              when X"BB" =>
                Alu_A <= X"00" & A;
                Alu_B <= X"00" & E;
                Alu_Mode <= Alu_Sub;
                State <= Exec2;
                -- CP A, H - (only tested if this does not destory A) -t
              when X"BC" =>
                Alu_A <= X"00" & A;
                Alu_B <= X"00" & H;
                Alu_Mode <= Alu_Sub;
                State <= Exec2;
                -- CP A, L - (only tested if this does not destory A) -t
              when X"BD" =>
                Alu_A <= X"00" & A;
                Alu_B <= X"00" & L;
                Alu_Mode <= Alu_Sub;
                State <= Exec2;
                -- CP A, (HL) - (only tested if this does not destory A) -t
              when X"BE" =>
                Mem_Addr <= H & L;
                State <= Exec2;
                -- CP A, # - (only tested if this does not destory A) -t
              when X"FE" =>
                Mem_Addr <= PC;
                PC <= std_logic_vector(unsigned(PC) + 1);
                State <= Exec2;
                -- END op-codes from page 87
                -- OP-codes from page 88
                -- INC A -t
              when X"3C" =>
                Alu_A <= X"00" & A;
                Alu_Mode <= Alu_Inc;
                Alu_Flags_In <= F;
                State <= Exec2;
                -- INC B -t
              when X"04" =>
                Alu_A <= X"00" & A;
                Alu_Mode <= Alu_Inc;
                Alu_Flags_In <= F;
                State <= Exec2;
                -- INC C -t
              when X"0C" =>
                Alu_A <= X"00" & A;
                Alu_Mode <= Alu_Inc;
                Alu_Flags_In <= F;
                State <= Exec2;
                -- INC D -t
              when X"14" =>
                Alu_A <= X"00" & A;
                Alu_Mode <= Alu_Inc;
                Alu_Flags_In <= F;
                State <= Exec2;
                -- INC E -t
              when X"1C" =>
                Alu_A <= X"00" & A;
                Alu_Mode <= Alu_Inc;
                Alu_Flags_In <= F;
                State <= Exec2;
                -- INC H -t
              when X"24" =>
                Alu_A <= X"00" & A;
                Alu_Mode <= Alu_Inc;
                Alu_Flags_In <= F;
                State <= Exec2;
                -- INC L -t
              when X"2C" =>
                Alu_A <= X"00" & A;
                Alu_Mode <= Alu_Inc;
                Alu_Flags_In <= F;
                State <= Exec2;
                -- INC (HL) -t
              when X"34" =>
                Mem_Addr <= H & L;
                State <= Exec2;
                -- END op-codes from page 88
                -- OP-codes from page 89
                -- DEC A -t
              when X"3D" =>
                Alu_A <= X"00" & A;
                Alu_Mode <= Alu_Dec;
                Alu_Flags_In <= F;
                State <= Exec2;
                -- DEC B -t
              when X"05" =>
                Alu_A <= X"00" & A;
                Alu_Mode <= Alu_Dec;
                Alu_Flags_In <= F;
                State <= Exec2;
                -- DEC C -t
              when X"0D" =>
                Alu_A <= X"00" & A;
                Alu_Mode <= Alu_Dec;
                Alu_Flags_In <= F;
                State <= Exec2;
                -- DEC D -t
              when X"15" =>
                Alu_A <= X"00" & A;
                Alu_Mode <= Alu_Dec;
                Alu_Flags_In <= F;
                State <= Exec2;
                -- DEC E -t
              when X"1D" =>
                Alu_A <= X"00" & A;
                Alu_Mode <= Alu_Dec;
                Alu_Flags_In <= F;
                State <= Exec2;
                -- DEC H -t
              when X"25" =>
                Alu_A <= X"00" & A;
                Alu_Mode <= Alu_Dec;
                Alu_Flags_In <= F;
                State <= Exec2;
                -- DEC L -t
              when X"2D" =>
                Alu_A <= X"00" & A;
                Alu_Mode <= Alu_Dec;
                Alu_Flags_In <= F;
                State <= Exec2;
                -- DEC (HL) -t
              when X"35" =>
                Mem_Addr <= H & L;
                State <= Exec2;
                -- END op-codes from page 89
                -- OP-codes from page 90
                -- ADD HL, BC -t
              when X"09" =>
                Alu_A <= H & L;
                Alu_B <= B & C;
                Alu_Mode <= Alu_Add;
                Alu_High_Flags <= '1';
                State <= Exec2;
                -- ADD HL, DE -t
              when X"19" =>
                Alu_A <= H & L;
                Alu_B <= D & E;
                Alu_Mode <= Alu_Add;
                Alu_High_Flags <= '1';
                State <= Exec2;
                -- ADD HL, HL -t
              when X"29" =>
                Alu_A <= H & L;
                Alu_B <= H & L;
                Alu_Mode <= Alu_Add;
                Alu_High_Flags <= '1';
                State <= Exec2;
                -- ADD HL, SP -t
              when X"39" =>
                Alu_A <= H & L;
                Alu_B <= SP;
                Alu_Mode <= Alu_Add;
                Alu_High_Flags <= '1';
                State <= Exec2;
                -- END op-codes from page 90
                -- OP-code from page 91
                -- ADD SP, n (n = signed byte) # (High or low flags????) -t
              when X"E8" =>
                Mem_Addr <= PC;
                PC <= std_logic_vector(unsigned(PC) + 1);
                State <= Exec2;

                -- OP-codes from page 92
                -- INC BC -t
              when X"03" =>
                Tmp := std_logic_vector(unsigned(B & C) + 1);
                B <= Tmp(15 downto 8);
                C <= Tmp(7 downto 0);
                -- INC DE -t
              when X"13" =>
                Tmp := std_logic_vector(unsigned(D & E) + 1);
                D <= Tmp(15 downto 8);
                E <= Tmp(7 downto 0);
                -- INC HL -t
              when X"23" =>
                Tmp := std_logic_vector(unsigned(H & L) + 1);
                H <= Tmp(15 downto 8);
                L <= Tmp(7 downto 0);
                -- INC SP -t
              when X"33" =>
                SP <= std_logic_vector(unsigned(SP) + 1);
                -- END op-codes from page 92

                -- OP-codes from page 93
                -- DEC BC -t
              when X"0B" =>
                Tmp := std_logic_vector(unsigned(B & C) - 1);
                B <= Tmp(15 downto 8);
                C <= Tmp(7 downto 0);
                -- DEC DE -t
              when X"1B" =>
                Tmp := std_logic_vector(unsigned(D & E) - 1);
                D <= Tmp(15 downto 8);
                E <= Tmp(7 downto 0);
                -- DEC HL -t
              when X"2B" =>
                Tmp := std_logic_vector(unsigned(H & L) - 1);
                H <= Tmp(15 downto 8);
                L <= Tmp(7 downto 0);
                -- DEC SP -t
              when X"3B" =>
                SP <= std_logic_vector(unsigned(SP) - 1);
                -- END op-codes from page 93
                -- Multi-byte op-codes
              when X"10" =>
                Mem_Addr <= PC;
                PC <= std_logic_vector(unsigned(PC) + 1);
                State <= Mb_Exec;
              when X"CB" =>
                Mem_Addr <= PC;
                PC <= std_logic_vector(unsigned(PC) + 1);
                State <= Mb_Exec;

                -- OP-codes from page 95
                -- DAA (not implemented in daa_logic)
              when X"27" =>
                F <= Daa_Flags;
                A <= Daa_Output;
                
                -- CPL (set N and H flag)
              when X"2F" =>
                A <= not A;
                F(6 downto 5) <= "11";
                -- END op-codes from  page 95
                -- OP-codes from page 96
                -- CCF
              when X"3F" =>
                F(6 downto 5) <= "00";
                F(4) <= not F(4);
                -- SCF
              when X"37" =>
                F(6 downto 5) <= "00";
                F(4) <= '1';
                -- END op-codes from page 96
                -- OP-codes from page 97
                -- NOP
              when X"00" =>
                -- HALT
              when X"76" =>
                State <= Halted;
                -- END op-codes from page 97
                -- OP-codes from page 98
                -- DI
              when X"F3" =>
                Interrupts_Enabled <= '0';
                -- EI
              when X"FB" =>
                Interrupts_Enabled <= '1';
                -- END op-codes from page 98

                -- OP-codes from page 99
                -- RLCA -t
              when X"07" =>
                A(7 downto 1) <= A(6 downto 0);
                A(0) <= A(7);
                F(4) <= A(7);
                F(5) <= '0';
                F(6) <= '0';
                if A = X"00" then
                  F(7) <= '1';
                else
                  F(7) <= '0';
                end if;
                -- RLA -t
              when X"17" =>
                A(7 downto 1) <= A(6 downto 0);
                A(0) <= F(4);
                F(4) <= A(7);
                F(6 downto 5) <= "00";
                if A(6 downto 0) = "000000" and F(4) = '0' then
                  F(7) <= '1';
                else
                  F(7) <= '0';
                end if;
                -- END op-codes from page 99

                -- OP-codes from page 100
                -- RRCA -t
              when X"0F" =>
                A(6 downto 0) <= A(7 downto 1);
                A(7) <= A(0);
                F(4) <= A(0);
                F(5) <= '0';
                F(6) <= '0';
                if A = X"00" then
                  F(7) <= '1';
                else
                  F(7) <= '0';
                end if;
                -- RRA -t
              when X"1F" =>
                A(6 downto 0) <= A(7 downto 1);
                A(7) <= F(4);
                F(4) <= A(0);
                F(6 downto 5) <= "00";
                if A(7 downto 1) = "000000" and F(4) = '0' then
                  F(7) <= '1';
                else
                  F(7) <= '0';
                end if;
                -- END op-codes from page 100
                
                -- OP-codes from page 111
                -- JP nn
              when X"C3" =>
                Mem_Addr <= PC;
                PC <= std_logic_vector(unsigned(PC) + 1);
                State <= Exec2;
                -- JP NZ,nn
              when X"C2" =>
                Mem_Addr <= PC;
                PC <= std_logic_vector(unsigned(PC) + 1);
                State <= Exec2;
                -- JP Z,nn
              when X"CA" =>
                Mem_Addr <= PC;
                PC <= std_logic_vector(unsigned(PC) + 1);
                State <= Exec2;
                -- JP NC,nn
              when X"D2" =>
                Mem_Addr <= PC;
                PC <= std_logic_vector(unsigned(PC) + 1);
                State <= Exec2;
                -- JP C,nn
              when X"DA" =>
                Mem_Addr <= PC;
                PC <= std_logic_vector(unsigned(PC) + 1);
                State <= Exec2;
                -- END op-codes from page 111
                -- OP-codes from page 112
                -- JP (HL)
              when X"E9" =>
                PC <= H & L;
                -- JR n (relative jump, n signed, relative first byte of next instr)
              when X"18" =>
                Mem_Addr <= PC;
                PC <= std_logic_vector(unsigned(PC) + 1);
                State <= Exec2;
                -- END op-codes from page 112
                -- OP-codes from page 113
                -- JR NZ, n
              when X"20" =>
                Mem_Addr <= PC;
                PC <= std_logic_vector(unsigned(PC) + 1);
                State <= Exec2;
                -- JR Z, n
              when X"28" =>
                Mem_Addr <= PC;
                PC <= std_logic_vector(unsigned(PC) + 1);
                State <= Exec2;
                -- JR NC, n
              when X"30" =>
                Mem_Addr <= PC;
                PC <= std_logic_vector(unsigned(PC) + 1);
                State <= Exec2;
                -- JR C, n
              when X"38" =>
                Mem_Addr <= PC;
                PC <= std_logic_vector(unsigned(PC) + 1);
                State <= Exec2;
                -- END op-codes from page 113
                -- OP-code from page 114
                -- CALL nn
              when X"CD" =>
                Mem_Addr <= PC;
                PC <= std_logic_vector(unsigned(PC) + 1);
                State <= Exec2;
                -- OP-codes from page 115
                -- CALL NZ, nn
              when X"C4" =>
                Mem_Addr <= PC;
                PC <= std_logic_vector(unsigned(PC) + 1);
                State <= Exec2;
                -- CALL Z, nn
              when X"CC" =>
                Mem_Addr <= PC;
                PC <= std_logic_vector(unsigned(PC) + 1);
                State <= Exec2;
                -- CALL NC, nn
              when X"D4" =>
                Mem_Addr <= PC;
                PC <= std_logic_vector(unsigned(PC) + 1);
                State <= Exec2;
                -- CALL C, nn
              when X"DC" =>
                Mem_Addr <= PC;
                PC <= std_logic_vector(unsigned(PC) + 1);
                State <= Exec2;
                -- END op-codes from page 115
                -- OP-codes from page 116
                -- RST 0x00
              when X"C7" =>
                Tmp := std_logic_vector(unsigned(SP) - 1);
                SP <= Tmp;
                Mem_Write <= PC(15 downto 8);
                Mem_Addr <= Tmp;
                Mem_Write_Enable <= '1';
                State <= Exec2;
                -- RST 0x08
              when X"CF" =>
                Tmp := std_logic_vector(unsigned(SP) - 1);
                SP <= Tmp;
                Mem_Write <= PC(15 downto 8);
                Mem_Addr <= Tmp;
                Mem_Write_Enable <= '1';
                State <= Exec2;
                -- RST 0x10
              when X"D7" =>
                Tmp := std_logic_vector(unsigned(SP) - 1);
                SP <= Tmp;
                Mem_Write <= PC(15 downto 8);
                Mem_Addr <= Tmp;
                Mem_Write_Enable <= '1';
                State <= Exec2;
                -- RST 0x18
              when X"DF" =>
                Tmp := std_logic_vector(unsigned(SP) - 1);
                SP <= Tmp;
                Mem_Write <= PC(15 downto 8);
                Mem_Addr <= Tmp;
                Mem_Write_Enable <= '1';
                State <= Exec2;
                -- RST 0x20
              when X"E7" =>
                Tmp := std_logic_vector(unsigned(SP) - 1);
                SP <= Tmp;
                Mem_Write <= PC(15 downto 8);
                Mem_Addr <= Tmp;
                Mem_Write_Enable <= '1';
                State <= Exec2;
                -- RST 0x28
              when X"EF" =>
                Tmp := std_logic_vector(unsigned(SP) - 1);
                SP <= Tmp;
                Mem_Write <= PC(15 downto 8);
                Mem_Addr <= Tmp;
                Mem_Write_Enable <= '1';
                State <= Exec2;
                -- RST 0x30
              when X"F7" =>
                Tmp := std_logic_vector(unsigned(SP) - 1);
                SP <= Tmp;
                Mem_Write <= PC(15 downto 8);
                Mem_Addr <= Tmp;
                Mem_Write_Enable <= '1';
                State <= Exec2;
                -- RST 0x38
              when X"FF" =>
                Tmp := std_logic_vector(unsigned(SP) - 1);
                SP <= Tmp;
                Mem_Write <= PC(15 downto 8);
                Mem_Addr <= Tmp;
                Mem_Write_Enable <= '1';
                State <= Exec2;
                -- END op-codes from page 116
                -- OP-codes from page 117
                -- RET
              when X"C9" =>
                Mem_Addr <= SP;
                SP <= std_logic_vector(unsigned(SP) + 1);
                State <= Exec2;
                -- RET NZ
              when X"C0" =>
                if F(7) = '0' then
                  Mem_Addr <= SP;
                  SP <= std_logic_vector(unsigned(SP) + 1);
                  State <= Exec2;
                end if;
                -- RET Z
              when X"C8" =>
                if F(7) = '1' then
                  Mem_Addr <= SP;
                  SP <= std_logic_vector(unsigned(SP) + 1);
                  State <= Exec2;
                end if;
                -- RET NC
              when X"D0" =>
                if F(4) = '0' then
                  Mem_Addr <= SP;
                  SP <= std_logic_vector(unsigned(SP) + 1);
                  State <= Exec2;
                end if;
                -- RET C
              when X"D8" =>
                if F(4) = '1' then
                  Mem_Addr <= SP;
                  SP <= std_logic_vector(unsigned(SP) + 1);
                  State <= Exec2;
                end if;
                -- END op-codes from page 117
                -- OP-code from page 118
                -- RETI
              when X"D9" =>
                Mem_Addr <= SP;
                SP <= std_logic_vector(unsigned(SP) + 1);
                State <= Exec2;

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

                -- INC A
              when X"3C" =>
                F <= Alu_Flags;
                A <= Alu_Result(7 downto 0);
                -- INC B
              when X"04" =>
                F <= Alu_Flags;
                B <= Alu_Result(7 downto 0);
                -- INC C
              when X"0C" =>
                F <= Alu_Flags;
                C <= Alu_Result(7 downto 0);
                -- INC D
              when X"14" =>
                F <= Alu_Flags;
                D <= Alu_Result(7 downto 0);
                -- INC E
              when X"1C" =>
                F <= Alu_Flags;
                E <= Alu_Result(7 downto 0);
                -- INC H
              when X"24" =>
                F <= Alu_Flags;
                H <= Alu_Result(7 downto 0);
                -- INC L
              when X"2C" =>
                F <= Alu_Flags;
                L <= Alu_Result(7 downto 0);
                -- INC (HL)
              when X"34" =>
                Alu_A <= X"00" & Mem_Read;
                Alu_Mode <= Alu_Inc;
                Alu_Flags_In <= F;
                State <= Exec3;

                -- DEC A
              when X"3D" =>
                F <= Alu_Flags;
                A <= Alu_Result(7 downto 0);
                -- DEC B
              when X"05" =>
                F <= Alu_Flags;
                B <= Alu_Result(7 downto 0);
                -- DEC C
              when X"0D" =>
                F <= Alu_Flags;
                C <= Alu_Result(7 downto 0);
                -- DEC D
              when X"15" =>
                F <= Alu_Flags;
                D <= Alu_Result(7 downto 0);
                -- DEC E
              when X"1D" =>
                F <= Alu_Flags;
                E <= Alu_Result(7 downto 0);
                -- DEC H
              when X"25" =>
                F <= Alu_Flags;
                H <= Alu_Result(7 downto 0);
                -- DEC L
              when X"2D" =>
                F <= Alu_Flags;
                L <= Alu_Result(7 downto 0);
                -- DEC (HL)
              when X"35" =>
                Alu_A <= X"00" & Mem_Read;
                Alu_Mode <= Alu_Dec;
                Alu_Flags_In <= F;
                State <= Exec3;

                -- ADD HL, BC
              when X"09" =>
                H <= Alu_Result(15 downto 8);
                L <= Alu_Result(7 downto 0);
                F <= Alu_Flags;
                -- ADD HL, DE
              when X"19" =>
                H <= Alu_Result(15 downto 8);
                L <= Alu_Result(7 downto 0);
                F <= Alu_Flags;
                -- ADD HL, HL
              when X"29" =>
                H <= Alu_Result(15 downto 8);
                L <= Alu_Result(7 downto 0);
                F <= Alu_Flags;
                -- ADD HL, SP
              when X"39" =>
                H <= Alu_Result(15 downto 8);
                L <= Alu_Result(7 downto 0);
                F <= Alu_Flags;

                -- ADD SP, n (High or low flags????)
              when X"E8" =>
                Alu_A <= SP;
                Alu_B(6 downto 0) <= Mem_Read(6 downto 0);
                Alu_B(15 downto 7) <= (others => Mem_Read(7));
                Alu_Mode <= Alu_Add;
                Alu_High_Flags <= '0';  -- My guess. Check!
                State <= Exec3;

                -- JP nn
              when X"C3" =>
                Tmp_8Bit <= Mem_Read;
                Mem_Addr <= PC;
                PC <= std_logic_vector(unsigned(PC) + 1);
                State <= Exec3;
                -- JP NZ,nn
              when X"C2" =>
                Tmp_8Bit <= Mem_Read;
                Mem_Addr <= PC;
                PC <= std_logic_vector(unsigned(PC) + 1);
                State <= Exec3;
                -- JP Z,nn
              when X"CA" =>
                Tmp_8Bit <= Mem_Read;
                Mem_Addr <= PC;
                PC <= std_logic_vector(unsigned(PC) + 1);
                State <= Exec3;
                -- JP NC,nn
              when X"D2" =>
                Tmp_8Bit <= Mem_Read;
                Mem_Addr <= PC;
                PC <= std_logic_vector(unsigned(PC) + 1);
                State <= Exec3;
                -- JP C,nn
              when X"DA" =>
                Tmp_8Bit <= Mem_Read;
                Mem_Addr <= PC;
                PC <= std_logic_vector(unsigned(PC) + 1);
                State <= Exec3;
                -- JR n
              when X"18" =>
                PC <= std_logic_vector(signed(Mem_Read) + signed(PC));
                -- JR NZ, n
              when X"20" =>
                if F(7) = '0' then
                  PC <= std_logic_vector(signed(Mem_Read) + signed(PC));
                end if;
                -- JR Z, n
              when X"28" =>
                if F(7) = '1' then
                  PC <= std_logic_vector(signed(Mem_Read) + signed(PC));
                end if;
                -- JR NC, n
              when X"30" =>
                if F(4) = '0' then
                  PC <= std_logic_vector(signed(Mem_Read) + signed(PC));
                end if;
                -- JR C, n
              when X"38" =>
                if F(4) = '1' then
                  PC <= std_logic_vector(signed(Mem_Read) + signed(PC));
                end if;

                -- CALL nn
              when X"CD" =>
                Tmp_Addr(7 downto 0) <= Mem_Read;
                Mem_Addr <= PC;
                PC <= std_logic_vector(unsigned(PC) + 1);
                State <= Exec3;

                -- CALL NZ, nn
              when X"C4" =>
                Tmp_Addr(7 downto 0) <= Mem_Read;
                Mem_Addr <= PC;
                PC <= std_logic_vector(unsigned(PC) + 1);
                State <= Exec3;
                -- CALL Z, nn
              when X"CC" =>
                Tmp_Addr(7 downto 0) <= Mem_Read;
                Mem_Addr <= PC;
                PC <= std_logic_vector(unsigned(PC) + 1);
                State <= Exec3;
                -- CALL NC, nn
              when X"D4" =>
                Tmp_Addr(7 downto 0) <= Mem_Read;
                Mem_Addr <= PC;
                PC <= std_logic_vector(unsigned(PC) + 1);
                State <= Exec3;
                -- CALL C, nn
              when X"DC" =>
                Tmp_Addr(7 downto 0) <= Mem_Read;
                Mem_Addr <= PC;
                PC <= std_logic_vector(unsigned(PC) + 1);
                State <= Exec3;

                -- RST 0x00
              when X"C7" =>
                Tmp := std_logic_vector(unsigned(SP) - 1);
                SP <= Tmp;
                Mem_Write <= PC(7 downto 0);
                Mem_Addr <= Tmp;
                Mem_Write_Enable <= '1';
                PC <= X"0000";
                -- RST 0x08
              when X"CF" =>
                Tmp := std_logic_vector(unsigned(SP) - 1);
                SP <= Tmp;
                Mem_Write <= PC(7 downto 0);
                Mem_Addr <= Tmp;
                Mem_Write_Enable <= '1';
                PC <= X"0008";
                -- RST 0x10
              when X"D7" =>
                Tmp := std_logic_vector(unsigned(SP) - 1);
                SP <= Tmp;
                Mem_Write <= PC(7 downto 0);
                Mem_Addr <= Tmp;
                Mem_Write_Enable <= '1';
                PC <= X"0010";
                -- RST 0x18
              when X"DF" =>
                Tmp := std_logic_vector(unsigned(SP) - 1);
                SP <= Tmp;
                Mem_Write <= PC(7 downto 0);
                Mem_Addr <= Tmp;
                Mem_Write_Enable <= '1';
                PC <= X"0018";
                -- RST 0x20
              when X"E7" =>
                Tmp := std_logic_vector(unsigned(SP) - 1);
                SP <= Tmp;
                Mem_Write <= PC(7 downto 0);
                Mem_Addr <= Tmp;
                Mem_Write_Enable <= '1';
                PC <= X"0020";
                -- RST 0x28
              when X"EF" =>
                Tmp := std_logic_vector(unsigned(SP) - 1);
                SP <= Tmp;
                Mem_Write <= PC(7 downto 0);
                Mem_Addr <= Tmp;
                Mem_Write_Enable <= '1';
                PC <= X"0028";
                -- RST 0x30
              when X"F7" =>
                Tmp := std_logic_vector(unsigned(SP) - 1);
                SP <= Tmp;
                Mem_Write <= PC(7 downto 0);
                Mem_Addr <= Tmp;
                Mem_Write_Enable <= '1';
                PC <= X"0030";
                -- RST 0x38
              when X"FF" =>
                Tmp := std_logic_vector(unsigned(SP) - 1);
                SP <= Tmp;
                Mem_Write <= PC(7 downto 0);
                Mem_Addr <= Tmp;
                Mem_Write_Enable <= '1';
                PC <= X"0038";

                -- RET, and all other RET when they have decided to jump
              when X"C9" | X"C0" | X"C8" | X"D0" | X"D8" | X"D9" =>
                Tmp_8Bit <= Mem_Read;
                Mem_Addr <= SP;
                SP <= std_logic_vector(unsigned(SP) + 1);
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

                -- INC (HL)
              when X"34" =>
                Mem_Addr <= H & L;
                Mem_Write <= Alu_Result(7 downto 0);
                Mem_Write_Enable <= '1';
                F <= Alu_Flags;

                -- DEC (HL)
              when X"35" =>
                Mem_Addr <= H & L;
                Mem_Write <= Alu_Result(7 downto 0);
                Mem_Write_Enable <= '1';
                F <= Alu_Flags;

                -- ADD SP, n
              when X"E8" =>
                H <= Alu_Result(15 downto 8);
                L <= Alu_Result(7 downto 0);
                F <= Alu_Flags;

                -- JP nn
              when X"C3" =>
                PC <= Mem_Read & Tmp_8Bit;
                -- JP NZ,nn
              when X"C2" =>
                if F(7) = '0' then
                  PC <= Mem_Read & Tmp_8Bit;
                end if;
                -- JP Z,nn
              when X"CA" =>
                if F(7) = '1' then
                  PC <= Mem_Read & Tmp_8Bit;
                end if;
                -- JP NC,nn
              when X"D2" =>
                if F(4) = '0' then
                  PC <= Mem_Read & Tmp_8Bit;
                end if;
                -- JP C,nn
              when X"DA" =>
                if F(4) = '1' then
                  PC <= Mem_Read & Tmp_8Bit;
                end if;

                -- CALL nn
              when X"CD" =>
                Tmp_Addr(15 downto 8) <= Mem_Read;
                Tmp := std_logic_vector(unsigned(SP) - 1);
                SP <= Tmp;
                Mem_Addr <= Tmp;
                Mem_Write <= PC(15 downto 8);
                Mem_Write_Enable <= '1';
                State <= Exec4;

                -- CALL NZ, nn
              when X"C4" =>
                if F(7) = '0' then
                  Tmp_Addr(15 downto 8) <= Mem_Read;
                  Tmp := std_logic_vector(unsigned(SP) - 1);
                  SP <= Tmp;
                  Mem_Addr <= Tmp;
                  Mem_Write <= PC(15 downto 8);
                  Mem_Write_Enable <= '1';
                  State <= Exec4;
                end if;
                -- CALL Z, nn
              when X"CC" =>
                if F(7) = '1' then
                  Tmp_Addr(15 downto 8) <= Mem_Read;
                  Tmp := std_logic_vector(unsigned(SP) - 1);
                  SP <= Tmp;
                  Mem_Addr <= Tmp;
                  Mem_Write <= PC(15 downto 8);
                  Mem_Write_Enable <= '1';
                  State <= Exec4;
                end if;
                -- CALL NC, nn
              when X"D4" =>
                if F(4) = '0' then
                  Tmp_Addr(15 downto 8) <= Mem_Read;
                  Tmp := std_logic_vector(unsigned(SP) - 1);
                  SP <= Tmp;
                  Mem_Addr <= Tmp;
                  Mem_Write <= PC(15 downto 8);
                  Mem_Write_Enable <= '1';
                  State <= Exec4;
                end if;
                -- CALL C, nn
              when X"DC" =>
                if F(4) = '1' then
                  Tmp_Addr(15 downto 8) <= Mem_Read;
                  Tmp := std_logic_vector(unsigned(SP) - 1);
                  SP <= Tmp;
                  Mem_Addr <= Tmp;
                  Mem_Write <= PC(15 downto 8);
                  Mem_Write_Enable <= '1';
                  State <= Exec4;
                end if;

                -- RET, and all other RET when they have decided to jump
              when X"C9" | X"C0" | X"C8" | X"D0" | X"D8" =>
                PC <= Mem_Read & Tmp_8Bit;
                -- RETI
              when X"D9" =>
                PC <= Mem_Read & Tmp_8Bit;
                Interrupts_Enabled <= '1';

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
                -- CALL nn
              when X"CD" =>
                PC <= Tmp_Addr;
                Tmp := std_logic_vector(unsigned(SP) - 1);
                SP <= Tmp;
                Mem_Addr <= Tmp;
                Mem_Write <= PC(7 downto 0);
                Mem_Write_Enable <= '1';

                -- CALL NZ, nn
              when X"C4" =>
                PC <= Tmp_Addr;
                Tmp := std_logic_vector(unsigned(SP) - 1);
                SP <= Tmp;
                Mem_Addr <= Tmp;
                Mem_Write <= PC(7 downto 0);
                Mem_Write_Enable <= '1';
                -- CALL Z, nn
              when X"CC" =>
                PC <= Tmp_Addr;
                Tmp := std_logic_vector(unsigned(SP) - 1);
                SP <= Tmp;
                Mem_Addr <= Tmp;
                Mem_Write <= PC(7 downto 0);
                Mem_Write_Enable <= '1';
                -- CALL NC, nn
              when X"D4" =>
                PC <= Tmp_Addr;
                Tmp := std_logic_vector(unsigned(SP) - 1);
                SP <= Tmp;
                Mem_Addr <= Tmp;
                Mem_Write <= PC(7 downto 0);
                Mem_Write_Enable <= '1';
                -- CALL C, nn
              when X"DC" =>
                PC <= Tmp_Addr;
                Tmp := std_logic_vector(unsigned(SP) - 1);
                SP <= Tmp;
                Mem_Addr <= Tmp;
                Mem_Write <= PC(7 downto 0);
                Mem_Write_Enable <= '1';

              when others =>
            end case;
          when Mb_Exec =>
            -- Multi-byte OP-codes.
            State <= Waiting;
            MB_IR <= Mem_Read;
            Tmp := IR & Mem_Read;
            
            case (Tmp) is
              -- STOP Not correct implementation, halts instead
              when X"1000" =>
                State <= Halted;
                -- OP-codes from page 94
                -- SWAP A
              when X"CB37" =>
                A(7 downto 4) <= A(3 downto 0);
                A(3 downto 0) <= A(7 downto 4);
                if A = X"00" then
                  F(7) <= '1';
                else
                  F(7) <= '0';
                end if;
                F(6 downto 0) <= (others => '0');
                -- SWAP B
              when X"CB30" =>
                B(7 downto 4) <= B(3 downto 0);
                B(3 downto 0) <= B(7 downto 4);
                if B = X"00" then
                  F(7) <= '1';
                else
                  F(7) <= '0';
                end if;
                F(6 downto 0) <= (others => '0');
                -- SWAP C
              when X"CB31" =>
                C(7 downto 4) <= C(3 downto 0);
                C(3 downto 0) <= C(7 downto 4);
                if C = X"00" then
                  F(7) <= '1';
                else
                  F(7) <= '0';
                end if;
                F(6 downto 0) <= (others => '0');
                -- SWAP D
              when X"CB32" =>
                D(7 downto 4) <= D(3 downto 0);
                D(3 downto 0) <= D(7 downto 4);
                if D = X"00" then
                  F(7) <= '1';
                else
                  F(7) <= '0';
                end if;
                F(6 downto 0) <= (others => '0');
                -- SWAP E
              when X"CB33" =>
                E(7 downto 4) <= E(3 downto 0);
                E(3 downto 0) <= E(7 downto 4);
                if E = X"00" then
                  F(7) <= '1';
                else
                  F(7) <= '0';
                end if;
                F(6 downto 0) <= (others => '0');
                -- SWAP H
              when X"CB34" =>
                H(7 downto 4) <= H(3 downto 0);
                H(3 downto 0) <= H(7 downto 4);
                if H = X"00" then
                  F(7) <= '1';
                else
                  F(7) <= '0';
                end if;
                F(6 downto 0) <= (others => '0');
                -- SWAP L
              when X"CB35" =>
                L(7 downto 4) <= L(3 downto 0);
                L(3 downto 0) <= L(7 downto 4);
                if L = X"00" then
                  F(7) <= '1';
                else
                  F(7) <= '0';
                end if;
                F(6 downto 0) <= (others => '0');
                -- SWAP (HL)
              when X"CB36" =>
                Mem_Addr <= H & L;
                State <= Mb_Exec2;
              when others =>
            end case; -- End case IR & Mem_Read
          when Mb_Exec2 =>
            State <= Waiting;
            Tmp := IR & MB_IR;
            case (Tmp) is
              -- SWAP (HL)
              when X"CB36" =>
                Mem_Write(7 downto 4) <= Mem_Read(3 downto 0);
                Mem_Write(3 downto 0) <= Mem_Read(7 downto 4);
                Mem_Addr <= H & L;
                Mem_Write_Enable <= '1';
                if Mem_Read = X"00" then
                  F(7) <= '1';
                else
                  F(7) <= '0';
                end if;
                F(6 downto 0) <= (others => '0');
              when others =>
            end case; -- End case IR & MB_IR
          when others =>
        end case; -- End case State 
      end if;
    end if;
  end process;
  

end Cpu_Implementation;
