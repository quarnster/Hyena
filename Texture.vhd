library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

use work.Common.ALL;

--  Uncomment the following lines to use the declarations that are
--  provided for instantiating Xilinx primitive components.
--library UNISIM;
--use UNISIM.VComponents.all;

entity Texture is
    Port (
		clk : in std_logic;
		TextureState : in TextureState;
		NewTexel : in std_logic;
		Texel : in Texel;
		NewColor : out std_logic;
		Color : out Color;

		MemCtrlOut : in MemCtrlOut;
		MemCtrlIn : out MemCtrlIn;
		MemCtrlData : in std_logic_vector(MEMORY_DATA_WIDTH-1 downto 0)
	);
end Texture;

architecture Behavioral of Texture is

	constant TEXTURE_BASE : integer := 2*160*120;

	type state_type is (idle, calctexel, calcaddr, read, calcuvinv, calcbil, data_wait, output);
	signal state : state_type;

	type filter_state_type is (fetch0, fetch1, fetch2, fetch3);
	signal filter_state : filter_state_type;

	signal addr : std_logic_vector(MEMORY_ADDR_SIZE-1 downto 0);
	signal readreq : std_logic;

	signal data0 : std_logic_vector(MEMORY_DATA_WIDTH-1 downto 0);
	signal data1 : std_logic_vector(MEMORY_DATA_WIDTH-1 downto 0);
	signal data2 : std_logic_vector(MEMORY_DATA_WIDTH-1 downto 0);
	signal data3 : std_logic_vector(MEMORY_DATA_WIDTH-1 downto 0);

	signal ul : std_logic_vector(7 downto 0);
	signal ur : std_logic_vector(7 downto 0);
	signal ll : std_logic_vector(7 downto 0);
	signal lr : std_logic_vector(7 downto 0);

	signal uinv : std_logic_vector(7 downto 0);
	signal vinv : std_logic_vector(7 downto 0);

	signal Tex : work.Common.Texel;

	function mulrem(p : std_logic_vector) return std_logic_vector is
	begin
		return p(15  downto 8);
	end function;

	function expand(p : std_logic_vector; fromsize: std_logic_vector; tosize: std_logic_vector) return std_logic_vector is
	begin
		if fromsize < tosize then
			return p & p(conv_integer(fromsize)-1 downto conv_integer(tosize-fromsize));
		else
			return p(conv_integer(fromsize)-1 downto conv_integer(fromsize-tosize));
		end if;
	end function;
	function fractional(p : std_logic_vector; size: std_logic_vector) return std_logic_vector is
	begin
		return expand(p(15-3-conv_integer(size) downto 0), 16-3-size, conv_std_logic_vector(8,4));
	end function;
begin

	process (clk)
	begin
		if clk'event and clk = '1' then
			case (state) is
				when idle =>
					Tex <= Texel;
					if NewTexel = '1' then
						if TextureState.Filtering = '1' then
							state <= calctexel;
						else
							state <= calcaddr;
						end if;
						
					end if;
				when calctexel =>
					Tex.u <= Tex.u - X"7F"; -- u-=0.5 for bilinear interpolation
					Tex.v <= Tex.v - X"7F"; -- v-=0.5 for bilinear interpolation
					state <= calcaddr;
				when calcaddr =>
					state <= read;
				when read =>
					if TextureState.Filtering = '1' then
						state <= calcuvinv;
					else
						state <= data_wait;
					end if;
				when calcuvinv =>
					uinv <= X"FF" - fractional(Tex.u, TextureState.Width);
					vinv <= X"FF" - fractional(Tex.v, TextureState.Height);
					state <= calcbil;
				when calcbil =>
					state <= data_wait;
				when data_wait =>
					if readreq = '0' then
						if TextureState.Filtering = '1' then
							-- TODO: split into different cycles for a possible
							-- increase in maximum clocking frequency
							Color.R <= mulrem(data0(23 downto 16) * ul) + mulrem(data1(23 downto 16) * ur) +  mulrem(data2(23 downto 16) * ll) + mulrem(data3(23 downto 16) * lr);
							Color.G <= mulrem(data0(15 downto 8) * ul) + mulrem(data1(15 downto 8) * ur) +  mulrem(data2(15 downto 8) * ll) + mulrem(data3(15 downto 8) * lr);
							Color.B <= mulrem(data0(7 downto 0) * ul) + mulrem(data1(7 downto 0) * ur) +  mulrem(data2(7 downto 0) * ll) + mulrem(data3(7 downto 0) * lr);
						else 
							Color.R <= data0(23 downto 16);
							Color.G <= data0(15 downto 8);
							Color.B <= data0(7 downto 0);
						end if;
						state <= output;
					end if;
				when output =>
					state <= idle;
			end case;
		end if;
	end process;

	process (clk)
	begin
		if clk'event and clk = '1' then
			if state = calcbil then
				ul <= mulrem(uinv * vinv);
			end if;
		end if;
	end process;

	process (clk)
	begin
		if clk'event and clk = '1' and state = calcbil then
			ur <= mulrem(fractional(Tex.u, TextureState.Width) * vinv);
		end if;
	end process;

	process (clk)
	begin
		if clk'event and clk = '1' and state = calcbil then
			ll <= mulrem(uinv * fractional(Tex.v, TextureState.Height));
		end if;
	end process;

	process (clk)
	begin
		if clk'event and clk = '1' and state = calcbil then
			lr <= mulrem(fractional(Tex.u, TextureState.Width) * fractional(Tex.v, TextureState.Height));
		end if;
	end process;

	process (clk)
		impure function calc_addr(u : std_logic_vector; v : std_logic_vector) return std_logic_vector is
		begin
			return B"0" & v(7+8 downto 7+8-2-conv_integer(TextureState.height)) & u(7+8 downto 7+8-2-conv_integer(TextureState.width)) + TEXTURE_BASE + TextureState.Address;
		end function;
		function texel_size(size: std_logic_vector(2 downto 0)) return std_logic_vector is
		begin
			return shl(B"00000001000", size);
		end function;
	begin
		if clk'event and clk = '1' then
			if state = idle then
				filter_state <= fetch0;
			elsif state = calcaddr then
				addr <= calc_addr(Tex.u, Tex.v);
			elsif state = read then
				readreq <= '1';
			end if;
			if MemCtrlOut.ReadVld = '1' then
				if TextureState.Filtering = '1' then
					if filter_state /= fetch3 then
						case filter_state is
							when fetch0 =>
								data0 <= MemCtrlData;
								addr <= calc_addr(Tex.u + texel_size(TextureState.width), Tex.v);
								filter_state <= fetch1;
							when fetch1 =>
								data1 <= MemCtrlData;
								addr <= calc_addr(Tex.u, Tex.v + texel_size(TextureState.height));
								filter_state <= fetch2;
							when fetch2 =>
								data2 <= MemCtrlData;
								addr <= calc_addr(Tex.u + texel_size(TextureState.width), Tex.v + texel_size(TextureState.height));
								filter_state <= fetch3;
							when others => null;
						end case;
						readreq <= '1';
					else
						data3 <= MemCtrlData;
						readreq <= '0';
					end if;
				else
					data0 <= MemCtrlData;
					readreq <= '0';
				end if;
			end if;
		end if;
	end process;

	MemCtrlIn.ReadReq <= MemCtrlOut.ReadVld xor readreq;
	MemCtrlIn.Addr <= addr;

	NewColor <= '1' when state = output else '0';

end Behavioral;
