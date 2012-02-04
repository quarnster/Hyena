-- $Id: PixelShader.vhd,v 1.19 2005/06/07 09:50:06 quarn Exp $

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

use work.Common.ALL;
--  Uncomment the following lines to use the declarations that are
--  provided for instantiating Xilinx primitive components.
--library UNISIM;
--use UNISIM.VComponents.all;

entity PixelShader is
    Port (
		clk : in std_logic;
		NewData : in std_logic;
		Bary : in Barycentric;
		PBary : in Barycentric;
		TriPar : in TriangleParameters;
		RenderingState : in RenderingState;
		Pixel : in Pixel;
		Ready : out std_logic;

		NewTexel : out std_logic;
		Texel : out Texel;
		NewColor : in std_logic;
		TexColor : in Color;

		MemCtrlIn : out MemCtrlIn;
		MemCtrlOut : in MemCtrlOut;
		MemCtrlData : in std_logic_vector(MEMORY_DATA_WIDTH-1 downto 0)
	);
end PixelShader;

architecture Behavioral of PixelShader is
	signal addr : std_logic_vector(20-1 downto 0);
	signal data : std_logic_vector(MEMORY_DATA_WIDTH-1 downto 0) := (others=>'0');
	signal datain : std_logic_vector(MEMORY_DATA_WIDTH-1 downto 0) := (others=>'0');

	signal mr : std_logic := '0';
	signal mw : std_logic := '0';

	constant MAX_PARAMETER_SIZE : integer := VERTEX_Z_SIZE;
	constant RES_SIZE : integer := UVW_SIZE+MAX_PARAMETER_SIZE;

	type res_type is array (2 downto 0) of std_logic_vector(RES_SIZE-1 downto 0);
	signal res : res_type;

	type uvw_data_type is array (2 downto 0) of std_logic_vector(MAX_PARAMETER_SIZE-1 downto 0);
	signal uvw_data : uvw_data_type;

	signal fres : std_logic_vector(RES_SIZE-1 downto 0);

	type state_type is (idle, mult, sum, sum_fix, pmult, z, z_compare, u, v, setv, out_uv, red, green, blue, output_blue, color_mix, output);
	signal state : state_type;
	signal next_state : state_type;

	signal Col : Color;
	signal TCol : Color;
	signal wantTex : std_logic := '0';

	function fix(p : std_logic_vector) return std_logic_vector is
	begin
		if MAX_PARAMETER_SIZE-p'length > 0 then
			return conv_std_logic_vector(0, MAX_PARAMETER_SIZE-p'length) & p;
		else
			return p;
		end if;
	end function;

	function colrem(c : std_logic_vector) return std_logic_vector is
	begin
		return c(ARGB_SIZE+ARGB_SIZE-1 downto ARGB_SIZE);
	end function;
begin

	process (clk)
		variable zaccept : std_logic;
	begin
		if clk'event and clk = '1' then
			case state is
				when idle =>
					-- Make sure color value has been written
					if mw = '0' and NewData = '1' then
						addr <= unsigned(Pixel.y(PIXEL_SIZE-1 downto PIXEL_DECIMAL)) * unsigned(conv_std_logic_vector(160, PIXEL_SIZE-PIXEL_DECIMAL)) + unsigned(Pixel.x(PIXEL_SIZE-1 downto PIXEL_DECIMAL));
						state <= z;
					end if;
				when pmult =>
					state <= sum;
				when mult =>
					state <= sum;
				when sum =>
					fres <= unsigned(res(0)) + unsigned(res(1)) + unsigned(res(2));
					state <= sum_fix;
				when sum_fix =>
					fres <= unsigned(fres) + unsigned(fres(RES_SIZE-1 downto RES_SIZE-UVW_SIZE));
					state <= next_state;
				when z =>
					uvw_data(0) <= fix(TriPar(0).Z);
					uvw_data(1) <= fix(TriPar(1).Z);
					uvw_data(2) <= fix(TriPar(2).Z);
					next_state <= z_compare;
					state <= mult;
				when z_compare =>
					if mr = '0' then
						-- make sure z-buffer value has been read
						case RenderingState.ZTest is
							when always =>
								zaccept := '1';
							when never =>
								zaccept := '0';
							when greater =>
								if fres(UVW_SIZE-1+VERTEX_Z_SIZE downto UVW_SIZE) > datain(VERTEX_Z_SIZE-1 downto 0) then
									zaccept := '1';
								else
									zaccept := '0';
								end if;
							when less =>
								if fres(UVW_SIZE-1+VERTEX_Z_SIZE downto UVW_SIZE) < datain(VERTEX_Z_SIZE-1 downto 0) then
									zaccept := '1';
								else
									zaccept := '0';
								end if;
							when gequal =>
								if fres(UVW_SIZE-1+VERTEX_Z_SIZE downto UVW_SIZE) >= datain(VERTEX_Z_SIZE-1 downto 0) then
									zaccept := '1';
								else
									zaccept := '0';
								end if;
							when lequal =>
								if fres(UVW_SIZE-1+VERTEX_Z_SIZE downto UVW_SIZE) <= datain(VERTEX_Z_SIZE-1 downto 0) then
									zaccept := '1';
								else
									zaccept := '0';
								end if;
						end case;


						if zaccept = '1' then
							if RenderingState.Texture.mode /= disable then
								state <= u;	
							else
								state <= red;
							end if;

							data(31 downto 24) <= X"00";
							data(VERTEX_Z_SIZE-1 downto 0) <= fres(UVW_SIZE-1+VERTEX_Z_SIZE downto UVW_SIZE);
						else
							state <= idle;
						end if;
					end if;
				when u =>
					uvw_data(0) <= fix(TriPar(0).T.u);
					uvw_data(1) <= fix(TriPar(1).T.u);
					uvw_data(2) <= fix(TriPar(2).T.u);
					next_state  <= v;
					state <= pmult;
				when v =>
					Texel.u <= fres(UVW_SIZE-1+TEXEL_UV_SIZE downto UVW_SIZE);
					uvw_data(0) <= fix(TriPar(0).T.v);
					uvw_data(1) <= fix(TriPar(1).T.v);
					uvw_data(2) <= fix(TriPar(2).T.v);
					next_state  <= setv;
					state <= pmult;
				when red =>
					if RenderingState.FlatShade = '1' then
						Col <= TriPar(0).C;
						state <= color_mix;
					else 
						uvw_data(0) <= fix(TriPar(0).C.r);
						uvw_data(1) <= fix(TriPar(1).C.r);
						uvw_data(2) <= fix(TriPar(2).C.r);
						next_state <= green;
						state <= pmult;
					end if;
				when green =>
					Col.R <= fres(UVW_SIZE-1+ARGB_SIZE downto UVW_SIZE);	-- Red
					state <= pmult;
					uvw_data(0) <= fix(TriPar(0).C.g);
					uvw_data(1) <= fix(TriPar(1).C.g);
					uvw_data(2) <= fix(TriPar(2).C.g);
					next_state <= blue;
				when blue =>
					Col.G <= fres(UVW_SIZE-1+ARGB_SIZE downto UVW_SIZE); -- Green
					state <= pmult;
					uvw_data(0) <= fix(TriPar(0).C.b);
					uvw_data(1) <= fix(TriPar(1).C.b);
					uvw_data(2) <= fix(TriPar(2).C.b);
					next_state <= output_blue;
				when output_blue =>
					Col.B <= fres(UVW_SIZE-1+ARGB_SIZE downto UVW_SIZE); -- Blue
					state <= color_mix;
				when setv =>
					Texel.v <= fres(UVW_SIZE-1+TEXEL_UV_SIZE downto UVW_SIZE);					
					state <= out_uv;
				when out_uv =>
					state <= red;
				when color_mix =>
					if wantTex = '0' and mw = '0' then
						-- make sure z-buffer value has been written
						addr <= addr + 160*120;

						data(31 downto 24) <= X"FF";
						if RenderingState.Texture.mode = replace then
							data(23 downto 16) <= TCol.R;
							data(15 downto 8) <= TCol.G;
							data(7 downto 0) <= TCol.B;
						elsif RenderingState.Texture.mode = modulate then
							data(23 downto 16) <= colrem(Col.R * TCol.R);
							data(15 downto 8) <= colrem(Col.G * TCol.G);
							data(7 downto 0) <= colrem(Col.B * TCol.B);
						else
							data(23 downto 16) <= Col.R;
							data(15 downto 8) <= Col.G;
							data(7 downto 0) <= Col.B;
						end if;
						state <= output;
					end if;
				when output =>
					state <= idle;
				when others => null;
			end case;
		end if;
	end process;

	--- Memory read controll -------------------------
	process (clk)
	begin
		if clk'event and clk = '1' then
			if state = z then
				-- Read from z-buffer
				mr <= '1';
			end if;
			if MemCtrlOut.ReadVld = '1' then
				mr <= '0';
			end if;
		end if;
	end process;

	--- Memory write controll -------------------------
	process (clk)
	begin
		if clk'event and clk = '1' then
			if state = red then
				-- Write to z-buffer
				mw <= '1';
			elsif state = output then
				-- Write to color buffer
				mw <= '1';
			end if;
			if MemCtrlOut.WriteVld = '1' then
				mw <= '0';
			end if;
		end if;
	end process;

	--- Parameter interpolation multiplication --------
	process (clk)
	begin
		if clk'event and clk = '1' then
			if state = mult then
				res(0) <= unsigned(bary.u) * unsigned(uvw_data(2));
			elsif state = pmult then
				res(0) <= unsigned(pbary.u) * unsigned(uvw_data(2));
			end if;
		end if;
	end process;

	process (clk)
	begin
		if clk'event and clk = '1' then
			if state = mult then
				res(1) <= unsigned(bary.v) * unsigned(uvw_data(0));
			elsif state = pmult then
				res(1) <= unsigned(pbary.v) * unsigned(uvw_data(0));
			end if;
		end if;
	end process;

	process (clk)
	begin
		if clk'event and clk = '1' then
			if state = mult then
				res(2) <= unsigned(bary.w) * unsigned(uvw_data(1));
			elsif state = pmult then
				res(2) <= unsigned(pbary.w) * unsigned(uvw_data(1));
			end if;
		end if;
	end process;

	wantTex <= '1' when state = u else '0' when NewColor = '1'; -- else '0';
	MemCtrlIn.ReadReq <= mr;
	MemCtrlIn.WriteReq <= mw;

	MemCtrlIn.Data <= data;
	datain <= MemCtrlData when MemCtrlOut.ReadVld = '1';
	MemCtrlIn.Addr <= addr;


	TCol <= TexColor when NewColor = '1';
	NewTexel <= '1' when state = out_uv else '0';

	Ready <= '1' when state = idle and mw = '0' else '0';

end Behavioral;
