library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity multi_sample_buffer is
	generic(
		MULTI_SAMPLE_WIDTH : integer := 4;
		BAUD_WIDTH         : integer := 2**MULTI_SAMPLE_WIDTH
	);
	port (
		-- Physical layer interface.
		
		rxd : in std_logic;
		
		-- Control interface.
		
		rx_enable_n : in  std_logic;
		rx_data     : out std_logic;
		rx          : out std_logic;
		
		-- Configuration interface.
		
		clk_per_baud : in std_logic_vector(BAUD_WIDTH-1 downto 0);
		multi_sample : in std_logic_vector(MULTI_SAMPLE_WIDTH-1 downto 0);
		
		-- System interface.
		
		clk   : in std_logic;
		rst_n : in std_logic
	);
end multi_sample_buffer;

architecture arch of multi_sample_buffer is
    signal rxd_v : std_logic_vector(0 downto 0);
    
    signal rx_data_next : std_logic;
	signal rx_next      : std_logic;
    
	type sample_state is (idle, prepad, sample, postpad);
	
	signal state      : sample_state;
	signal state_next : sample_state;
	
	signal half_remainder             : std_logic_vector(BAUD_WIDTH-1 downto 0);
	signal half_remainder_decremented : std_logic_vector(BAUD_WIDTH-1 downto 0);
	signal rx_clk_per_sample          : std_logic_vector(BAUD_WIDTH-1 downto 0);
	signal rx_samples_per_bit         : std_logic_vector(MULTI_SAMPLE_WIDTH-1 downto 0);
	
	signal rx_sample_cntdwn      : std_logic_vector(BAUD_WIDTH-1 downto 0);
	signal rx_sample_cntdwn_next : std_logic_vector(BAUD_WIDTH-1 downto 0);
	
	signal rx_sample_cnt      : std_logic_vector(MULTI_SAMPLE_WIDTH-1 downto 0);
	signal rx_sample_cnt_next : std_logic_vector(MULTI_SAMPLE_WIDTH-1 downto 0);
	
	signal rx_samples      : std_logic_vector(BAUD_WIDTH-1 downto 0);
	signal rx_samples_next : std_logic_vector(BAUD_WIDTH-1 downto 0);
