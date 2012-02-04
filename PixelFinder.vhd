-- $Id: PixelFinder.vhd,v 1.13 2005/06/09 11:32:10 quarn Exp $

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

use work.Common.ALL;

--  Uncomment the following lines to use the declarations that are
--  provided for instantiating Xilinx primitive components.
--library UNISIM;

--use UNISIM.VComponents.all;

entity PixelFinder is
	Port (
		clk : in std_logic;
		NewData : in std_logic;
		Continue : in std_logic;
		P : in Pixel;
		E : in Edges;
		W	: in WArray;
		A	: in std_logic_vector(AREA_SIZE-1 downto 0);
		ERes : in EdgeResult;
		NewPixel : out std_logic;
		Pout : out Pixel; 
		Bary : out BaryCentric;
		PBary : out BaryCentric;
		Ready : out std_logic
	);
end PixelFinder;

architecture Behavioral of PixelFinder is
	------- States ----------------------------------------------------------
	type state_type is (idle, dummy, traverse);
	signal state : state_type;

	------- Internal signals ------------------------------------------------
	signal I0 : std_logic;
	signal I1 : std_logic;
	signal I2 : std_logic;
	signal ICont : std_logic;
	signal BCont : std_logic;
	signal barynew : std_logic;
	signal baryoutnew : std_logic;

	signal PBaryOutNew : std_logic;
	signal PBCont : std_logic;

	signal EResO : EdgeResult;
	signal EResO2 : EdgeResult;

	signal tilehack : std_logic;
	signal readyhack : std_logic;

	signal x : std_logic_vector(3 downto 0);	-- TODO: hardcoded. allows tiles up to 2^4 pixels tall/wide.
	signal y : std_logic_vector(3 downto 0);
	signal Pouti : Pixel;
	signal inside : std_logic;
begin
	Eval0: entity work.PixelEvaluator port map(
		clk => clk,
		NewData => NewData,
		Continue => ICont,
		E => E(0),
		Eres => Eres(0),
		P => P,
		Inside => I0,
		Result => EResO(0)
	);
	Eval1: entity work.PixelEvaluator port map(
		clk => clk,
		NewData => NewData,
		Continue => ICont,
		E => E(1),
		Eres => Eres(1),
		P => P,
		Inside => I1,
		Result => EResO(1)
	);
	Eval2: entity work.PixelEvaluator port map(
		clk => clk,
		NewData => NewData,
		Continue => ICont,
		E => E(2),
		Eres => Eres(2),
		P => P,
		Inside => I2,
		Result => EResO(2)
	);

	BaryC : entity work.BarycentricCalculator port map(
		clk => clk,
		NewData => BaryNew,
		Continue => Continue,
		A => A,
		ERes => EresO2,
		Bary => Bary,
		OutNew => BaryOutNew,
		Ready => BCont
	);

	PBaryC : entity work.PerspectiveBaryCalculator port map(
		clk => clk,
		NewData => BaryNew,
		Continue => Continue,
		W => W,
		ERes => EresO2,
		Bary => PBary,
		OutNew => PBaryOutNew,
		Ready => PBCont
	);

	process (clk)
	begin
		if clk'event and clk = '1' then
			case state is
				when idle =>
					x <= (others=>'0');
					y <= (others=>'0');
					Pouti <= P;
					Pout <= P;
					EResO2 <= ERes;
					tilehack <= '1';

					if NewData = '1' then
						state <= traverse;
					end if;
				when traverse =>
					if Continue = '1' then
						Pout <= Pouti;
					end if;
					if ICont = '1' and tilehack = '0' then
						EResO2 <= EResO;
						if x < TILE_SIZE -1 then
							-- zig/zag across the tile
							if y(0) = '0' then
								Pouti.x <= Pouti.x + fp_base_conv("1", 0, PIXEL_DECIMAL);
							else
								Pouti.x <= Pouti.x - fp_base_conv("1", 0, PIXEL_DECIMAL);
							end if;
							x <= x + 1;
						else
							x <= (others=>'0');
							if y < TILE_SIZE -1 then
								Pouti.y <= Pouti.y + fp_base_conv("1", 0, PIXEL_DECIMAL);
							else
								state <= idle;
							end if;
							y <= y + 1;
						end if;
					end if;
					tilehack <= '0';

				when others => null;
			end case;
		end if;
	end process;

	ICont <= PBCont and BCont and (Continue or readyhack);

	readyhack <= '0';-- when (I0 = '1' and I1 = '1' and I2 = '1') and Continue'event and Continue = '0' else '0';

	barynew <= '1' when state = traverse and ICont = '1' and (I0 = '1' and I1 = '1' and I2 = '1') else '0';
	Ready <= '1' when state = idle and ICont = '1' and baryOutNew /= '1' else '0';
	NewPixel <= '1' when Continue = '1' and PBaryOutNew = '1' else '0';
end Behavioral;
