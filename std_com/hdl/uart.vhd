library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;

entity uart is
	generic (
		MULTI_SAMPLE_WIDTH   : integer := 4;                     -- Baud rate config port width.
		BAUD_WIDTH           : integer := 2**MULTI_SAMPLE_WIDTH; -- Multi-sample config port width.
		
		DEFAULT_BAUD         : integer := 868; -- Default clock counts per bit; 115200 at 100MHz.
		DEFAULT_BYTE_SIZE    : integer := 8;   -- Default to 8-bit byte size.
		DEFAULT_PARITY       : integer := 0;   -- Default to no parity bit.
		DEFAULT_STOP_BITS    : integer := 1;   -- Default to one stop bit.
		DEFAULT_MULTI_SAMPLE : integer := 1    -- Default to no multi-sampling.
	);
	port (
		-- Physical layer interface.
		
		rxd : in  std_logic;
		txd : out std_logic;
		
		-- Control interface.
		
		rx_data : out std_logic_vector(8 downto 0);
		rx      : out std_logic;
		
		tx_data : in  std_logic_vector(8 downto 0);
		tx      : in  std_logic;
		rts     : out std_logic;
		cts     : in  std_logic;
		
		-- State reporting interface.
		
		tx_busy    : out std_logic;
		rx_busy    : out std_logic;
		
		err_break  : out std_logic;
		err_parity : out std_logic;
		err_frame  : out std_logic;
		
		-- Configuration interface.
		
		config_set   : in  std_logic;
		config_ack   : out std_logic;
		
		use_cts_rts  : in std_logic;
		
		clk_per_baud : in std_logic_vector(BAUD_WIDTH-1 downto 0);
		byte_size    : in std_logic_vector(3 downto 0);
		parity       : in std_logic;
		stop_bits    : in std_logic_vector(1 downto 0);
		
		multi_sample : in std_logic_vector(MULTI_SAMPLE_WIDTH-1 downto 0);
		
		-- System interface.
		
		clk   : in std_logic;
		rst_n : in std_logic
	);
end uart;

