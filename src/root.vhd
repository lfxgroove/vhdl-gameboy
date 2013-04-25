library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_textio.all;
use ieee.numeric_std.all;

entity Root is
  port (Clk, Rst : in std_logic;
        vgaRed, vgaGreen : out std_logic_vector(2 downto 0);
        vgaBlue : out std_logic_vector(2 downto 1);
        Hsync, Vsync : out std_logic);
end Root;

architecture Behavioural of Root is
  component Gpu_Logic
    port ( Clk,Rst : in  std_logic;
           vgaRed, vgaGreen : out  std_logic_vector (2 downto 0);
           vgaBlue : out  std_logic_vector (2 downto 1);
           Hsync,Vsync : out  std_logic;
           Gpu_Write : in std_logic_vector(7 downto 0);
           Gpu_Read : out std_logic_vector(7 downto 0);
           Gpu_Addr : in std_logic_vector(15 downto 0);
           Gpu_Write_Enable : in std_logic);
  end component;

  component Cpu
    port(Clk, Reset : in std_logic;
         Mem_Write : out std_logic_vector(7 downto 0);
         Mem_Read : in std_logic_vector(7 downto 0);
         Mem_Addr : out std_logic_vector(15 downto 0);
         Mem_Write_Enable : out std_logic);
  end component;

  component Bus_Controller
    port (Clk, Reset : in std_logic;
          Mem_Write : in std_logic_vector(7 downto 0);
          Mem_Read : out std_logic_vector(7 downto 0);
          Mem_Addr : in std_logic_vector(15 downto 0);
          Mem_Write_Enable : in std_logic;
          -- Output to the GPU
          Gpu_Write : out std_logic_vector(7 downto 0);
          Gpu_Read : in std_logic_vector(7 downto 0);
          Gpu_Addr : out std_logic_vector(15 downto 0);
          Gpu_Write_Enable : out std_logic;
          -- These three signals writes to the large rom.
          Rom_Write_Enable : in std_logic;
          Rom_Addr : in std_logic_vector(15 downto 0);
          Rom_Write : in std_logic_vector(7 downto 0));
  end component;

  --Local signals
  signal Mem_Write : std_logic_vector(7 downto 0);
  signal Mem_Read : std_logic_vector(7 downto 0);
  signal Mem_Addr : std_logic_vector(15 downto 0);
  signal Mem_Write_Enable : std_logic;
  signal Rom_Write_Enable : std_logic := '0';
  signal Rom_Addr : std_logic_vector(15 downto 0) := X"0000";
  signal Rom_Write : std_logic_vector(7 downto 0) := X"00";

  signal Gpu_Write : std_logic_vector(7 downto 0);
  signal Gpu_Read : std_logic_vector(7 downto 0);
  signal Gpu_Addr : std_logic_vector(15 downto 0);
  signal Gpu_Write_Enable : std_logic;
begin
  Gpu_Port : Gpu_Logic port map (
    Clk => Clk,
    Rst => Rst,
    vgaRed => vgaRed,
    vgaGreen => vgaGreen,
    vgaBlue => vgaBlue,
    Hsync => Hsync,
    Vsync => Vsync,
    Gpu_Write => Gpu_Write,
    Gpu_Read => Gpu_Read,
    Gpu_Addr => Gpu_Addr,
    Gpu_Write_Enable => Gpu_Write_Enable);

  Cpu_Port : Cpu port map (
    Clk => Clk,
    Reset => Rst,
    Mem_Write => Mem_Write,
    Mem_Read => Mem_Read,
    Mem_Addr => Mem_Addr,
    Mem_Write_Enable => Mem_Write_Enable);

  Bus_Port : Bus_Controller port map (
    Clk => Clk,
    Reset => Rst,
    Mem_Write => Mem_Write,
    Mem_Read => Mem_Read,
    Mem_Addr => Mem_Addr,
    Mem_Write_Enable => Mem_Write_Enable,
    Gpu_Write => Gpu_Write,
    Gpu_Read => Gpu_Read,
    Gpu_Addr => Gpu_Addr,
    Gpu_Write_Enable => Gpu_Write_Enable,
    Rom_Write_Enable => Rom_Write_Enable,
    Rom_Addr => Rom_Addr,
    Rom_Write => Rom_Write);

end Behavioural;
