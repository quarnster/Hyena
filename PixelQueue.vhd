library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

--  Uncomment the following lines to use the declarations that are
--  provided for instantiating Xilinx primitive components.
--library UNISIM;
--use UNISIM.VComponents.all;

use work.Common.ALL;

entity PixelQueue is
	Port (
		clk : in std_logic;
		Continue : in std_logic;
		PixelIn : in Pixel;
		BaryIn : in Barycentric;
		PBaryIn : in Barycentric;
		NewPixel : in std_logic;
		Ready : out std_logic;
		Empty : out std_logic;
		NewPixelOut : out std_logic;
		PixelOut : out Pixel;
		BaryOut : out Barycentric;
		PBaryOut: out Barycentric
	);
end PixelQueue;

architecture Behavioral of PixelQueue is
	------- States ----------------------------------------------------------
	type state_type is (idle, output);
	signal state : state_type;

	constant QUEUE_SIZE : integer := 32;
	type PixelArray is array(QUEUE_SIZE-1 downto 0) of Pixel;
	type BaryArray is array(QUEUE_SIZE-1 downto 0) of Barycentric;

	signal PixelQueue : PixelArray;
	signal BaryQueue : BaryArray;
	signal PBaryQueue : BaryArray;

	signal writepos : std_logic_vector(4 downto 0) := "00000";
	signal readpos : std_logic_vector(4 downto 0) := "00000";
	signal queuesize : std_logic_vector(4 downto 0) := "00000";
begin

	process (clk)
	begin
		if clk'event and clk = '1' then
			if NewPixel = '1' then
				PixelQueue(conv_integer(writepos)) <= PixelIn;
				BaryQueue(conv_integer(writepos)) <= BaryIn;
				PBaryQueue(conv_integer(writepos)) <= PBaryIn;
				writepos <= writepos + '1';
			end if;
		end if;
	end process;

	process (clk)
		variable add : integer range -1 to 1 := 0;
	begin
		if clk'event and clk = '1' then
			add := 0;
			if NewPixel = '1' then
				add := add + 1;
			end if;
			if state = output then
				add := add - 1;
			end if;

			queuesize <= queuesize + add;
		end if;
	end process;

	process (clk)
	begin 
		if clk'event and clk = '1' then
			if state = idle and Continue = '1' and writepos /= readpos then
				PixelOut <= PixelQueue(conv_integer(readpos));
				BaryOut <= BaryQueue(conv_integer(readpos));
				PBaryOut <= PBaryQueue(conv_integer(readpos));

				state <= output;
			elsif state = output then
				readpos <= readpos + '1';
				state <= idle;
			end if;
		end if;
	end process;

	NewPixelOut <= '1' when state = output else '0';
	Empty <= '1' when queuesize = 0 else '0';	
	Ready <= '1' when queuesize < QUEUE_SIZE-1 else '0';
end Behavioral;
