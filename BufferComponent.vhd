library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

--  Uncomment the following lines to use the declarations that are
--  provided for instantiating Xilinx primitive components.
--library UNISIM;
--use UNISIM.VComponents.all;

entity BufferComponent is
	Port (
		clk : in std_logic
	);
end BufferComponent;

architecture Behavioral of BufferComponent is

	------- States ----------------------------------------------------------
	type state_type is (clear_start, clear, idle, render);
	signal state : state_type := clear_start;

	------- Memory input/output ---------------------------------------------
	signal addr : std_logic_vector(19 downto 0) := (others=>'0');
	signal we : std_logic := '0';
	signal di : std_logic_vector(7 downto 0);
	signal do : std_logic_vector(7 downto 0);

	------- Signals used for clear operation --------------------------------
	signal clear_count : std_logic_vector(1 downto 0);
	
begin
	Memory : entity work.RAM
		generic map(
			WORD_SIZE => 8,
			WORD_COUNT => 3 * 160 * 120,
			ADDR_SIZE => 20
		)
		port map (
			addr => addr,
			clk => clk,
			we => we,
			din => di,
			dout => do
		)
	;

	process (clk)
	begin
		if clk'event and clk='1' then
			case state is
				when clear_start =>
					addr <= (others=>'0');
					clear_count <= (others=>'0');
					state <= clear;
				when clear =>
					we <= '1';

					if clear_count = "00" then
						di <= X"11";
					elsif clear_count = "01" then
						di <= X"22";
					else
						di <= X"44";
					end if;

					if addr /= 0 or clear_count /= 0 then
						addr <= addr + 1;
					end if;

					if clear_count = "10" then
						clear_count <= "00";
					else
						clear_count <= clear_count + 1;
					end if;


					if addr = B"0000_00000000_00000011" then
						we <= '0';
						state <= idle;
					end if;

				when others => null;
			end case;
		end if;
	end process;

end Behavioral;