begin
	-- use standard logic vector representation of receive bit to use in addition
    rxd_v(0) <= rxd;
	
	-- clk counts   / clk counts  \   / /   sample    \
	-- ---------- = | ----------- |  /  | ----------- |
	--   sample     \ bit-audible / /   \ bit-audible /
	--
	--                     sample
	-- where dividing by ----------- is equivalent to right-shifting by (multi_sample). See below.
	--                   bit-audible
	rx_clk_per_sample <=
		std_logic_vector(
			unsigned(clk_per_baud srl to_integer(unsigned(multi_sample))) - 1
		);
	
	--   sample       (multi_sample)
	-- ----------- = 2
	-- bit-audible
	--                             (multi_sample)
	-- Multiplying or dividing by 2               is equivalent to a left-shift or right-shift,
	-- respectively, by (multi_sample) number of bits.
	rx_samples_per_bit <= 
		std_logic_vector(
			to_unsigned(
				2**to_integer(unsigned(multi_sample)) - 1,
				MULTI_SAMPLE_WIDTH
			)
		);
	
	--                  / clk counts  \   / /   sample    \
	-- The remainder of | ----------- |  /  | ----------- | is the last (multi_sample) number of
	--                  \ bit-audible / /   \ bit-audible /
	--         clk counts 
	-- bits in -----------. Half that amount is the remainder right-shifted by 1, as done by the
	--         bit-audible
	-- name-indexing within the generate-loop.
	half_remainder(BAUD_WIDTH-1) <= '0';
	GEN_REMAINDER : for i in (BAUD_WIDTH-2) downto 0 generate
	begin
		half_remainder(i) <= clk_per_baud(i+1) when (i+1 < unsigned(multi_sample)) else '0';
	end generate GEN_REMAINDER;
	half_remainder_decremented <= std_logic_vector(unsigned(half_remainder) - 1);
	
	process (all) begin
		rx_data_next          <= rx_data         ;
		rx_next               <= '0'             ;
		state_next            <= state           ;
		rx_sample_cntdwn_next <= rx_sample_cntdwn;
		rx_sample_cnt_next    <= rx_sample_cnt   ;
		rx_samples_next       <= rx_samples      ;
		
		-- If the active-low enable is set, idle the state machine. Otherwise, run it.
		if (rx_enable_n = '1') then
			state_next <= idle;
		else
			-- State machine tracking what stage in a bit-sample we are in.
			--
			-- All samples are taken in the `sample` state. However, the amount of time spent in
			--                   clk counts
			-- `sample` state is ---------- * (number of samples), and the right-shift used to
			--                     sample
			--        clk counts
			-- obtain ---------- entirely destroys information about the remainder of that division.
			--          sample
			-- To account for the remainder not being included, add a `prepad` state and a `postpad`
			-- state to count out the remainder value when necessary.
			case (state) is
				when idle =>
					--    / clk counts  \   / /   sample    \
					-- If | ----------- |  /  | ----------- | has a remainder of 0 or 1, skip the
					--    \ bit-audible / /   \ bit-audible /
					--
					-- pre-padding counter. Otherwise, pre-pad the counter with half_remainder.
					if (unsigned(half_remainder) = 0) then
						state_next            <= sample;
						rx_sample_cntdwn_next <= rx_clk_per_sample;
						rx_sample_cnt_next    <= rx_samples_per_bit;
						rx_samples_next       <= (others => '0');
					else
						state_next            <= prepad;
						rx_sample_cntdwn_next <= half_remainder_decremented;
					end if;
					
				when prepad =>
					-- Pre-pad count done, go to `sample` state.
					if (unsigned(rx_sample_cntdwn) = 0) then
						state_next            <= sample;
						rx_sample_cntdwn_next <= rx_clk_per_sample;
						rx_sample_cnt_next    <= rx_samples_per_bit;
						rx_samples_next       <= (others => '0');
					else
						rx_sample_cntdwn_next <= std_logic_vector(unsigned(rx_sample_cntdwn) - 1);
					end if;
					
				when sample =>
					-- If the sample countdown is zero, take a sample or move to the next state.
					-- Otherwise, decrement the counter.
					if (unsigned(rx_sample_cntdwn) = 0) then
						-- If the proper number of samples have been taken, output the sampled data
						-- and go to the next state. Otherwise, take a sample, decrement the number
						-- of samples that still need to be taken, and re-load the sampling
						-- countdown.
						if (unsigned(rx_sample_cnt) = 0) then
							-- Signal data valid.
							rx_next <= '1';
							-- rx_samples is the the sum of all samples taken. Take the average of
							-- all samples to produce the data reading. Taking a direct average,
							-- as below,
							--               / /   sample    \
							-- (rx_samples) /  | ----------- |
							--             /   \ bit-audible /
							-- would produce a number between 0 and 1. Using a right-shift to do the
							-- integer division would always produce zero. Instead, do
							--                 / /   sample    \
							-- (2*rx_samples) /  | ----------- |
							--               /   \ bit-audible /
							-- to produce a number between 0 and 2. The right-shift division now
							-- gives the proper data reading.
							if (
								unsigned(rx_samples srl to_integer(unsigned(multi_sample) - 1)) > 0
							) then
								rx_data_next <= '1';
							else
								rx_data_next <= '0';
							end if;
							
							-- If clk_per_baud is an odd number, always post-pad. Otherwise,
							-- post-pad if half_remainder is not zero.
							if (clk_per_baud(0) = '1') then
								state_next            <= postpad;
								rx_sample_cntdwn_next <= half_remainder;
							elsif (unsigned(half_remainder) = 0) then
								state_next            <= sample;
								rx_sample_cntdwn_next <= rx_clk_per_sample;
								rx_sample_cnt_next    <= rx_samples_per_bit;
								rx_samples_next       <= (others => '0');
							else
								state_next            <= postpad;
								rx_sample_cntdwn_next <= half_remainder_decremented;
							end if;
						else
							rx_sample_cntdwn_next <= rx_clk_per_sample;
							rx_sample_cnt_next    <= std_logic_vector(unsigned(rx_sample_cnt) - 1);
							rx_samples_next       <=
								std_logic_vector(
									unsigned(rx_samples) + unsigned(rxd_v)
								);
						end if;
					else
						rx_sample_cntdwn_next <= std_logic_vector(unsigned(rx_sample_cntdwn) - 1);
					end if;
					
				when postpad =>
					-- If the countdown has expired, go to the next state. Otherwise, keep counting.
					if (unsigned(rx_sample_cntdwn) = 0) then
						-- If the half_remainder is zero, continue sampling. Otherwise, do the
						-- proper pre-padding countdown.
						if (unsigned(half_remainder) = 0) then
							state_next            <= sample;
							rx_sample_cntdwn_next <= rx_clk_per_sample;
							rx_sample_cnt_next    <= rx_samples_per_bit;
							rx_samples_next       <= (others => '0');
						else
							state_next            <= prepad;
							rx_sample_cntdwn_next <= half_remainder_decremented;
						end if;
					else
						rx_sample_cntdwn_next <= std_logic_vector(unsigned(rx_sample_cntdwn) - 1);
					end if;
					
			end case;
		end if;
	end process;
	
	process (clk) begin
		if (rising_edge(clk)) then
			if (rst_n = '0') then
				rx_data          <= '0';
				rx               <= '0';
				state            <= idle;
				rx_sample_cntdwn <= (others => '0');
				rx_sample_cnt    <= (others => '0');
				rx_samples       <= (others => '0');
			else
				rx_data          <= rx_data_next         ;
				rx               <= rx_next              ;
				state            <= state_next           ;
				rx_sample_cntdwn <= rx_sample_cntdwn_next;
				rx_sample_cnt    <= rx_sample_cnt_next   ;
				rx_samples       <= rx_samples_next      ;
			end if;
		end if;
	end process;
end arch;
