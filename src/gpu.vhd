library ieee;
use ieee.std_logic_1164.all;
use IEEE.numeric_std.all;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity gpu is
    Port ( Clk,Rst : in  STD_LOGIC;
           vgaRed, vgaGreen : out  STD_LOGIC_VECTOR (2 downto 0);
           vgaBlue : out  STD_LOGIC_VECTOR (2 downto 1);
           Hsync,Vsync : out  STD_LOGIC);
end gpu;

architecture Behavioral of gpu is
  --component leddriver
  --  Port ( Clk,Rst : in  STD_LOGIC;
  --         ca,cb,cc,cd,ce,cf,cg,dp : out  STD_LOGIC;
  --         an : out  STD_LOGIC_VECTOR (3 downto 0);
  --         ledvalue : in  STD_LOGIC_VECTOR (15 downto 0));
  --end component;

  -- Screen size in large pixels
  constant Screen_Width : std_logic_vector(8 downto 0) := "010100000";  -- 160
  constant Screen_Height : std_logic_vector(8 downto 0) := "010010000";  -- 144
  -- Syncing constants in small pixels
  constant Hsync_Length : std_logic_vector(8 downto 0) := "0" & X"35";  -- 53
  constant Vsync_Length : std_logic_vector(8 downto 0) := "0" & X"0D";  -- 13
  constant Vsync_Start : std_logic_vector(8 downto 0) := "010100011"; -- 163
  -- Small pixel counters
  signal X_Counter,Y_Counter : std_logic_vector(9 downto 0) := "0000000000";
  -- BIG pixel counters
  signal Row : std_logic_vector(8 downto 0) := "000000000";
  signal Column : std_logic_vector(8 downto 0) := "000000000";
  signal Video : std_logic_vector(1 downto 0);
  signal Next_Pixel_Counter : std_logic_vector(1 downto 0) := "00";
  -- Small to big pixels sync
  signal Small_To_Big_X : std_logic_vector(1 downto 0) := "00";
  signal Small_To_Big_Y : std_logic_vector(1 downto 0) := "00";
  -- HS VS
  signal HS, VS : std_logic := '0';
begin
  -- Pixel clock generation.
  process(Clk)
  begin
    if rising_edge(Clk) then
      if Rst = '1' then
        Next_Pixel_Counter <= "00";
      else
        Next_Pixel_Counter <= std_logic_vector(unsigned(Next_Pixel_Counter) + 1);
      end if;
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
          Column <= "0" & X"00";
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
      if unsigned(X_Counter) = 799 and Next_Pixel_Counter = "00" then
        Small_To_Big_Y <= std_logic_vector(unsigned(Small_To_Big_Y) + 1);
        if Small_To_Big_Y = "10" then
          Row <= std_logic_vector(unsigned(Column) + 1);
        end if;

        if unsigned(Y_Counter) = 520 then
          Y_Counter <= "0000000000";
        else
          Y_Counter <= std_logic_vector(unsigned(Y_Counter) + 1);
        end if;

        if unsigned(Y_Counter) = 490 then
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
  begin
    if rising_edge(Clk) then
      --if Row < Screen_Height then
      --  if Column < Screen_Width then
      --    if Next_Pixel_Counter = "11" then
      --      if unsigned(Column) < 10 then
      --        Video <= "11";
      --      else
      --        Video <= "00";
      --      end if;
      --    end if;
      --  else
      --    Video <= "10";
      --  end if;
      --else
      --  Video <= "10";
      --end if;
      if unsigned(Y_Counter) < 480 then
        if unsigned(X_Counter) < 640 then
          if Next_Pixel_Counter = "11" then
            Video <= X_Counter(1 downto 0);
          end if;
        else
          Video <= "00";
        end if;
      else
        Video <= "00";
      end if;
    end if;
  end process;

  --vgaRed(2 downto 0) <= "101"; -- (Video & Video(1));
  --vgaGreen(2 downto 0) <= "010"; -- (Video & Video(1));
  --vgaBlue(2 downto 1) <= "10"; -- (Video);
  vgaRed(2 downto 0) <= (Video & Video(1));
  vgaGreen(2 downto 0) <= (Video & Video(1));
  vgaBlue(2 downto 1) <= (Video);

  
end Behavioral;
