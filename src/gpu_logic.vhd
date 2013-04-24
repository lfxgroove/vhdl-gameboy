library ieee;
use ieee.std_logic_1164.all;
use IEEE.numeric_std.all;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity Gpu_Logic is
    Port ( Clk,Rst : in  std_logic;
           vgaRed, vgaGreen : out  std_logic_vector (2 downto 0);
           vgaBlue : out  std_logic_vector (2 downto 1);
           Hsync,Vsync : out  std_logic);
end Gpu_Logic;

architecture Behavioral of Gpu_Logic is
  component Gpu
    Port ( Clk,Rst : in  std_logic;
           vgaRed, vgaGreen : out  std_logic_vector (2 downto 0);
           vgaBlue : out  std_logic_vector (2 downto 1);
           Hsync,Vsync : out  std_logic;
           Current_Row : out std_logic_vector(7 downto 0);
           Next_Row : out std_logic;
           Row_Buffer_High : in std_logic_vector(159 downto 0);
           Row_Buffer_Low : in std_logic_vector(159 downto 0));
  end component;

  signal Current_Row : std_logic_vector(7 downto 0);
  signal Current_Row_Buffer_High : std_logic_vector(159 downto 0) := (2 | 4 | 6 | 158 => '0', others => '1');
  signal Current_Row_Buffer_Low : std_logic_vector(159 downto 0) := (2 | 3 | 4 | 6 => '0', others => '1');

  signal Next_Row : std_logic_vector(7 downto 0);
  signal Next_Row_Buffer_High : std_logic_vector(159 downto 0) := (2 | 4 | 6 | 158 => '0', others => '1');
  signal Next_Row_Buffer_Low : std_logic_vector(159 downto 0) := (2 | 3 | 4 | 6 => '0', others => '1');

  -- 8 kb video ram starting at address 0x8000
  type Video_Ram_Type is array(8191 downto 0) of std_logic_vector(7 downto 0);
  signal Video_Ram : Video_Ram_Type := (others => X"15");

  -- 160 byte ram for OBJ, sprites
  type Obj_Ram_Type is array(159 downto 0) of std_logic_vector(7 downto 0);
  signal Obj_Ram : Obj_Ram_Type := (others => X"15");

  signal Internal_Hsync, Internal_Vsync : std_logic;
  signal On_Next_Row : std_logic;

  type State_Type is (Read_Bg, Read_BG_B, Sprites, Sprites_B, Sprites_C, Done);
  signal State : State_Type := Done;
  signal Bg_Addr : std_logic_vector(7 downto 0) := X"00";
  signal Bg_Added : std_logic_vector(15 downto 0) := X"0000";

  -- BG offsets
  signal Bg_First_Sprite_Offset : std_logic_vector(15 downto 0) := X"0000";
  signal Bg_Sprite_Line_Offset : std_logic_vector(7 downto 0) := X"00";

  -- Sprite signals
  signal Sprite_Addr : std_logic_vector(7 downto 0) := X"00";
  signal Sprite_X, Sprite_Y, Sprite_Tile_Number, Sprite_Options : std_logic_vector(7 downto 0);

