library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

use work.Common.ALL;

--  Uncomment the following lines to use the declarations that are
--  provided for instantiating Xilinx primitive components.
--library UNISIM;
--use UNISIM.VComponents.all;

entity MemController is
    Port (
		clk : in std_logic;

		CtrlIn : in CtrlInArray;
		CtrlOut : out CtrlOutArray;
		
		data : out std_logic_vector(MEMORY_DATA_WIDTH-1 downto 0);

		memAddr : out std_logic_vector(MEMORY_ADDR_SIZE-1 downto 0);
		memDataOut : out std_logic_vector(MEMORY_DATA_WIDTH-1 downto 0);
		memDataIn : in std_logic_vector(MEMORY_DATA_WIDTH-1 downto 0);
		memWe : out std_logic
	);
end MemController;

architecture Behavioral of MemController is
	type state_type is (idle, readwrite);
	signal state : state_type;

	signal idx : integer range 0 to 1;
begin

	process (clk)
		variable idxloc : integer range 0 to 2;
	begin
		if clk'event and clk = '1' then
			case (state) is
				when idle =>
					idxloc := 2;

					for i in 0 to 1 loop
						if idxloc = 2 then
							if CtrlIn(i).ReadReq = '1' then
								idxloc := i;
							elsif CtrlIn(i).WriteReq = '1' then
								idxloc := i;
							end if;
						end if;
					end loop;
					if idxloc /= 2 then
						memAddr <= ctrlIn(idxloc).Addr;
						memDataOut <= CtrlIn(idxloc).Data;
						state <= readwrite;
						idx <= idxloc;
					end if;
				when readwrite =>
					state <= idle;
			end case;

		end if;
	end process;

	data <= memDataIn;
--	memWe <= '1' when CtrlIn(idx).WriteReq = '1' and CtrlIn(idx).ReadReq = '0' and state = readwrite else '0';

	-- ReadVld control
	process (clk)
	begin
		if clk'event and clk = '1' then
			for i in 0 to 1 loop
				if i = idx then
					if state = idle then
						CtrlOut(i).ReadVld <= '0';
					else
						CtrlOut(i).ReadVld <= CtrlIn(i).ReadReq;
					end if;
					if CtrlIn(i).WriteReq = '1' and  CtrlIn(i).ReadReq = '0' and state = readwrite then
						CtrlOut(i).WriteVld <= '1';
						memWe <= '1';
					else
						CtrlOut(i).WriteVld <= '0';
						memWe <= '0';
					end if;
				else
					CtrlOut(i).ReadVld <= '0';
					CtrlOut(i).WriteVld <= '0';

				end if;
			end loop;
		end if;
	end process;

	-- Write Vld control
--	process (clk)
--	begin
--		if clk'event and clk = '1' then
--			for i in 0 to 1 loop
--				if i = idx then
--				else
--				end if;
--			end loop;
--		end if;
--	end process;

--	CtrlOut(idx).ReadVld <= '0' when state = idle else CtrlIn(idx).ReadReq;
--	CtrlOut(idx).WriteVld <= '1' when CtrlIn(idx).WriteReq = '1' and CtrlIn(idx).ReadReq = '0' and state = readwrite else '0'; -- same as We for now...

end Behavioral;
