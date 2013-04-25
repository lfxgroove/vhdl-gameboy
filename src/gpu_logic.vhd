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
           Hsync,Vsync : out  std_logic;
           -- Writing to the memory and registers of the GPU
           Gpu_Write : in std_logic_vector(7 downto 0);
           Gpu_Read : out std_logic_vector(7 downto 0);
           Gpu_Addr : in std_logic_vector(15 downto 0);
           Gpu_Write_Enable : in std_logic);
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
  signal Video_Ram : Video_Ram_Type := (others => X"F0");

  -- 160 byte ram for OBJ, sprites
  type Obj_Ram_Type is array(159 downto 0) of std_logic_vector(7 downto 0);
  signal Obj_Ram : Obj_Ram_Type := (others => X"15");

  signal Internal_Hsync, Internal_Vsync : std_logic;
  signal On_Next_Row : std_logic;

  type State_Type is (Read_Bg, Read_BG_B, Read_Bg_C, Read_Bg_D, Sprites, Sprites_B, Sprites_C, Sprites_D, Sprites_E, Sprites_F, Done);
  signal State : State_Type := Done;
  signal Bg_Addr : std_logic_vector(7 downto 0) := X"00";
  signal Bg_Added : std_logic_vector(15 downto 0) := X"0000";

  -- High when the next screen should be drawn
  signal Next_Screen : std_logic := '0';

  -- BG offsets. Keeps track of the current row and the current pixel in the background
  signal Bg_First_Sprite_Offset : std_logic_vector(15 downto 0) := X"0000";
  signal Bg_Sprite_Line_Offset : std_logic_vector(7 downto 0) := X"00";

  -- Sprite signals
  signal Sprite_Addr : std_logic_vector(7 downto 0) := X"00";
  signal Sprite_X, Sprite_Y, Sprite_Tile_Number, Sprite_Options : std_logic_vector(7 downto 0);
  -- Used to calc offsets in the sprite address region
  signal Sprite_Row_Addr : std_logic_vector(15 downto 0) := X"0000";
  signal Sprite_Id : std_logic_vector(7 downto 0) := X"00";
  signal Sprite_Row : std_logic_vector(7 downto 0) := X"00";
  signal Sprite_High_Data : std_logic_vector(7 downto 0) := X"00";
  signal Sprite_Low_Data : std_logic_vector(7 downto 0) := X"00";
  --pointer to the current bg-sprite index
  signal Bg_Map_Addr : std_logic_vector(15 downto 0) := X"0000";

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

  -- Detect next row, and increment the row counter. Also tell the scanline
  -- generator when the entire screen has been drawn.
  process (Clk)
  begin
    if rising_edge(Clk) then
      if Rst = '1' then
        -- Reset the row generator as well
        Next_Screen <= '1';
      elsif On_Next_Row = '1' then
        if unsigned(Current_Row) > 143 then
          Next_Row <= X"00";
          Next_Screen <= '1';
        else
          Next_Row <= std_logic_vector(unsigned(Current_Row) + 1);
          Next_Screen <= '0';
        end if;
      else
        Next_Screen <= '0';
      end if;
    end if;
  end process;

  process (Clk) is
    variable Sprite_Tmp_X : integer range 0 to 255;
  begin
    if rising_edge(Clk) then
      -- Next_Screen also works as a reset for this process. See process above.
      if Next_Screen = '1' then
        Next_Row_Buffer_Low <= (others => '0');
        Next_Row_Buffer_High <= (others => '0');

        Bg_First_Sprite_Offset <= X"0000";
        Bg_Sprite_Line_Offset <= X"00";
      elsif On_Next_Row = '1' then
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
            --TODO: Switch between two mem locations, 6144 (0x1800) should be able to be replaced
            Bg_Map_Addr <= std_logic_vector(unsigned(Bg_First_Sprite_Offset) + 6144 + unsigned(Bg_Added));
            State <= Read_Bg_B;
          when Read_Bg_B =>
            --Sprite_Id <= Video_Ram(to_integer(unsigned(Bg_Map_Addr)));
            -- Sprite_Row <= Next_Row;
            --calculates the sprite's row address using the current sprite row
            --and the sprite id, ie: sprite_id*16 + sprite_row
            Sprite_Row_Addr <= std_logic_vector(unsigned(Video_Ram(to_integer(unsigned(Bg_Map_Addr)))) * 16 + unsigned(Bg_Sprite_Line_Offset)); 
            state <= Read_Bg_C;
          when Read_Bg_C =>
            if unsigned(Bg_Added) = 20 then
              State <= Sprites;
              Sprite_Addr <= X"00";
            else
              Next_Row_Buffer_High(7 downto 0) <= Video_Ram(to_integer(unsigned(Sprite_Row_Addr)));
              Next_Row_Buffer_High(159 downto 8) <= Next_Row_Buffer_High(151 downto 0);
              State <= Read_Bg_D;
              -- increase the addr here so that the compiler understands that
              -- we want to use RAM :D:D:D:
              Sprite_Row_Addr <= std_logic_vector(unsigned(Sprite_Row_Addr) + 1);
            end if;
          when Read_Bg_D =>
            Next_Row_Buffer_Low(7 downto 0) <= Video_Ram(to_integer(unsigned(Sprite_Row_Addr)));
            Next_Row_Buffer_Low(159 downto 8) <= Next_Row_Buffer_Low(151 downto 0);
            Bg_Added <= std_logic_vector(unsigned(Bg_Added) + 1);
            State <= Read_Bg;
          when Sprites =>
            --If we're past this address, we've read all the sprites available
            if unsigned(Sprite_Addr) = 160 then
              State <= Done;
            else
              Sprite_Y <= Obj_Ram(to_integer(unsigned(Sprite_Addr)));
              Sprite_X <= Obj_Ram(to_integer(unsigned(Sprite_Addr) + 1));
              Sprite_Addr <= std_logic_vector(unsigned(Sprite_Addr) + 2);
              State <= Sprites_B;
            end if;       
          when Sprites_B =>
            Sprite_Tile_Number <= Obj_Ram(to_integer(unsigned(Sprite_Addr)));
            Sprite_Options <= Obj_Ram(to_integer(unsigned(Sprite_Addr) + 1));
            Sprite_Addr <= std_logic_vector(unsigned(Sprite_Addr) + 2);
            State <= Sprites_C;
          when Sprites_C =>
            if unsigned(Sprite_Y) <= unsigned(Next_Row) + 16
              and unsigned(Sprite_Y) + 8 > unsigned(Next_Row) + 16 then
              -- We found something to draw, lets read it into some registers
              -- in the following states
              -- TODO: Replace 0 with a more suitable address
              Sprite_Row_Addr <= std_logic_vector(unsigned(Sprite_Tile_Number) * 16
                                                  + unsigned(Next_Row) - unsigned(Sprite_Y) + 16 + 0);  
              State <= Sprites_D;
            else
              --Nothing in range to draw on screen, read next bg sprite
              State <= Sprites;
            end if;
          when Sprites_D =>
            --Read the high data from vram and increase the sprite row addr
            Sprite_High_Data <= Video_Ram(to_integer(unsigned(Sprite_Row_Addr)));
            Sprite_Row_Addr <= std_logic_vector(unsigned(Sprite_Row_Addr) + 1);
            State <= Sprites_E;   
          when Sprites_E =>
            --Read the low data from vram
            Sprite_Low_Data <= Video_Ram(to_integer(unsigned(Sprite_Row_Addr)));
            State <= Sprites_F;
          when Sprites_F =>
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

  -- Writing to video memory
  process (Clk) is
  begin
    if rising_edge(Clk) then
      if Gpu_Write_Enable = '1' then
        if Gpu_Addr < X"A000" then
          -- Starts at 0x8000
          Video_Ram(to_integer(unsigned(Gpu_Addr(12 downto 0)))) <= Gpu_Write;
        elsif Gpu_Addr < X"FEA0" then
          -- Starts at 0xFE00.
          Obj_Ram(to_integer(unsigned(Gpu_Addr(4 downto 0)))) <= Gpu_Write;
        end if;
      end if;
    end if;
  end process;

  -- Reading not implemented yet!
  Gpu_Read <= X"00";
end Behavioral;
