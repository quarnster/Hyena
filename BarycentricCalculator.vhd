-- $Id: BarycentricCalculator.vhd,v 1.6 2005/05/27 14:31:27 quarn Exp $

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

use work.Common.ALL;

--  Uncomment the following lines to use the declarations that are
--  provided for instantiating Xilinx primitive components.
--library UNISIM;
--use UNISIM.VComponents.all;

entity BarycentricCalculator is
	Port (
		clk : in std_logic;
		Continue : in std_logic;
		NewData : in std_logic;
		A 	: in std_logic_vector(AREA_SIZE-1 downto 0);    		
		ERes : in EdgeResult;
		Bary : out Barycentric;
		OutNew : out std_logic;
		Ready : out std_logic
	);
end BarycentricCalculator;

architecture Behavioral of BarycentricCalculator is
	type state_type is (idle, calc, output);
	signal state : state_type;
	signal Baryi : Barycentric;
begin

	process (clk)
		function mulrem(p : std_logic_vector) return std_logic_vector is
		begin
			return p(AREA_SIZE+EDGE_C_DECIMAL-1-1  downto AREA_SIZE+EDGE_C_DECIMAL-UVW_SIZE-1);
		end function;
	begin
		if clk'event and clk = '1' then
			case state is
				when idle =>
					if NewData = '1' then
						state <= calc;
					end if;
				when calc =>
					baryi.u <= mulrem(ERes(0) * A);
					baryi.v <= mulrem(ERes(1) * A);
					baryi.w <= mulrem(ERes(2) * A);
					state <= output;
				when output =>
					if Continue = '1' then
						Bary <= Baryi;
						state <= idle;
					end if;
				when others => null;
			end case;
		end if;
	end process;

	Ready <= '1' when state = idle else '0';
	OutNew <= '1' when state = output and Continue = '1' else '0';

end Behavioral;
