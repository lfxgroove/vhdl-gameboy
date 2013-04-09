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
  signal A, B, C, D, E, F, H, L : std_logic_vector(7 downto 0);
  -- Status register
  signal SR : std_logic_vector(7 downto 0);
  -- Stack pointer and program counter
  signal SP, PC : std_logic_vector(15 downto 0);

  type State_Type is (Waiting, Fetch, Exec);
  -- current state of the interpreter
  signal State : State_Type := Waiting;
  -- how long have we been waiting?
  signal Waited_Clks : std_logic_vector(15 downto 0) := X"0000";
  
  
begin
  -- 
  process(Clk)
  begin
    if rising_edge(Clk) then
      if (Reset = '1') then
        Waited_Clks <= X"0000";
        State <= Waiting;
        PC <= X"0000"; -- TODO Not the real default
        -- Reset SP?
        A <= X"01";
        B <= X"00";
      else
        
        Waited_Clks <= std_logic_vector(unsigned(Waited_Clks) + 1);
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
            case (Mem_Read) is
              -- LD A, B
              when X"78" =>
                B <= A;
              when others =>
                --FAKKA UR TOTALT OCH DÖ.
            end case;
            State <= Waiting;
          when others =>
        end case;
      end if;
    end if;
  end process;
    

end Cpu_Implementation;
