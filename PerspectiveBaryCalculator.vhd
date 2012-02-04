-- $Id: PerspectiveBaryCalculator.vhd,v 1.12 2005/06/09 11:32:10 quarn Exp $

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

use work.Common.ALL;

--  Uncomment the following lines to use the declarations that are
--  provided for instantiating Xilinx primitive components.
--library UNISIM;
--use UNISIM.VComponents.all;

entity PerspectiveBaryCalculator is
	Port (
		clk : in std_logic;
		Continue : in std_logic;
		NewData : in std_logic;
		W 	: in WArray;
		ERes : in EdgeResult;
		Bary : out Barycentric;
		OutNew : out std_logic;
		Ready : out std_logic
	);
end PerspectiveBaryCalculator;

architecture Behavioral of PerspectiveBaryCalculator is

	type state_type is (idle, mult, sum, sum_fix, calcu, calcv, calcw, sleep, output_u, output_v, output_w, output);
	signal state : state_type;
	signal f0 : std_logic_vector(31 downto 0);
	signal f1 : std_logic_vector(31 downto 0);
	signal f2 : std_logic_vector(31 downto 0);

	signal sumf : std_logic_vector(31 downto 0);

	function mulrem(p : std_logic_vector) return std_logic_vector is
	begin
		return '0' & p(VERTEX_W_SIZE+EDGE_C_DECIMAL-1+6  downto VERTEX_W_SIZE+EDGE_C_DECIMAL-32+1+6);
	end function;

	function baryrem(p : std_logic_vector) return std_logic_vector is
	begin
		return p(UVW_SIZE+UVW_SIZE-1 downto UVW_SIZE);
	end function;

	function makebary(p : std_logic_vector) return std_logic_vector is
	begin
		return baryrem((p & conv_std_logic_vector(0, UVW_SIZE)) - p);
	end function;

--	signal dividend : std_logic_vector(31 downto 0);
--	signal divisor : std_logic_vector(31 downto 0);
--	signal quot : std_logic_vector(31 downto 0);
--	signal remd : std_logic_vector(31 downto 0);
--	signal ce : std_logic;

--	signal rfd : std_logic;
--	signal aclr : std_logic;
--	signal sclr : std_logic;

--	signal count : integer;

	signal temp1 : std_logic_vector(31 downto 0);
	signal temp2 : std_logic_vector(31 downto 0);
	signal temp3 : std_logic_vector(31 downto 0);
begin

--Div : entity work.divider
--		port map (
--			dividend => dividend,
--			divisor => divisor,
--			quot => quot,
--			remd => remd,
--			clk => clk,
--			rfd => rfd,
--			aclr => aclr,
--			sclr => sclr,
--			ce => ce);
							 
	process (clk)
	begin
		if clk'event and clk = '1' then
			case state is
				when idle =>
					if NewData = '1' then
						state <= mult;
					end if;						    
				when mult =>
					state <= sum;
				when sum =>
					sumf <= f2 + f1 + f0;
					state <= sum_fix;
				when sum_fix =>
					temp1 <= conv_std_logic_vector(conv_integer(f0(31 downto 31 - UVW_SIZE+1) & conv_std_logic_vector(0, 32-UVW_SIZE)) / conv_integer(conv_std_logic_vector(0, UVW_SIZE) & sumf(31 downto UVW_SIZE)), 32);
--					divisor <= conv_std_logic_vector(0, UVW_SIZE) & sumf(31 downto UVW_SIZE);
					state <= calcv;
				when calcv =>
					temp2 <= conv_std_logic_vector(conv_integer(f1(31 downto 31 - UVW_SIZE+1) & conv_std_logic_vector(0, 32-UVW_SIZE)) / conv_integer(conv_std_logic_vector(0, UVW_SIZE) & sumf(31 downto UVW_SIZE)), 32);
--					dividend <= f1(31 downto 31 - UVW_SIZE+1) & conv_std_logic_vector(0, 32-UVW_SIZE);
					state <= calcw;
				when calcw =>
					temp3 <= conv_std_logic_vector(conv_integer(f2(31 downto 31 - UVW_SIZE+1) & conv_std_logic_vector(0, 32-UVW_SIZE)) / conv_integer(conv_std_logic_vector(0, UVW_SIZE) & sumf(31 downto UVW_SIZE)), 32);
--					dividend <= f2(31 downto 31 - UVW_SIZE+1) & conv_std_logic_vector(0, 32-UVW_SIZE);
--					state <= sleep;
					state <= output_u;
--					count <= 31;
				when sleep =>
--					if count = 0 then
--						state <= output_u;
--					else
--						count <= count - 1;
--					end if;
				when output_u =>
					bary.u <= makebary(temp1);
--					bary.u <= makebary(quot);
					state <= output_v;
				when output_v =>
					bary.v <= makebary(temp2);
--					bary.v <= makebary(quot);
					state <= output_w;
				when output_w =>
					bary.w <= makebary(temp3);
--					bary.w <= makebary(quot);
					state <= output;
				when output =>
					if Continue = '1' then
						state <= idle;
					end if;
				when others => null;
			end case;
		end if;
	end process;

	process (clk)
	begin
		if clk'event and clk = '1' and state = mult then
			f0 <= mulrem(unsigned(ERes(0)) * unsigned(W(2)));
		end if;
	end process;

	process (clk)
	begin
		if clk'event and clk = '1' and state = mult then
			f1 <= mulrem(unsigned(ERes(1)) * unsigned(W(0)));
		end if;
	end process;

	process (clk)
	begin
		if clk'event and clk = '1' and state = mult then
			f2 <= mulrem(unsigned(ERes(2)) * unsigned(W(1)));
		end if;
	end process;

--	ce <= '1' when Continue = '1' else '0';


	Ready <= '1' when state = idle else '0';
	OutNew <= '1' when state = output and Continue = '1' else '0';

end Behavioral;
