-- $Id: RAM.vhd,v 1.4 2005/05/12 15:07:14 quarn Exp $

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

--  Uncomment the following lines to use the declarations that are
--  provided for instantiating Xilinx primitive components.
--library UNISIM;
--use UNISIM.VComponents.all;

entity RAM is
	generic
	(
		WORD_SIZE : integer := 8;
		WORD_COUNT : integer := 32;
		ADDR_SIZE : integer := 8
	);
    Port (
           clk : in std_logic;
		 addr : in std_logic_vector(ADDR_SIZE-1 downto 0);
           we : in std_logic;
           din : in std_logic_vector(WORD_SIZE-1 downto 0);
           dout : out std_logic_vector(WORD_SIZE-1 downto 0));
end RAM;

architecture Behavioral of RAM is
	type ram_type is array (WORD_COUNT-1 downto 0) of std_logic_vector(WORD_SIZE-1 downto 0);
	signal ram_array: ram_type := (others=>(others=>'0')); -- Clear RAM at startup, only used for simulation

begin
	process(clk)
	begin
		if clk'event and clk='1' then
			if we = '1' then
				ram_array(conv_integer(addr)) <= din;
			end if;

			
		end if;
	end process;
	process(clk)
	begin
		if clk'event and clk='1' then
			dout <= ram_array(conv_integer(addr));
		end if;
	end process;

end Behavioral;
								  