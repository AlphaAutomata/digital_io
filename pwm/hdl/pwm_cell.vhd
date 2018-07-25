library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity pwm_cell is
	generic (
		COUNTER_WIDTH : integer := 32
	);
	port (
		pwm : out std_logic;
		
		counter              : in std_logic_vector(COUNTER_WIDTH-1 downto 0);
		counter_plus_period  : in std_logic_vector(COUNTER_WIDTH-1 downto 0);
		counter_minus_period : in std_logic_vector(COUNTER_WIDTH-1 downto 0);
		
		polarity : in std_logic;
		period   : in std_logic_vector(COUNTER_WIDTH-1 downto 0);
		duty     : in std_logic_vector(COUNTER_WIDTH-1 downto 0);
		phase    : in std_logic_vector(COUNTER_WIDTH-1 downto 0)
	);
end pwm_cell;

architecture arch of pwm_cell is
	signal comparison : std_logic;
	
	signal thresh_high : std_logic_vector(COUNTER_WIDTH-1 downto 0);
	signal thresh_low  : std_logic_vector(COUNTER_WIDTH-1 downto 0);
begin
	pwm <= comparison when (polarity = '1') else (not comparison);
	
	thresh_high <= std_logic_vector(-signed(phase) + signed(duty));
	thresh_low  <= std_logic_vector(-signed(phase));
	
	-- Drive PWM output based on comparison mode, counter value, and the comparison thresholds.
	process (
		counter,
		counter_plus_period,
		counter_minus_period,
		thresh_high,
		thresh_low
	) begin
		if (
			(
				(signed(counter) < signed(thresh_high)) and
				(signed(counter) >= signed(thresh_low))
			) or (
				(signed(counter_plus_period) < signed(thresh_high)) and
				(signed(counter_plus_period) >= signed(thresh_low))
			) or (
				(signed(counter_minus_period) < signed(thresh_high)) and
				(signed(counter_minus_period) >= signed(thresh_low))
			)
		) then
			comparison <= '1';
		else
			comparison <= '0';
		end if;
	end process;
end arch;
