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
  type State_Type is (Waiting, Fetch, Exec, Exec2, Exec3);
  -- current state of the interpreter
  signal State : State_Type := Waiting;
  -- how long have we been waiting?
  signal Waited_Clks : std_logic_vector(15 downto 0) := X"0000";

  -- tmp variable for calculations on full addresses
  signal Tmp_addr : std_logic_vector(15 downto 0);

begin
  -- 
  process(Clk)
  begin
    if rising_edge(Clk) then
      if (Reset = '1') then
        Waited_Clks <= X"0000";
        State <= Waiting;
        Mem_Write_Enable <= '0';
        PC <= X"0100"; -- see 3.2.3 at page 63
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
              when X"0A" =>
                Mem_Addr <= B & C;
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
                -- This instruction cannot be implemented
                -- with the current structure. An instruction
                -- register needs to be added, otherwise other
                -- states, like Exec2, are unusable since the
                -- contents of Mem_Read will most likely be
                -- destroyed.
                -- END op-codes from page 69 --

                -- OP-codes from page 70
                
                -- 5. LD A,(C) - F2
                -- Put value at address $FF00 + register C into A.
                -- Same as: LD A,($FF00+C)
                --     when X"F2" =>
                --       A <= Get_what_is_on_the_freaking_adress(std_logic_vector(unsigned (C) + X"FF00"));
                
                -- 6. LD(C),A - E2
                -- Put A into address $FF00 + register C.
                when X"E2" =>
                Mem_Addr <= std_logic_vector(unsigned (C) + X"FF00");
                Mem_Write <= A;
                Mem_Write_Enable <= '1';
                
                -- 7. LD A,(HLD) is same as LD A,(HL-) same as LDD A,(HL)
                -- Put value at address HL into A. Decrement HL.
                -- Same as: LD A,(HL) - DEC HL
              when X"3A" =>
                Mem_Addr <= H & L;
                Mem_Write <= A;
                Mem_Write_Enable <= '1';
                Tmp_addr <= std_logic_vector(unsigned(H & L) - X"0001");
                H <= Tmp_addr(15 downto 8);
                L <= Tmp_addr(7 downto 0);
                -- END of-codes from page 71
                
              when others =>
                --FAKKA UR TOTALT OCH D
            end case;
          when others =>
        end case;
      end if;
    end if;
  end process;
    

end Cpu_Implementation;
