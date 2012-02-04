-- $Id: TileOverlap.vhd,v 1.9 2005/05/27 14:31:27 quarn Exp $

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

use work.Common.ALL;

--  Uncomment the following lines to use the declarations that are
--  provided for instantiating Xilinx primitive components.
--library UNISIM;
--use UNISIM.VComponents.all;

entity TileOverlap is
	Port (
		clk : in std_logic;
		NewData : in std_logic;
		Continue : in std_logic;
		T : in Triangle;
		E : in Edges;
		P : out Pixel;
		Result : out EdgeResult;
		OutNewData : out std_logic;
		Ready : out std_logic
	);
end TileOverlap;

architecture Behavioral of TileOverlap is
	type state_type is (idle, calca, calcb, fix_edge, testoutside, traverse);
	signal state : state_type;
	signal next_state : state_type;

	signal ERes:  EdgeResult;
	signal TopLeft : Pixel;

	signal idx : integer range 0 to 2;
begin

	process (clk)
		variable topVertex : integer range 0 to 3;
		function selectTileCorner(p : std_logic_vector; sign: std_logic) return std_logic_vector is
		begin
			if sign = '0' then
				return p + fp_base_conv(TILE_SIZE, 0, PIXEL_DECIMAL);
			else
				return p;
			end if;
		end function;

		variable edgefix : std_logic_vector(EDGE_AB_SIZE+TILE_SHIFTi-1 downto 0);
	begin
		if clk'event and clk = '1' then
			case state is
				when idle =>
					if T(0).y < T(1).y then
						if T(0).y < T(2).y then
							topVertex := 0;
						else
							topVertex := 2;
						end if;
					else
						if T(1).y < T(2).y then
							topVertex := 1;
						else
							topVertex := 2;
						end if;
					end if;

					if NewData = '1' then
						TopLeft.x <= tile_clamp(T(topVertex).x);
						TopLeft.y <= tile_clamp(T(topVertex).y);

						idx <= 0;
						state <= calca;
						next_state <= testoutside;
					end if;
				when calca =>
					Eres(idx) <= E(idx).c + signed(E(idx).a) * unsigned(TopLeft.x);
					state <= calcb;
				when calcb =>
					Eres(idx) <= Eres(idx) + signed(E(idx).b) * unsigned(TopLeft.y);
					state <= fix_edge;
				when fix_edge =>
					Result(idx) <= Eres(idx);
					if E(idx).a(EDGE_AB_SIZE-1) = '0' then
						edgefix := E(idx).a & conv_std_logic_vector(0, TILE_SHIFTi);
					else
						edgefix := conv_std_logic_vector(0, EDGE_AB_SIZE+TILE_SHIFTi);
					end if;
					if E(idx).b(EDGE_AB_SIZE-1) = '0' then
						edgefix := edgefix + (E(idx).b & conv_std_logic_vector(0, TILE_SHIFTi));
					end if;
					Eres(idx) <= Eres(idx) + fp_base_conv(edgefix, EDGE_AB_DECIMAL, EDGE_C_DECIMAL);

					if idx = 2 then
						idx <= 0;
						state <= next_state;
					else
						idx <= idx + 1;
						state <= calca;
					end if;
				when testoutside =>
					if  TopLeft.y > T(0).y and TopLeft.y > T(1).y and TopLeft.y > T(2).y
					then
						-- triangle fully processed
						state <= idle;
					else 
						if TopLeft.y(TILE_SHIFTi) = '1' then
							if	(((E(0).a(EDGE_AB_SIZE-1)) and Eres(0)(EDGE_C_SIZE-1)) or
								 ((E(1).a(EDGE_AB_SIZE-1)) and Eres(1)(EDGE_C_SIZE-1)) or
								 ((E(2).a(EDGE_AB_SIZE-1)) and Eres(2)(EDGE_C_SIZE-1))) = '1'
							then
								-- process tile-line
								TopLeft.x <= TopLeft.x - fp_base_conv(TILE_SIZE, 0, PIXEL_DECIMAL);
								next_state <= traverse;
							else
								-- walk backwards (right)
								TopLeft.x <= TopLeft.x + fp_base_conv(TILE_SIZE, 0, PIXEL_DECIMAL);
							end if;
						else 
							if	((not E(0).a(EDGE_AB_SIZE-1) and Eres(0)(EDGE_C_SIZE-1)) or
								 (not E(1).a(EDGE_AB_SIZE-1) and Eres(1)(EDGE_C_SIZE-1)) or
								 (not E(2).a(EDGE_AB_SIZE-1) and Eres(2)(EDGE_C_SIZE-1))) = '1'
							then
								-- process tile-line
								TopLeft.x <= TopLeft.x + fp_base_conv(TILE_SIZE, 0, PIXEL_DECIMAL);
								next_state <= traverse;
							elsif conv_integer(TopLeft.x) = 0 then
								next_state <= traverse;
							else
								-- walk backwards (left)
								TopLeft.x <= TopLeft.x - fp_base_conv(TILE_SIZE, 0, PIXEL_DECIMAL);
							end if;
						end if;
						state <= calca;
					end if;
				when traverse =>
					if Continue = '1' then
						if TopLeft.y(TILE_SHIFTi) = '1' then
							if	(((not E(0).a(EDGE_AB_SIZE-1)) and Eres(0)(EDGE_C_SIZE-1)) or
								 ((not E(1).a(EDGE_AB_SIZE-1)) and Eres(1)(EDGE_C_SIZE-1)) or
								 ((not E(2).a(EDGE_AB_SIZE-1)) and Eres(2)(EDGE_C_SIZE-1))) = '1'
							then
								-- Next line
								TopLeft.y <= TopLeft.y + fp_base_conv(TILE_SIZE, 0, PIXEL_DECIMAL);
								next_state <= testoutside;
							else
								-- walk forward (left)
								TopLeft.x <= TopLeft.x - fp_base_conv(TILE_SIZE, 0, PIXEL_DECIMAL);
							end if;
						else 
							if	((E(0).a(EDGE_AB_SIZE-1) and Eres(0)(EDGE_C_SIZE-1)) or
								 (E(1).a(EDGE_AB_SIZE-1) and Eres(1)(EDGE_C_SIZE-1)) or
								 (E(2).a(EDGE_AB_SIZE-1) and Eres(2)(EDGE_C_SIZE-1))) = '1'
							then
								-- Next line
								TopLeft.y <= TopLeft.y + fp_base_conv(TILE_SIZE, 0, PIXEL_DECIMAL);
								next_state <= testoutside;
							else
								-- walk forward (right)
								TopLeft.x <= TopLeft.x + fp_base_conv(TILE_SIZE, 0, PIXEL_DECIMAL);
							end if;
						end if;
						state <= calca;
					end if;
				when others => null;
			end case;
		end if;
	end process;

	P.x <= TopLeft.x;
	P.y <= TopLeft.y;

	Ready <= '1' when state = idle else '0';
	OutNewData <= '1' when Eres(0)(EDGE_C_SIZE-1) = '0' and Eres(1)(EDGE_C_SIZE-1) = '0' and Eres(2)(EDGE_C_SIZE-1) = '0' and  state = traverse and Continue = '1' else '0';

end Behavioral;
