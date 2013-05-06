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
           Row_Buffer_Low : in std_logic_vector(159 downto 0);
           Next_Screen : out std_logic);
  end component;

  signal Current_Row : std_logic_vector(7 downto 0);
  signal Current_Row_Buffer_High : std_logic_vector(159 downto 0) := (others => '0');
  signal Current_Row_Buffer_Low : std_logic_vector(159 downto 0) := (others => '0');

  signal Next_Row : std_logic_vector(7 downto 0);
  signal Next_Row_Buffer_High : std_logic_vector(167 downto 0) := (others => '0');
  signal Next_Row_Buffer_Low : std_logic_vector(167 downto 0) := (others => '0');

  -- 8 kb video ram starting at address 0x8000
  type Video_Ram_Type is array(8191 downto 0) of std_logic_vector(7 downto 0);
  signal Video_Ram : Video_Ram_Type := (others => X"F0");  -- was F0

  -- 160 byte ram for OBJ, sprites
  type Obj_Ram_Type is array(79 downto 0) of std_logic_vector(7 downto 0);
  signal Obj_Ram_Even, Obj_Ram_Odd : Obj_Ram_Type := (others => X"00");  --was 15

  signal Internal_Hsync, Internal_Vsync : std_logic;
  signal On_Next_Row : std_logic;

  type State_Type is (Read_Bg, Read_BG_B, Read_Bg_C, Read_Bg_D, Sprites, Sprites_B, Sprites_C, Sprites_D,
                      Sprites_E, Sprites_F, Sprites_G, Done);
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
  signal Sprite_Pixel_Counter : std_logic_vector(3 downto 0) := X"0";

  --Registers in the gpu
  signal Scroll_X, Scroll_Y : std_logic_vector(7 downto 0);
  signal LCD : std_logic_vector(7 downto 0);
  signal Stat : std_logic_vector(7 downto 0) := X"00";
  alias Stat_Mode : std_logic_vector is Stat(1 downto 0);
  --alias Stat_Int_Mode : std_logic_vector is Stat(6 downto 4);

  function reverse_any_vector (a: in std_logic_vector)
    return std_logic_vector is
    variable result: std_logic_vector(a'RANGE);
    alias aa: std_logic_vector(a'REVERSE_RANGE) is a;
  begin
    for i in aa'RANGE loop
      result(i) := aa(i);
    end loop;
    return result;
  end; -- function reverse_any_vector
  
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
    Row_Buffer_Low => Current_Row_Buffer_Low,
    Next_Screen => Next_Screen);
  
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
        Current_Row_Buffer_Low <= Next_Row_Buffer_Low(159 downto 0);
        Current_Row_Buffer_High <= Next_Row_Buffer_High(159 downto 0);
      end if;
    end if;
  end process;

  --For the Stat register, to update it's flags
  process(Clk)
  begin
    if rising_edge(Clk) then
      if Rst = '1' then
        Stat <= X"00";
      else
        if Internal_Hsync = '1' then
          Stat_Mode <= B"00";
        elsif Internal_Vsync = '1' then
          Stat_Mode <= B"01";
        elsif State = Sprites or State = Sprites_B then
          --The oam/obj memory is used in these 2 states
          Stat_Mode <= B"10";
        else
          Stat_Mode <= B"11";
        end if;
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
      elsif Next_Screen = '1' then
        Next_Row <= X"00";
      elsif On_Next_Row = '1' then
        Next_Row <= std_logic_vector(unsigned(Current_Row) + 1);
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

        -- Each bg bitmap is 8*8  big and the bg is 32 bitmaps wide
        Bg_First_Sprite_Offset <= std_logic_vector(0 + unsigned(Scroll_Y) / 8 * 32);
        -- Scroll Y % 8
        Bg_Sprite_Line_Offset <= B"00000" & Scroll_Y(2 downto 0); 
      elsif On_Next_Row = '1' then
        State <= Read_Bg;
        
        if Bg_Sprite_Line_Offset = X"07" then
          Bg_Sprite_Line_Offset <= X"00";
          -- 32 * 32 is the screen size in bitmaps
          Bg_First_Sprite_Offset <= std_logic_vector((unsigned(Bg_First_Sprite_Offset) + 32) mod (32 * 32));
        else
          Bg_Sprite_Line_Offset <= std_logic_vector(unsigned(Bg_Sprite_Line_Offset) + 1);
        end if;
        Bg_Added <= X"0000";
        
      else
        case State is
          when Done =>
            null;
          when Read_Bg =>
            --Select BG Code
            if LCD(3) = '1' then
              -- 0x1C00
              Sprite_Row_Addr <= std_logic_vector(unsigned(Bg_First_Sprite_Offset) + 7168 + unsigned(Bg_Added) + ((unsigned(Scroll_X) / 8) mod 32));
            else
              -- 0x1800
              Sprite_Row_Addr <= std_logic_vector(unsigned(Bg_First_Sprite_Offset) + 6144 + unsigned(Bg_Added) + ((unsigned(Scroll_X) / 8) mod 32));
            end if; 
            State <= Read_Bg_B;
          when Read_Bg_B =>
            --Sprite_Id <= Video_Ram(to_integer(unsigned(Bg_Map_Addr)));
            -- Sprite_Row <= Next_Row;
            --calculates the sprite's row address using the current sprite row
            --and the sprite id, ie: sprite_id*16 + sprite_row
            --Select BG Char
            if LCD(4) = '0' then
              Sprite_Row_Addr <= std_logic_vector(unsigned(Video_Ram(to_integer(signed(Sprite_Row_Addr))))
                                                  * 16 + unsigned(Bg_Sprite_Line_Offset) * 2 + 2048); 
            else
              Sprite_Row_Addr <= std_logic_vector(unsigned(Video_Ram(to_integer(unsigned(Sprite_Row_Addr))))
                                                  * 16 + unsigned(Bg_Sprite_Line_Offset) * 2); 
            end if;
            state <= Read_Bg_C;
          when Read_Bg_C =>
            if unsigned(Bg_Added) = 21 then
              State <= Sprites;            --was Sprites
              Sprite_Addr <= X"00";
              Next_Row_Buffer_High(167 - to_integer(unsigned(Scroll_X) mod 8) downto 0) <= Next_Row_Buffer_High(167 downto to_integer(unsigned(Scroll_X) mod 8));
              Next_Row_Buffer_Low(167 - to_integer(unsigned(Scroll_X) mod 8) downto 0) <= Next_Row_Buffer_Low(167 downto to_integer(unsigned(Scroll_X) mod 8));
            else
              --Flip the bits and shift right
              Next_Row_Buffer_High(167 downto 160) <= reverse_any_vector(Video_Ram(to_integer(unsigned(Sprite_Row_Addr))));
              Next_Row_Buffer_High(159 downto 0) <= Next_Row_Buffer_High(167 downto 8);
              State <= Read_Bg_D;
              -- increase the addr here so that the compiler understands that
              -- we want to use RAM :D:D:D:D
              Sprite_Row_Addr <= std_logic_vector(unsigned(Sprite_Row_Addr) + 1);
            end if;
          when Read_Bg_D =>
            --Flip the bits and shift right
            Next_Row_Buffer_Low(167 downto 160) <= reverse_any_vector(Video_Ram(to_integer(unsigned(Sprite_Row_Addr))));
            Next_Row_Buffer_Low(159 downto 0) <= Next_Row_Buffer_Low(167 downto 8);
            Bg_Added <= std_logic_vector(unsigned(Bg_Added) + 1);
            State <= Read_Bg;
          when Sprites =>
            --If we're past this address, we've read all the sprites available
            if unsigned(Sprite_Addr) = 80 then
              State <= Done;
            else
              Sprite_Y <= Obj_Ram_Even(to_integer(unsigned(Sprite_Addr)));
              Sprite_X <= Obj_Ram_Odd(to_integer(unsigned(Sprite_Addr)));
              Sprite_Addr <= std_logic_vector(unsigned(Sprite_Addr) + 1);
              State <= Sprites_B;
            end if;
          when Sprites_B =>
            Sprite_Tile_Number <= Obj_Ram_Even(to_integer(unsigned(Sprite_Addr)));
            Sprite_Options <= Obj_Ram_Odd(to_integer(unsigned(Sprite_Addr)));
            Sprite_Addr <= std_logic_vector(unsigned(Sprite_Addr) + 1);

            Sprite_Y <= std_logic_vector(unsigned(Next_Row) - unsigned(Sprite_Y) + 16);
 
            State <= Sprites_C;
          when Sprites_C =>
            -- HFlip check
            if Sprite_Options(5) = '1' then
              Sprite_Y <= std_logic_vector(7 - unsigned(Sprite_Y));
            end if;
            State <= Sprites_D;
          when Sprites_D =>
            if unsigned(Sprite_Y) >= 0 and
              unsigned(Sprite_Y) < 8 then
              -- We found something to draw, lets read it into some registers
              -- in the following states
              -- TODO: Replace 0 with a more suitable address
              if Sprite_Options(4) = '1' then
                Sprite_Row_Addr <= std_logic_vector(signed(Sprite_Tile_Number) * 16
                                                    + signed(Sprite_Y) * 2 + 2048);
              else
                Sprite_Row_Addr <= std_logic_vector(unsigned(Sprite_Tile_Number) * 16
                                                    + (unsigned(Sprite_Y) * 2)) ;
              end if; 
              State <= Sprites_E;
            else
              --Nothing in range to draw on screen, read next bg sprite
              State <= Sprites;
            end if;
          when Sprites_E =>
            --Read the high data from vram and increase the sprite row addr
            --VFlip bit
            if Sprite_Options(6) = '0' then
              Sprite_High_Data <= reverse_any_vector(Video_Ram(to_integer(unsigned(Sprite_Row_Addr))));
            else
              Sprite_High_Data <= Video_Ram(to_integer(unsigned(Sprite_Row_Addr)));
            end if; 
            Sprite_Row_Addr <= std_logic_vector(unsigned(Sprite_Row_Addr) + 1);
            State <= Sprites_F;
          when Sprites_F =>
            --Read the low data from vram
            --VFlip bit
            if Sprite_Options(6) = '0' then
              Sprite_Low_Data <= reverse_any_vector(Video_Ram(to_integer(unsigned(Sprite_Row_Addr))));
            else
              Sprite_Low_Data <= Video_Ram(to_integer(unsigned(Sprite_Row_Addr)));
            end if; 
            State <= Sprites_G;
            Sprite_Pixel_Counter <= X"0";
          when Sprites_G =>
            --HFlip bit check
            if Sprite_Pixel_Counter = X"8" then
              State <= Sprites;
            else
                Sprite_Tmp_X := to_integer(unsigned(Sprite_Pixel_Counter) + unsigned(Sprite_X)) - 8;
                -- TODO: Check if the sprite is above or below and if the bg is
                -- transparent
                if Sprite_Options(7) = '1' then
                  -- If below background:
                  if Next_Row_Buffer_High(Sprite_Tmp_X) = '0'
                    and Next_Row_Buffer_Low(Sprite_Tmp_X) = '0' then
                    Next_Row_Buffer_High(Sprite_Tmp_X) <=
                      Sprite_High_Data(to_integer(unsigned(Sprite_Pixel_Counter)));
                    Next_Row_Buffer_Low(Sprite_Tmp_X) <=
                      Sprite_Low_Data(to_integer(unsigned(Sprite_Pixel_Counter)));
                  end if;
                else
                  -- if above background
                  Next_Row_Buffer_High(Sprite_Tmp_X) <=
                    Sprite_High_Data(to_integer(unsigned(Sprite_Pixel_Counter)));
                  Next_Row_Buffer_Low(Sprite_Tmp_X) <=
                    Sprite_Low_Data(to_integer(unsigned(Sprite_Pixel_Counter)));
                end if;
                Sprite_Pixel_Counter <= std_logic_vector(unsigned(Sprite_Pixel_Counter) + 1);
            end if;
            --This line tells a story D:
            --for I in 7 downto 0 loop
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
          Video_Ram(to_integer(unsigned(Gpu_Addr(13 downto 0)))) <= Gpu_Write;
        elsif Gpu_Addr < X"FEA0" then
          -- Starts at 0xFE00.
          if Gpu_Addr(0) = '0' then
            Obj_Ram_Even(to_integer(unsigned(Gpu_Addr(7 downto 0)) srl 1)) <= Gpu_Write;
          else
            Obj_Ram_Odd(to_integer(unsigned(Gpu_Addr(7 downto 0)) srl 1)) <= Gpu_Write;
          end if;
        elsif Gpu_Addr = X"FF42" then
          Scroll_Y <= Gpu_Write;
        elsif Gpu_Addr = X"FF43" then
          Scroll_X <= Gpu_Write;
        elsif Gpu_Addr = X"FF40" then
          LCD <= Gpu_Write;
        end if;
      end if;
    end if;
  end process;
  
  -- Reading not implemented yet!
  Gpu_Read <= Stat when Gpu_Addr = X"FF41" else
              X"00";
end Behavioral;
