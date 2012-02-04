-- $Id: HyenaCore.vhd,v 1.15 2005/05/31 15:47:46 quarn Exp $

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

use work.Common.ALL;
--  Uncomment the following lines to use the declarations that are
--  provided for instantiating Xilinx primitive components.
--library UNISIM;
--use UNISIM.VComponents.all;

entity HyenaCore is
	Port (
		clk : in std_logic;
		NewData : in std_logic;
		A : in std_logic_vector(AREA_SIZE-1 downto 0);
		T : in Triangle;
		TriPar : in TriangleParameters;
		RenderingState : in RenderingState;
		W : in WArray;
		E : in Edges;
		Ready : out std_logic
	);
end HyenaCore;

architecture Behavioral of HyenaCore is
	------- States ----------------------------------------------------------
	type state_type is (idle, test);
	signal state : state_type;

	signal TilePixel : Pixel;
	signal EoutTO : EdgeResult;
	signal Bary : Barycentric;
	signal PBary : Barycentric;
	signal OutPixel : Pixel;
	signal NewPixel : std_logic;
	signal PFReady : std_logic;
	signal TONewData : std_logic;
	signal PSReady : std_logic;
	signal TOReady : std_logic;

	signal PQ_Ready : std_logic;
	signal PQ_NewPixel : std_logic;
	signal PQ_Pixel : Pixel;
	signal PQ_Bary : Barycentric;
	signal PQ_PBary : BaryCentric;
	signal PQ_Empty : std_logic;



	signal PSTexel : Texel;
	signal PSNewTexel: std_logic;

	signal PSColor : Color;
	signal PSNewColor : std_logic;

	signal CtrlOut : CtrlOutArray;
	signal CtrlIn : CtrlInArray;
	signal MemCtrlData : std_logic_vector(MEMORY_DATA_WIDTH-1 downto 0);


	signal memCtrlAddr : std_logic_vector(MEMORY_ADDR_SIZE-1 downto 0);
	signal memCtrlDataOut : std_logic_vector(MEMORY_DATA_WIDTH-1 downto 0);
	signal memCtrlDataIn : std_logic_vector(MEMORY_DATA_WIDTH-1 downto 0);
	signal memCtrlWe : std_logic;

	signal INewData : std_logic;
begin
	TileOverlap: entity work.TileOverlap port map(
		clk => clk,
		NewData => INewData,
		Continue => PFReady,
		T => T,
		E => E,
		P => TilePixel,
		Result => EoutTO,
		OutNewData => TONewData,
		Ready => TOReady
	);
	PixelFinder: entity work.PixelFinder port map(
		clk => clk,
		NewData => TONewData, 
		Continue => PQ_Ready,
		P => TilePixel,
		W => W,
		A => A,
		E => E,
		ERes => EoutTO,
		Bary => bary,
		PBary => PBary,
		NewPixel => NewPixel,
		Pout => OutPixel,
		Ready => PFReady
	);

	PixelQueue : entity work.PixelQueue port map(
		clk => clk,
		Continue => PSReady,
		PixelIn => OutPixel,
		BaryIn => bary,
		PBaryIn => PBary,
		NewPixel => NewPixel,
		Ready => PQ_Ready,
		NewPixelOut => PQ_NewPixel,
		PixelOut => PQ_Pixel,
		BaryOut => PQ_Bary,
		PBaryOut => PQ_PBary,
		Empty => PQ_Empty
		
	);
	PixelShader : entity work.PixelShader port map(
		clk => clk,
		NewData => PQ_NewPixel,
		TriPar => TriPar,
		RenderingState => RenderingState,
		Pixel => PQ_Pixel,
		Bary => PQ_Bary,
		PBary => PQ_PBary,
		Ready => PSReady,

		NewTexel => PSNewTexel,
		Texel => PSTexel,
		NewColor => PSNewColor,
		TexColor => PSColor,

		MemCtrlOut => CtrlOut(0),
		MemCtrlIn => CtrlIn(0),
		MemCtrlData => MemCtrlData
	);

	Texture : entity work.Texture
	port map(
		clk => clk,
		TextureState => RenderingState.Texture,
		NewTexel => PSNewTexel,
		Texel => PSTexel,
		NewColor => PSNewColor,
		Color => PSColor,
		MemCtrlOut => CtrlOut(1),
		MemCtrlIn => CtrlIn(1),
		MemCtrlData => MemCtrlData
	);

		
	memctrl  : entity work.MemController
	port map(
		clk => clk,

		CtrlOut => CtrlOut,
		CtrlIn => CtrlIn,
		data => memctrlData,

		memAddr => memCtrlAddr,
		memDataOut => memCtrlDataOut,
		memDataIn => memCtrlDataIn,
		memWe => memCtrlWe
	);
	Ram  : entity work.RAM
	generic map(
		WORD_SIZE => MEMORY_DATA_WIDTH,
		WORD_COUNT => 160*120 * 2 + 256*256,
		ADDR_SIZE => MEMORY_ADDR_SIZE
	)
	port map(
		clk => clk,
		addr => memCtrlAddr,
		we => memCtrlWe,
		din => memCtrlDataOut,
		dout => memCtrlDataIn
	);

	process (clk)
	begin
		if clk'event and clk = '1' then
			case state is
				when idle =>
					if NewData = '1' then
						state <= test;
					end if;
				when test =>
					state <= idle;
			end case;
		end if;
	end process;
	Ready <= '1' when PSReady = '1' and PFReady = '1' and TOReady = '1' and PQ_Empty = '1' and state = idle else '0';

	INewData <= '1' when
		conv_integer(a) /= 0 and						-- don't draw triangles with zero area
		state = test else '0';
end Behavioral;
