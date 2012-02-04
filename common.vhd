-- $Id: common.vhd,v 1.25 2005/06/09 11:32:10 quarn Exp $

--	Package File Template
--
--	Purpose: This package defines supplemental types, subtypes, 
--		 constants, and functions 


library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;


package Common is

	------- Constants - Edges --------------------------------------------------
	constant EDGE_AB_DECIMAL	: integer := 4;
	constant EDGE_AB_SIZE	: integer := 1 + 10 + EDGE_AB_DECIMAL;

	constant EDGE_C_DECIMAL	: integer := 2 * EDGE_AB_DECIMAL;
	constant EDGE_C_SIZE	: integer := 2 * EDGE_AB_SIZE;

	type Edge is
	record
		a	: std_logic_vector(EDGE_AB_SIZE-1 downto 0);
		b	: std_logic_vector(EDGE_AB_SIZE-1 downto 0);
		c	: std_logic_vector(EDGE_C_SIZE-1 downto 0);
	end record;

	------- Constants - Pixel --------------------------------------------------
	-- TODO: Pixel does not need decimal...
	constant PIXEL_DECIMAL	: integer := EDGE_AB_DECIMAL;
	constant PIXEL_SIZE		: integer := 10 + PIXEL_DECIMAL;

	type	Pixel is
	record
		x	: std_logic_vector(PIXEL_SIZE-1 downto 0);
		y	: std_logic_vector(PIXEL_SIZE-1 downto 0);
	end record;


	------- Constants - Tile ---------------------------------------------------
	constant TILE_SHIFTi	: integer := 2;
	constant TILE_SHIFT		: std_logic_vector := conv_std_logic_vector(TILE_SHIFTi, 2);
	constant TILE_SIZE		: std_logic_vector := shl("0001", TILE_SHIFT);

	------- Constants - Vertex -------------------------------------------------
	constant VERTEX_XY_DECIMAL	: integer := 4;
	constant VERTEX_XY_SIZE	: integer := 10 + VERTEX_XY_DECIMAL;

	constant VERTEX_W_SIZE 	: integer := 24;
	constant VERTEX_Z_SIZE 	: integer := 24;

	type Vertex is
	record
		x	: std_logic_vector(VERTEX_XY_SIZE-1 downto 0);
		y	: std_logic_vector(VERTEX_XY_SIZE-1 downto 0);
	end record;


	------- Constants - Color --------------------------------------------------	
	constant ARGB_SIZE		: integer := 8;

	type Color is
	record
		a	: std_logic_vector(ARGB_SIZE-1 downto 0);
		r	: std_logic_vector(ARGB_SIZE-1 downto 0);
		g	: std_logic_vector(ARGB_SIZE-1 downto 0);
		b	: std_logic_vector(ARGB_SIZE-1 downto 0);
	end record;

	------- Constants - Texel --------------------------------------------------	
	constant TEXEL_UV_DECIMAL: integer := 16;
	constant TEXEL_UV_SIZE	: integer := 8 + TEXEL_UV_DECIMAL;

	type Texel is
	record
		u : std_logic_vector(TEXEL_UV_SIZE-1 downto 0);
		v : std_logic_vector(TEXEL_UV_SIZE-1 downto 0);
	end record;


	------- Constants - Barycentric --------------------------------------------	
	constant UVW_SIZE		: integer := 16;
	type Barycentric is
	record
		u	: std_logic_vector(UVW_SIZE-1 downto 0);						 
		v	: std_logic_vector(UVW_SIZE-1 downto 0);
		w	: std_logic_vector(UVW_SIZE-1 downto 0);
	end record;

	------- Constants - Memory -------------------------------------------------
	constant MEMORY_DATA_WIDTH : integer := 32;
	constant MEMORY_ADDR_SIZE : integer := 20;
	constant MEMORY_CTRL_NUM : integer := 1;


	type MemCtrlIn is
	record
		addr : std_logic_vector(MEMORY_ADDR_SIZE-1 downto 0);
		data : std_logic_vector(MEMORY_DATA_WIDTH-1 downto 0);
		we : std_logic;
		WriteReq : std_logic;
		ReadReq : std_logic;
	end record;

	type MemCtrlOut is
	record
		WriteVld : std_logic;
		ReadVld : std_logic;
	end record;

	type CtrlInArray is array(1 downto 0) of MemCtrlIn;
	type CtrlOutArray is array(1 downto 0) of MemCtrlOut;

	------- Constants - Other --------------------------------------------------
	constant AREA_SIZE		: integer := 28;


	type Triangle is array (2 downto 0) of Vertex;
	type Edges is array (2 downto 0) of Edge;

	type EdgeResult is array (2 downto 0) of std_logic_vector(EDGE_C_SIZE-1 downto 0);

	type WArray is array (2 downto 0) of std_logic_vector(VERTEX_W_SIZE-1 downto 0);

	type VertexParameters is
	record
		Z : std_logic_vector(VERTEX_Z_SIZE-1 downto 0);
		C : Color;
		T : Texel;
	end record;


	type ztest is (greater, less, lequal, gequal, always, never);
	type TextureMode is (disable, replace, modulate);
	type TextureState is
	record
		mode		: TextureMode;
		filtering : std_logic;
		width	: std_logic_vector(2 downto 0);
		height	: std_logic_vector(2 downto 0);
		address	: std_logic_vector(19 downto 0);
	end record;

	type RenderingState is
	record
		Texture : TextureState;
		FlatShade : std_logic;
		ZTest : ztest;
	end record;
	
	type TriangleParameters is array (2 downto 0) of VertexParameters;

	------- Functions ----------------------------------------------------------	
	function tile_clamp(p : std_logic_vector) return std_logic_vector;
	function fp_base_conv(Val : std_logic_vector; from_base, to_base : integer) return std_logic_vector;
end Common;


package body Common is
	-- insert function implementations here
	function tile_clamp(p : std_logic_vector) return std_logic_vector is
	begin
		return p and fp_base_conv(shl(B"11_1111_1111", TILE_SHIFT), 0, PIXEL_DECIMAL);	-- TODO: hardcoded bits...
	end;

	-- Converts a value from one fixed point base to another
	function fp_base_conv(Val : std_logic_vector; from_base, to_base : integer) return std_logic_vector is
	begin
		if (from_base < to_base) then
			return Val & conv_std_logic_vector(0, to_base - from_base); -- append zeros
		else
			return shr(Val, conv_std_logic_vector(from_base - to_base, 8));
		end if;
	end;
end Common;