begin
  Gpu_Port : Gpu port map (
    Clk => Clk,
    Rst => Rst,
    vgaRed => vgaRed,
    vgaGreen => vgaGreen,
    vgaBlue => vgaBlue,
    Hsync => Internal_Hsync,
    Vsync => Internal_Vsync,
    Current_Row => Current_Row,
    Next_Row => On_Next_Row,
    Row_Buffer_High => Current_Row_Buffer_High,
    Row_Buffer_Low => Current_Row_Buffer_Low);

  Hsync <= Internal_Hsync;
  Vsync <= Internal_Vsync;

  -- Process for outputting next scanline
  process (Clk)
  begin
    if rising_edge(Clk) then
      if Rst = '1' then
        Current_Row_Buffer_Low <= (others => '0');
        Current_Row_Buffer_High <= (others => '0');
      elsif On_Next_Row = '1' then
        Current_Row_Buffer_Low <= Next_Row_Buffer_Low;
        Current_Row_Buffer_High <= Next_Row_Buffer_High;
      end if;
    end if;
  end process;

  process (Clk)
    variable Sprite_Tmp_Addr : std_logic_vector(15 downto 0);
    variable Sprite_High_Data : std_logic_vector(7 downto 0);
    variable Sprite_Low_Data : std_logic_vector(7 downto 0);
    variable Sprite_Tmp_X : integer range 0 to 255;
    variable Tmp_Addr : integer range 0 to 65535;
  begin
    if rising_edge(Clk) then
      if Rst = '1' then
        Next_Row_Buffer_Low <= (others => '0');
        Next_Row_Buffer_High <= (others => '0');
      elsif On_Next_Row = '1' then
        if unsigned(Current_Row) > 143 then
          Next_Row <= X"00";
          Bg_First_Sprite_Offset <= X"0000";
          Bg_Sprite_Line_Offset <= X"00";
        else
          Next_Row <= std_logic_vector(unsigned(Current_Row) + 1);
        end if;
        -- TODO: Reset other stuff
        State <= Read_Bg;
        if Bg_Sprite_Line_Offset = X"07" then
          Bg_Sprite_Line_Offset <= X"00";
          Bg_First_Sprite_Offset <= std_logic_vector(unsigned(Bg_First_Sprite_Offset) + 32);
        else
          Bg_Sprite_Line_Offset <= std_logic_vector(unsigned(Bg_Sprite_Line_Offset) + 1);
        end if;
        Bg_Added <= X"0000";
      else
        case State is
          when Done =>
            null;
          when Read_Bg =>
            --TODO: Switch between two mem locations, 1800 should be able to be replaced
            Tmp_Addr := to_integer(unsigned(Bg_First_Sprite_Offset) + 6144 + unsigned(Bg_Added));
            Bg_Addr <= Video_Ram(Tmp_Addr);
            State <= Read_Bg_B;
          when Read_Bg_B =>
            if unsigned(Bg_Added) = 20 then
              State <= Sprites;
              Sprite_Addr <= X"00";
            else
              Tmp_Addr := to_integer(unsigned(Bg_Addr) * 16 + unsigned(Next_Row));
              
              Next_Row_Buffer_High(7 downto 0) <= Video_Ram(Tmp_Addr);
              Next_Row_Buffer_Low(7 downto 0) <= Video_Ram(Tmp_Addr + 1);
              Next_Row_Buffer_High(159 downto 8) <= Next_Row_Buffer_High(151 downto 0);
              Next_Row_Buffer_Low(159 downto 8) <= Next_Row_Buffer_Low(151 downto 0);
              Bg_Added <= std_logic_vector(unsigned(Bg_Added) + 1);
              State <= Read_Bg;
            end if;
          when Sprites =>
            Sprite_Y <= Obj_Ram(to_integer(unsigned(Sprite_Addr)));
            Sprite_X <= Obj_Ram(to_integer(unsigned(Sprite_Addr) + 1));
            State <= Sprites_B;
          when Sprites_B =>
            Sprite_Tile_Number <= Obj_Ram(to_integer(unsigned(Sprite_Addr) + 2));
            Sprite_Options <= Obj_Ram(to_integer(unsigned(Sprite_Addr) + 3));
            State <= Sprites_C;
          when Sprites_C =>
            if unsigned(Sprite_Y) <= unsigned(Next_Row) + 16
              and unsigned(Sprite_Y) + 8 > unsigned(Next_Row) + 16 then
              -- DRAW!
              -- TODO: Replace 0 with a more suitable address
              Sprite_Tmp_Addr := std_logic_vector(unsigned(Sprite_Tile_Number) * 16
                                                  + unsigned(Next_Row) - unsigned(Sprite_Y) + 16 + 0);
              Sprite_High_Data := Video_Ram(to_integer(unsigned(Sprite_Tmp_Addr)));
              Sprite_Low_Data := Video_Ram(to_integer(unsigned(Sprite_Tmp_Addr) + 1));
              for I in 7 downto 0 loop
                Sprite_Tmp_X := I + to_integer(unsigned(Sprite_X)) - 8;
                -- TODO: Check if the sprite is above or below and if the bg is
                -- transparent
                if Sprite_Options(7) = '1' then
                  -- If below background:
                  if Next_Row_Buffer_High(Sprite_Tmp_X) = '0'
                    and Next_Row_Buffer_Low(Sprite_Tmp_X) = '0' then
                    Next_Row_Buffer_High(Sprite_Tmp_X) <= Sprite_High_Data(I);
                    Next_Row_Buffer_Low(Sprite_Tmp_X) <= Sprite_Low_Data(I);
                  end if;
                else
                  -- If above background
                  Next_Row_Buffer_High(Sprite_Tmp_X) <= Sprite_High_Data(I);
                  Next_Row_Buffer_Low(Sprite_Tmp_X) <= Sprite_Low_Data(I);
                end if;
              end loop;
            end if;

            -- Double check the value 9C
            if Sprite_Addr = X"9C" then
              State <= Done;
            else
              Sprite_Addr <= std_logic_vector(unsigned(Sprite_Addr) + 4);
            end if;
        end case;
      end if;
    end if;
  end process;
  
end Behavioral;
