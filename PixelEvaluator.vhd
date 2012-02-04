-- $Id: PixelEvaluator.vhd,v 1.9 2005/06/09 11:32:10 quarn Exp $

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

use work.Common.ALL;

--  Uncomment the following lines to use the declarations that are
--  provided for instantiating Xilinx primitive components.
--library UNISIM;
--use UNISIM.VComponents.all;


entity PixelEvaluator is
	Port (
		clk	: in std_logic;
		NewData : in std_logic;
		Continue : in std_logic;
		E : in work.Common.Edge;
		Eres : in std_logic_vector(EDGE_C_SIZE-1 downto 0);
		P : in work.Common.Pixel;
		Inside : out std_logic;
		Result : out std_logic_vector(EDGE_C_SIZE-1 downto 0)
	);
end PixelEvaluator;

architecture Behavioral of PixelEvaluator is
	------- States ----------------------------------------------------------
	type state_type is (idle, traverse);
	signal state : state_type;

	------- Internal signals ------------------------------------------------
	signal Eresi : std_logic_vector(EDGE_C_SIZE-1 downto 0);
	signal x : std_logic_vector(3 downto 0);	-- TODO: hardcoded. allows tiles up to 2^4 pixels tall/wide.
	signal y : std_logic_vector(3 downto 0);

	signal iinside : std_logic;
begin

	process (clk)
	begin
		if clk'event and clk = '1' then
			case state is
				when	idle =>
					y <= (others=>'0');
					x <= (others=>'0');
					Eresi <= Eres;
					if NewData = '1' then
						state <= traverse;
					end if;
				when traverse =>
					if Continue = '1' then
						if x < TILE_SIZE -1 then
							-- zig/zag across the tile
							if y(0) = '0' then
								Eresi <= signed(Eresi) + signed(fp_base_conv(E.a, EDGE_AB_DECIMAL, EDGE_C_DECIMAL));
							else
								Eresi <= signed(Eresi) - signed(fp_base_conv(E.a, EDGE_AB_DECIMAL, EDGE_C_DECIMAL));
							end if;
							x <= x + 1;
						else
							x <= (others=>'0');
							if y < TILE_SIZE -1 then
								y <= y + 1;
							else
								state <= idle;
							end if;
							Eresi <= signed(Eresi) + signed(fp_base_conv(E.b, EDGE_AB_DECIMAL, EDGE_C_DECIMAL));
						end if;
					end if;
				when others => null;
			end case;
										
		end if;
	end process;


	iinside <= '1' when (Eresi(EDGE_C_SIZE-1) = '0' and Eresi /= 0) or ((Eresi = 0 and E.a/= 0 and E.a(EDGE_AB_SIZE-1) = '0') or (Eresi = 0 and E.a = 0 and E.b(EDGE_AB_SIZE-1) = '0')) else '0';
	Result <= Eresi;
	Inside <= '1' when iinside = '1' and state = traverse else '0';	-- TODO: tie breaker??
end Behavioral;
