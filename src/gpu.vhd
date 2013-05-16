library ieee;
use ieee.std_logic_1164.all;
use IEEE.numeric_std.all;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity Gpu is
    Port ( Clk,Rst : in  STD_LOGIC;
           vgaRed, vgaGreen : out  STD_LOGIC_VECTOR (2 downto 0);
           vgaBlue : out  STD_LOGIC_VECTOR (2 downto 1);
           Hsync,Vsync : out  STD_LOGIC;
           Current_Row : out std_logic_vector(7 downto 0);
           Next_Row : out std_logic;
           -- High bit and low bit of color
           Row_Buffer_High : in std_logic_vector(159 downto 0);
           Row_Buffer_Low : in std_logic_vector(159 downto 0);
           -- Data to gpu_logic to know when to draw a new screen
           Next_Screen : out std_logic;
           VBlank_Interrupt : out std_logic);
end Gpu;

architecture Behavioral of Gpu is
  --component leddriver
  --  Port ( Clk,Rst : in  STD_LOGIC;
  --         ca,cb,cc,cd,ce,cf,cg,dp : out  STD_LOGIC;
  --         an : out  STD_LOGIC_VECTOR (3 downto 0);
  --         ledvalue : in  STD_LOGIC_VECTOR (15 downto 0));
  --end component;

  -- Screen size in large pixels
  constant Screen_Width : std_logic_vector(7 downto 0) := "10100000";  -- 160
  constant Screen_Height : std_logic_vector(7 downto 0) := "10010000";  -- 144
  -- Small pixel counters
  signal X_Counter,Y_Counter : std_logic_vector(9 downto 0) := "0000000000";
  -- BIG pixel counters
  signal Row : std_logic_vector(7 downto 0) := "00000000";
  signal Column : std_logic_vector(7 downto 0) := "00000000";
  signal Video : std_logic_vector(1 downto 0);
  signal Next_Pixel_Counter : std_logic_vector(1 downto 0) := "00";
  -- Small to big pixels sync
  signal Small_To_Big_X : std_logic_vector(1 downto 0) := "00";
  signal Small_To_Big_Y : std_logic_vector(1 downto 0) := "00";
  -- HS VS
  signal HS, VS : std_logic := '0';
  
  type Palette_Type is array (0 to 3) of std_logic_vector(1 downto 0);
  
  constant Palette : Palette_Type := (
    "11",
    "10",
    "01",
    "00"
    );
begin
  Current_Row <= Row when unsigned(Row) <= 153 else
                 X"00";

  -- Pixel clock generation.
  process(Clk)
  begin
    if rising_edge(Clk) then
      Next_Pixel_Counter <= std_logic_vector(unsigned(Next_Pixel_Counter) + 1);
    end if;
  end process;

  -- Horizontal syncing logic
  process(Clk)
    -- Think of delays in VHDL....!
  begin
    if rising_edge(Clk) then
      if Next_Pixel_Counter = "11" then
        Small_To_Big_X <= std_logic_vector(unsigned(Small_To_Big_X) + 1);
        if Small_To_Big_X = "11" then
          Small_To_Big_X <= "00";
          Column <= std_logic_vector(unsigned(Column) + 1);
          
          --MAKE A VSYNC HAPPEN :D:D:D
        end if;
        
        if unsigned(X_Counter) = 670 then
          HS <= '1';
        elsif unsigned(X_Counter) = 766 then
          HS <= '0';
        end if;
        
        if unsigned(X_Counter) = 799 then
          Column <= X"00";
          X_Counter <= "0000000000";
          Small_To_Big_X <= "00";
        else
          X_Counter <= std_logic_vector(unsigned(X_Counter) + 1);
        end if;
      end if;
    end if;
  end process;

  -- Vertical syncing logic
  process(Clk)
  begin
    if rising_edge(Clk) then
      Next_Row <= '0';
      Next_Screen <= '0';
      VBlank_Interrupt <= '0';

      if unsigned(X_Counter) = 670 and Next_Pixel_Counter = "11" then
        Small_To_Big_Y <= std_logic_vector(unsigned(Small_To_Big_Y) + 1);
        if Small_To_Big_Y = "10" then   --10
          Row <= std_logic_vector(unsigned(Row) + 1);
          Next_Row <= '1';
          Small_To_Big_Y <= "00";
          if unsigned(Row) >= unsigned(Screen_Height) - 1 then
            Next_Screen <= '1';
          end if;
        end if;
      elsif unsigned(X_Counter) = 799 and Next_Pixel_Counter = "00" then

        if unsigned(Y_Counter) = 520 then
          Y_Counter <= "0000000000";
          Small_To_Big_Y <= "00";
          Row <= X"00";
        else
          Y_Counter <= std_logic_vector(unsigned(Y_Counter) + 1);
        end if;

        if unsigned(Y_Counter) = 480 then
          VBlank_Interrupt <= '1';
        elsif unsigned(Y_Counter) = 490 then
          VS <= '1';
        elsif unsigned(Y_Counter) = 491 then
          VS <= '0';
        end if;
      end if;
    end if;
  end process;

  Hsync <= HS;
  Vsync <= VS;

  -- Video
  process(Clk)
    variable Tmp_Video : std_logic_vector(1 downto 0);
  begin
    if rising_edge(Clk) then
      if unsigned(Y_Counter) < 480 then
        if unsigned(X_Counter) < 640 then
          if Next_Pixel_Counter = "11" then
            Tmp_Video(1) := Row_Buffer_High(to_integer(unsigned(Column)));
            Tmp_Video(0) := Row_Buffer_Low(to_integer(unsigned(Column)));
            Video <= Palette(to_integer(unsigned(Tmp_Video)));
          end if;
        else
          Video <= "00";
        end if;
      else
        Video <= "00";
      end if;
    end if;
  end process;

  vgaRed(2 downto 0) <= (Video & Video(1));
  vgaGreen(2 downto 0) <= (Video & Video(1));
  vgaBlue(2 downto 1) <= (Video);

  
end Behavioral;