architecture arch of uart is
	-- Output drivers.
	
	signal rx_next : std_logic;
	
	signal err_break_next  : std_logic;
	signal err_parity_next : std_logic;
	signal err_frame_next  : std_logic;
	
	signal config_ack_next : std_logic;
	
	-- Configuration registers.
	
	signal use_cts_rts_reg  : std_logic;
	
	signal clk_per_baud_reg : std_logic_vector(BAUD_WIDTH-1 downto 0);
	signal byte_size_reg    : std_logic_vector(3 downto 0);
	signal parity_reg       : std_logic_vector(0 downto 0);
	signal stop_bits_reg    : std_logic_vector(1 downto 0);
	
	signal multi_sample_reg : std_logic_vector(MULTI_SAMPLE_WIDTH-1 downto 0);
	
	signal use_cts_rts_reg_next  : std_logic;
	
	signal clk_per_baud_reg_next : std_logic_vector(BAUD_WIDTH-1 downto 0);
	signal byte_size_reg_next    : std_logic_vector(3 downto 0);
	signal parity_reg_next       : std_logic_vector(0 downto 0);
	signal stop_bits_reg_next    : std_logic_vector(1 downto 0);
	
	signal multi_sample_reg_next : std_logic_vector(MULTI_SAMPLE_WIDTH-1 downto 0);
	
	-- Transceiver state.
	
	type trx_state is (idle, trx_req, trx_start, trx_data, trx_parity, trx_stop);
	
	-- Receive state machine.
	
	signal rx_state      : trx_state;
	signal rx_state_next : trx_state;
	
	signal rx_start_buffer      : std_logic;
	signal rx_start_buffer_next : std_logic;
	
	signal rx_buffer      : std_logic_vector(8 downto 0);
	signal rx_buffer_next : std_logic_vector(8 downto 0);
	
	signal rx_parity_buffer      : std_logic;
	signal rx_parity_buffer_next : std_logic;
	
	signal rx_stop_buffer      : std_logic_vector(1 downto 0);
	signal rx_stop_buffer_next : std_logic_vector(1 downto 0);
	
	signal data_parity : std_logic;
	
	signal rx_bit_cnt      : std_logic_vector(3 downto 0);
	signal rx_bit_cnt_next : std_logic_vector(3 downto 0);
	
	component multi_sample_buffer is
		generic (
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
	end component;
	
	signal ss_rxd : std_logic;
	
	signal ss_rx_enable_n : std_logic;
	signal ss_rx_data     : std_logic;
	signal ss_rx          : std_logic;
	
	signal ss_clk_per_baud : std_logic_vector(BAUD_WIDTH-1 downto 0);
	signal ss_multi_sample : std_logic_vector(MULTI_SAMPLE_WIDTH-1 downto 0);
	
	-- Transmit state machine
	
	signal tx_state      : trx_state;
	signal tx_state_next : trx_state;
	
	signal tx_parity : std_logic;
	
	signal tx_buffer     : std_logic_vector(8 downto 0);
	signal tx_bit_cnt    : std_logic_vector(3 downto 0);
	signal tx_bit_cntdwn : std_logic_vector(BAUD_WIDTH-1 downto 0);
	
	signal tx_buffer_next     : std_logic_vector(8 downto 0);
	signal tx_bit_cnt_next    : std_logic_vector(3 downto 0);
	signal tx_bit_cntdwn_next : std_logic_vector(BAUD_WIDTH-1 downto 0);
begin
	rx_data <=
		rx_buffer       when (unsigned(byte_size_reg) = 9) else
		rx_buffer srl 1 when (unsigned(byte_size_reg) = 8) else
		rx_buffer srl 2 when (unsigned(byte_size_reg) = 7) else
		rx_buffer srl 3 when (unsigned(byte_size_reg) = 6) else
		rx_buffer srl 4 when (unsigned(byte_size_reg) = 5) else
		(others => '-');
	
	-- Configuration setting.
	
	process (
		tx_busy     ,
		rx_busy     ,
		use_cts_rts ,
		clk_per_baud,
		byte_size   ,
		parity      ,
		stop_bits   ,
		multi_sample,
		data_parity ,
		tx_parity   ,
		config_set  ,
		use_cts_rts_reg ,
		clk_per_baud_reg,
		byte_size_reg   ,
		parity_reg      ,
		stop_bits_reg   ,
		multi_sample_reg
	) begin
		config_ack_next       <= '0'             ;
		use_cts_rts_reg_next  <= use_cts_rts_reg ;
		clk_per_baud_reg_next <= clk_per_baud_reg;
		byte_size_reg_next    <= byte_size_reg   ;
		parity_reg_next       <= parity_reg      ;
		stop_bits_reg_next    <= stop_bits_reg   ;
		multi_sample_reg_next <= multi_sample_reg;
		
		if ((config_set = '1') and (tx_busy = '0') and (rx_busy = '0')) then
			config_ack_next       <= '1'         ;
			use_cts_rts_reg_next  <= use_cts_rts ;
			clk_per_baud_reg_next <= clk_per_baud;
			byte_size_reg_next    <= std_logic_vector(unsigned(byte_size) - 1);
			parity_reg_next(0)    <= parity      ;
			stop_bits_reg_next    <= std_logic_vector(unsigned(stop_bits) - 1);
			multi_sample_reg_next <= multi_sample;
		end if;
	end process;
	
	process (clk) begin
		if (rising_edge(clk)) then
			if (rst_n = '0') then
				config_ack       <= '0';
				use_cts_rts_reg  <= '0';
				clk_per_baud_reg <= std_logic_vector(to_unsigned(DEFAULT_BAUD       , BAUD_WIDTH));
				byte_size_reg    <= std_logic_vector(to_unsigned(DEFAULT_BYTE_SIZE-1, 4));
				parity_reg       <= std_logic_vector(to_unsigned(DEFAULT_PARITY     , 1));
				stop_bits_reg    <= std_logic_vector(to_unsigned(DEFAULT_STOP_BITS-1, 2));
				multi_sample_reg <=
					std_logic_vector(
						to_unsigned(DEFAULT_MULTI_SAMPLE, MULTI_SAMPLE_WIDTH)
					);
			else
				config_ack       <= config_ack_next      ;
				use_cts_rts_reg  <= use_cts_rts_reg_next ;
				clk_per_baud_reg <= clk_per_baud_reg_next;
				byte_size_reg    <= byte_size_reg_next   ;
				parity_reg       <= parity_reg_next      ;
				multi_sample_reg <= multi_sample_reg_next;
			end if;
		end if;
	end process;
	
	-- Receive state machine.
	
	data_parity <=
		xor_reduce(rx_buffer(8 downto 0)) when (unsigned(byte_size_reg) = 9) else
		xor_reduce(rx_buffer(8 downto 1)) when (unsigned(byte_size_reg) = 8) else
		xor_reduce(rx_buffer(8 downto 2)) when (unsigned(byte_size_reg) = 7) else
		xor_reduce(rx_buffer(8 downto 3)) when (unsigned(byte_size_reg) = 6) else
		xor_reduce(rx_buffer(8 downto 4)) when (unsigned(byte_size_reg) = 5) else
		'-';
	
	process (
		rxd,
		clk_per_baud_reg,
		byte_size_reg   ,
		parity_reg      ,
		stop_bits_reg   ,
		multi_sample_reg,
		err_break       ,
		err_parity      ,
		err_frame       ,
		rx_state        ,
		rx_start_buffer ,
		rx_buffer       ,
		rx_parity_buffer,
		rx_stop_buffer  ,
		rx_bit_cnt      ,
		ss_rx     ,
		ss_rx_data,
		data_parity
	) begin
		rx_busy               <= '1';
		rx_next               <= '0';
		err_break_next        <= err_break       ;
		err_parity_next       <= err_parity      ;
		err_frame_next        <= err_frame       ;
		rx_state_next         <= rx_state        ;
		rx_start_buffer_next  <= rx_start_buffer ;
		rx_buffer_next        <= rx_buffer       ;
		rx_parity_buffer_next <= rx_parity_buffer;
		rx_stop_buffer_next   <= rx_stop_buffer  ;
		rx_bit_cnt_next       <= rx_bit_cnt      ;
		ss_rx_enable_n        <= '0';
		
		case (rx_state) is
			when idle =>
				rx_busy        <= '0';
				ss_rx_enable_n <= '1';
				
				if (rxd = '0') then -- start receiving on RxD falling edge
					err_break_next        <= '0';
					err_parity_next       <= '0';
					err_frame_next        <= '0';
					rx_state_next         <= trx_start;
					rx_start_buffer_next  <= '0';
					rx_buffer_next        <= (others => '0');
					rx_parity_buffer_next <= '0';
					rx_stop_buffer_next   <= (others => '0');
					rx_bit_cnt_next       <= byte_size_reg;
					ss_rx_enable_n        <= '0';
				end if;
				
			when trx_start =>
				if (ss_rx = '1') then
					if (ss_rx_data = '1') then
						err_frame_next <= '1';
					end if;
					
					rx_state_next        <= trx_data;
					rx_start_buffer_next <= ss_rx_data;
				end if;
				
			when trx_data =>
				if (ss_rx = '1') then
					rx_bit_cnt_next <= std_logic_vector(unsigned(rx_bit_cnt) - 1);
					
					if (unsigned(rx_bit_cnt) = 0) then
						if (parity_reg = "1") then
							rx_state_next <= trx_parity;
						else
							rx_state_next <= trx_stop;
							rx_bit_cnt_next(3 downto 2) <= (others => '0');
							rx_bit_cnt_next(1 downto 0) <= stop_bits_reg;
						end if;
					else
						rx_buffer_next <= ss_rx_data & rx_buffer(8 downto 1);
					end if;
				end if;
				
			when trx_parity =>
				if (ss_rx = '1') then
					if (ss_rx_data /= data_parity) then
						err_parity_next <= '1';
					end if;
					
					rx_state_next         <= trx_stop;
					rx_parity_buffer_next <= ss_rx_data;
					rx_bit_cnt_next(3 downto 2) <= (others => '0');
					rx_bit_cnt_next(1 downto 0) <= stop_bits_reg;
				end if;
				
			when trx_stop =>
				if (ss_rx = '1') then
					if (ss_rx_data /= '1') then
						err_frame_next <= '1';
					end if;
					
					if (unsigned(rx_bit_cnt) = 0) then
						rx_next        <= '1';
						
						if (
							unsigned(
								rx_start_buffer & rx_buffer & rx_parity_buffer & rx_stop_buffer
							) = 0
						) then
							err_break_next <= '1';
						end if;
						
						rx_state_next <= idle;
					end if;
					
					rx_bit_cnt_next     <= std_logic_vector(unsigned(rx_bit_cnt) - 1);
					rx_stop_buffer_next <= ss_rx_data & rx_stop_buffer(1);
				end if;
			
			when trx_req =>
				rx_state_next <= idle;
				
		end case;
	end process;
	
	ss_rxd <= rxd;
	
	ss_clk_per_baud <= clk_per_baud_reg;
	ss_multi_sample <= multi_sample_reg;
	
	ss : multi_sample_buffer
	generic map (
		MULTI_SAMPLE_WIDTH => MULTI_SAMPLE_WIDTH,
		BAUD_WIDTH         => BAUD_WIDTH        
	) port map (
		-- Physical layer interface.
		
		rxd => ss_rxd,
		
		-- Control interface.
		
		rx_enable_n => ss_rx_enable_n,
		rx_data     => ss_rx_data    ,
		rx          => ss_rx         ,
		
		-- Configuration interface.
		
		clk_per_baud => ss_clk_per_baud,
		multi_sample => ss_multi_sample,
		
		-- System interface.
		
		clk   => clk  ,
		rst_n => rst_n
	);
	
	process (clk) begin
		if (rising_edge(clk)) then
			if (rst_n = '0') then
				rx               <= '0';
				err_break        <= '0';
				err_parity       <= '0';
				err_frame        <= '0';
				rx_state         <= idle;
				rx_start_buffer  <= '0';
				rx_buffer        <= (others => '0');
				rx_parity_buffer <= '0';
				rx_stop_buffer   <= (others => '1');
				rx_bit_cnt       <= (others => '0');
			else
				rx               <= rx_next              ;
				err_break        <= err_break_next       ;
				err_parity       <= err_parity_next      ;
				err_frame        <= err_frame_next       ;
				rx_state         <= rx_state_next        ;
				rx_start_buffer  <= rx_start_buffer_next ;
				rx_buffer        <= rx_buffer_next       ;
				rx_parity_buffer <= rx_parity_buffer_next;
				rx_stop_buffer   <= rx_stop_buffer_next  ;
				rx_bit_cnt       <= rx_bit_cnt_next      ;
			end if;
		end if;
	end process;
	
	-- transmit state machine
	
	tx_parity <= 
		xor_reduce(tx_buffer(8 downto 0)) when (unsigned(byte_size_reg) = 9) else
		xor_reduce(tx_buffer(8 downto 1)) when (unsigned(byte_size_reg) = 8) else
		xor_reduce(tx_buffer(8 downto 2)) when (unsigned(byte_size_reg) = 7) else
		xor_reduce(tx_buffer(8 downto 3)) when (unsigned(byte_size_reg) = 6) else
		xor_reduce(tx_buffer(8 downto 4)) when (unsigned(byte_size_reg) = 5) else
		'-';
	
	process (
		tx_data,
		tx     ,
		cts    ,
		use_cts_rts_reg ,
		clk_per_baud_reg,
		byte_size_reg   ,
		parity_reg      ,
		stop_bits_reg   ,
		multi_sample_reg,
		tx_state     ,
		tx_buffer    ,
		tx_bit_cnt   ,
		tx_bit_cntdwn,
		tx_parity
	) begin
		rts     <= '0';
		tx_busy <= '1';
		tx_state_next      <= tx_state     ;
		tx_buffer_next     <= tx_buffer    ;
		tx_bit_cnt_next    <= tx_bit_cnt   ;
		tx_bit_cntdwn_next <= tx_bit_cntdwn;
		
		case (tx_state) is
			when idle =>
				txd     <= '1';
				rts     <= '1';
				tx_busy <= '0';
				
				if (tx = '1') then
					if (use_cts_rts_reg = '1') then
						tx_state_next <= trx_req;
					else
						tx_state_next <= trx_start;
					end if;
					
					tx_buffer_next     <= tx_data;
					tx_bit_cnt_next    <= byte_size_reg;
					tx_bit_cntdwn_next <= clk_per_baud_reg;
				end if;
				
			when trx_req =>
				txd     <= '1';
				
				if (cts = '0') then
					tx_state_next <= trx_start;
				end if;
				
			when trx_start =>
				txd <= '0';
				
				if (unsigned(tx_bit_cntdwn) = 0) then
					tx_state_next      <= trx_data;
					tx_bit_cntdwn_next <= clk_per_baud_reg;
				else
					tx_bit_cntdwn_next <= std_logic_vector(unsigned(tx_bit_cntdwn) - 1);
				end if;
				
			when trx_data =>
				txd <= tx_buffer(0);
				
				if (unsigned(tx_bit_cntdwn) = 0) then
					if (unsigned(tx_bit_cnt) = 0) then
						if (parity_reg = "1") then
							tx_state_next <= trx_parity;
						else
							tx_state_next <= trx_stop;
						end if;
						
						tx_bit_cnt_next(3 downto 2) <= (others => '0');
						tx_bit_cnt_next(1 downto 0) <= stop_bits_reg;
					else
						tx_bit_cnt_next <= std_logic_vector(unsigned(tx_bit_cnt) - 1);
					end if;
					
					tx_buffer_next     <= tx_buffer ror 1;
					tx_bit_cntdwn_next <= clk_per_baud_reg;
				else
					tx_bit_cntdwn_next <= std_logic_vector(unsigned(tx_bit_cntdwn) - 1);
				end if;
				
			when trx_parity =>
				txd <= tx_parity;
				
				if (unsigned(tx_bit_cntdwn) = 0) then
					tx_state_next      <= trx_stop;
					tx_bit_cntdwn_next <= clk_per_baud_reg;
				else
					tx_bit_cntdwn_next <= std_logic_vector(unsigned(tx_bit_cntdwn) - 1);
				end if;
				
			when trx_stop =>
				txd <= '1';
				
				if (unsigned(tx_bit_cntdwn) = 0) then
					if (unsigned(tx_bit_cnt) = 0) then
						tx_state_next <= idle;
					end if;
					
					tx_bit_cnt_next    <= std_logic_vector(unsigned(tx_bit_cnt) - 1);
					tx_bit_cntdwn_next <= clk_per_baud_reg;
				else
					tx_bit_cntdwn_next <= std_logic_vector(unsigned(tx_bit_cntdwn) - 1);
				end if;
				
		end case;
	end process;
	
	process (clk) begin
		if (rising_edge(clk)) then
			if (rst_n = '0') then
				tx_state      <= idle;
				tx_buffer     <= (others => '0');
				tx_bit_cnt    <= (others => '0');
				tx_bit_cntdwn <= (others => '0');
			else
				tx_state      <= tx_state_next     ;
				tx_buffer     <= tx_buffer_next    ;
				tx_bit_cnt    <= tx_bit_cnt_next   ;
				tx_bit_cntdwn <= tx_bit_cntdwn_next;
			end if;
		end if;
	end process;
end arch;
