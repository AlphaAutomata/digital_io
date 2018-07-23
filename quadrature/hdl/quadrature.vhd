library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity quadrature is
	generic (
		COUNTER_WIDTH : integer := 32
	);
	port (
		in_a : in std_logic;
		in_b : in std_logic;
		
		hw_err : out std_logic;
		
		displacement       : out std_logic_vector(COUNTER_WIDTH-1 downto 0);
		clear_displacement : in  std_logic;
		
		phase_offset       : out std_logic_vector(COUNTER_WIDTH-1 downto 0);
		phase_offset_valid : out std_logic;
		
		a_pulse_width      : out std_logic_vector(COUNTER_WIDTH-1 downto 0);
		a_pulse_polarity   : out std_logic;
		a_pulse_valid      : out std_logic;
		
		b_pulse_width      : out std_logic_vector(COUNTER_WIDTH-1 downto 0);
		b_pulse_polarity   : out std_logic;
		b_pulse_valid      : out std_logic;
		
		clk   : in std_logic;
		rst_n : in std_logic
	);
end quadrature;

architecture arch of quadrature is
	signal in_a_reg : std_logic;
	signal in_b_reg : std_logic;
	
	signal hw_err_next : std_logic;
	
	signal displacement_next       : std_logic_vector(COUNTER_WIDTH-1 downto 0);
	
	signal phase_offset_next       : std_logic_vector(COUNTER_WIDTH-1 downto 0);
	signal phase_offset_valid_next : std_logic;
	
	signal a_pulse_width_next      : std_logic_vector(COUNTER_WIDTH-1 downto 0);
	signal a_pulse_polarity_next   : std_logic;
	signal a_pulse_valid_next      : std_logic;
	
	signal b_pulse_width_next      : std_logic_vector(COUNTER_WIDTH-1 downto 0);
	signal b_pulse_polarity_next   : std_logic;
	signal b_pulse_valid_next      : std_logic;
	
	signal a_time_since_edge : std_logic_vector(COUNTER_WIDTH-1 downto 0);
	signal b_time_since_edge : std_logic_vector(COUNTER_WIDTH-1 downto 0);
	
	signal a_time_since_edge_next : std_logic_vector(COUNTER_WIDTH-1 downto 0);
	signal b_time_since_edge_next : std_logic_vector(COUNTER_WIDTH-1 downto 0);
begin
	process (all) begin
		hw_err_next             <= '0';
		displacement_next       <= displacement;
		phase_offset_next       <= phase_offset;
		phase_offset_valid_next <= '0';
		a_pulse_width_next      <= a_pulse_width;
		a_pulse_polarity_next   <= a_pulse_polarity;
		a_pulse_valid_next      <= '0';
		b_pulse_width_next      <= b_pulse_width;
		b_pulse_polarity_next   <= b_pulse_polarity;
		b_pulse_valid_next      <= '0';
		a_time_since_edge_next  <= std_logic_vector(unsigned(a_time_since_edge) + 1);
		b_time_since_edge_next  <= std_logic_vector(unsigned(b_time_since_edge) + 1);
		
		if ((in_a_reg /= in_a) and (in_b_reg /= in_b)) then
			hw_err_next <= '1';
		elsif (clear_displacement = '1') then
			displacement_next <= (others => '0');
		elsif (in_a_reg /= in_a) then
			if (in_a = in_b) then
				displacement_next <= std_logic_vector(signed(displacement) + 1);
			else
				displacement_next <= std_logic_vector(signed(displacement) - 1);
			end if;
		elsif (in_b_reg /= in_b) then
			if (in_a = in_b) then
				displacement_next <= std_logic_vector(signed(displacement) - 1);
			else
				displacement_next <= std_logic_vector(signed(displacement) + 1);
			end if;
		end if;
		
		if (in_a_reg /= in_a) then
			a_pulse_width_next     <= std_logic_vector(unsigned(a_time_since_edge) + 1);
			a_pulse_polarity_next  <= in_a_reg;
			a_pulse_valid_next     <= '1';
			a_time_since_edge_next <= (others => '0');
		end if;
		
		if (in_b_reg /= in_b) then
			b_pulse_width_next      <= std_logic_vector(unsigned(b_time_since_edge) + 1);
			b_pulse_polarity_next   <= in_b_reg;
			b_pulse_valid_next      <= '1';
			b_time_since_edge_next  <= (others => '0');
		end if;
		
		if (in_a_reg /= in_b_reg) then
			if (in_a = in_b_reg) then
				phase_offset_next       <= std_logic_vector(unsigned(b_time_since_edge) + 1);
				phase_offset_valid_next <= '1';
			elsif (in_b = in_a_reg) then
				phase_offset_next       <= std_logic_vector(0 - unsigned(a_time_since_edge) - 1);
				phase_offset_valid_next <= '1';
			end if;
		end if;
	end process;
	
	process (clk) begin
		if (rising_edge(clk)) then
			in_a_reg <= in_a;
			in_b_reg <= in_b;
			
			if (rst_n = '0') then
				hw_err             <= '0';
				displacement       <= (others => '0');
				phase_offset       <= (others => '0');
				phase_offset_valid <= '0';
				a_pulse_width      <= (others => '0');
				a_pulse_polarity   <= '0';
				a_pulse_valid      <= '0';
				b_pulse_width      <= (others => '0');
				b_pulse_polarity   <= '0';
				b_pulse_valid      <= '0';
				a_time_since_edge  <= (others => '0');
				b_time_since_edge  <= (others => '0');
			else
				hw_err             <= hw_err_next            ;
				displacement       <= displacement_next      ;
				phase_offset       <= phase_offset_next      ;
				phase_offset_valid <= phase_offset_valid_next;
				a_pulse_width      <= a_pulse_width_next     ;
				a_pulse_polarity   <= a_pulse_polarity_next  ;
				a_pulse_valid      <= a_pulse_valid_next     ;
				b_pulse_width      <= b_pulse_width_next     ;
				b_pulse_polarity   <= b_pulse_polarity_next  ;
				b_pulse_valid      <= b_pulse_valid_next     ;
				a_time_since_edge  <= a_time_since_edge_next ;
				b_time_since_edge  <= b_time_since_edge_next ;
			end if;
		end if;
	end process;
end arch;
