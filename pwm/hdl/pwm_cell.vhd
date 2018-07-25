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
		
		count_dir : in std_logic;
		polarity  : in std_logic;
		period    : in std_logic_vector(COUNTER_WIDTH-1 downto 0);
		duty      : in std_logic_vector(COUNTER_WIDTH-1 downto 0);
		phase     : in std_logic_vector(COUNTER_WIDTH-1 downto 0)
	);
end pwm_cell;

architecture arch of pwm_cell is
	signal thresh_high : std_logic_vector(COUNTER_WIDTH-1 downto 0);
	signal thresh_low  : std_logic_vector(COUNTER_WIDTH-1 downto 0);
	
	type comparison_mode is (within, outside);
	
	signal mode : comparison_mode;
begin
	mode <= within when (polarity = '1') else outside;
	thresh_high <=
		std_logic_vector(-signed(phase) + signed(duty)) when (count_dir = '1') else
		std_logic_vector(-signed(phase) + signed(period));
	thresh_low <=
		std_logic_vector(-signed(phase)) when (count_dir = '1') else
		std_logic_vector(-signed(phase) + signed(period) - signed(duty));
	
	-- Drive PWM output based on comparison mode, counter value, and the comparison thresholds.
	process (
		mode,
		counter,
		counter_plus_period,
		counter_minus_period,
		thresh_high,
		thresh_low
	) begin
		case (mode) is
			when within =>
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
					pwm <= '1';
				else
					pwm <= '0';
				end if;
				
			when outside =>
				if (
					(
						(signed(counter) >= signed(thresh_high)) or
						(signed(counter) < signed(thresh_low))
					) and (
						(signed(counter_plus_period) >= signed(thresh_high)) or
						(signed(counter_plus_period) < signed(thresh_low))
					) and (
						(signed(counter_minus_period) >= signed(thresh_high)) or
						(signed(counter_minus_period) < signed(thresh_low))
					)
				) then
					pwm <= '1';
				else
					pwm <= '0';
				end if;
				
		end case;
	end process;
end arch;
