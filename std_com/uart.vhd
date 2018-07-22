library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity uart is
	generic(
		BAUD_WIDTH         : integer := 16;    -- Width of the baud rate configuration port.
		MULTI_SAMPLE_WIDTH : integer := 4;     -- Width of the multi-sample configuration port.
		
		DEFAULT_BAUD         : integer := 868; -- Default clock counts per bit; 115200 at 100MHz clock.
		DEFAULT_BYTE_SIZE    : integer := 8;   -- Default to 8-bit byte size.
		DEFAULT_PARITY       : integer := 0;   -- Default to no parity bit.
		DEFAULT_STOP_BITS    : integer := 1;   -- Default to one stop bit.
		DEFAULT_MULTI_SAMPLE : integer := 0    -- Default to no multi-sampling.
	);
	port (
		-- Physical layer interface.
		
		rxd : in  std_logic;
		txd : out std_logic;
		
		-- Control interface.
		
		rx_data : out std_logic_vector(8 downto 0);
		rx      : out std_logic;
		cts     : in  std_logic;
		
		tx_data : in  std_logic_vector(8 downto 0);
		tx      : in  std_logic;
		rts     : out std_logic;
		
		-- State reporting interface.
		
		tx_busy : out std_logic;
		rx_busy : out std_logic;
		
		err_overrun : out std_logic;
		err_break   : out std_logic;
		err_parity  : out std_logic;
		err_frame   : out std_logic;
		
		-- Configuration interface.
		
		config_set : in  std_logic;
		config_ack : out std_logic;
		
		use_cts_rts : in std_logic;
		
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
	
	signal err_overrun_next : std_logic;
	signal err_break_next   : std_logic;
	signal err_parity_next  : std_logic;
	signal err_frame_next   : std_logic;
	
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
	signal byte_size_reg_next    : std_logic_vector(2 downto 0);
	signal parity_reg_next       : std_logic_vector(0 downto 0);
	signal stop_bits_reg_next    : std_logic_vector(1 downto 0);
	
	signal multi_sample_reg_next : std_logic_vector(MULTI_SAMPLE_WIDTH-1 downto 0);
	
	-- Transceiver state.
	
	type trx_state is (idle, trx_start, trx_data, trx_parity, trx_stop);
	
	-- Receive state machine.
	
	signal rx_state      : trx_state;
	signal rx_state_next : trx_state;
	
	signal rx_buffer      : std_logic_vector(8 downto 0);
	signal rx_buffer_next : std_logic_vector(8 downto 0);
	
	signal rx_bit_cnt      : std_logic_vector(3 downto 0);
	signal rx_bit_cnt_next : std_logic_vector(3 downto 0);
begin
	-- Configuration setting.
	
	process (
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
			byte_size_reg_next    <= byte_size   ;
			parity_reg_next(0)    <= parity      ;
			stop_bits_reg_next    <= stop_bits   ;
			multi_sample_reg_next <= multi_sample;
		end if;
	end process;
	
	process (clk) begin
		if (rising_edge(clk)) then
			if (rst_n = '0') then
				config_ack       <= '0';
				use_cts_rts_reg  <= '0';
				clk_per_baud_reg <= std_logic_vector(to_unsigned(DEFAULT_BAUD     , BAUD_WIDTH));
				byte_size_reg    <= std_logic_vector(to_unsigned(DEFAULT_BYTE_SIZE, 4));
				parity_reg       <= std_logic_vector(to_unsigned(DEFAULT_PARITY   , 1));
				stop_bits_reg    <= std_logic_vector(to_unsigned(DEFAULT_STOP_BITS, 2));
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
	
	process (
		use_cts_rts_reg ,
		clk_per_baud_reg,
		byte_size_reg   ,
		parity_reg      ,
		stop_bits_reg   ,
		multi_sample_reg,
		rx           ,
		err_overrun  ,
		err_break    ,
		err_parity   ,
		err_frame    ,
		rx_state     ,
		rx_buffer    ,
		rx_bit_cnt
	) begin
		rx_busy            <= '1';
		rx_next            <= '0';
		err_overrun_next   <= err_overrun  ;
		err_break_next     <= err_break    ;
		err_parity_next    <= err_parity   ;
		err_frame_next     <= err_frame    ;
		rx_state_next      <= rx_state     ;
		rx_buffer_next     <= rx_buffer    ;
		rx_bit_cnt_next    <= rx_bit_cnt   ;
		
		case (rx_state) is
			when idle =>
				rx_busy <= '0';
				
				if (rxd = '0') then -- start receiving on RxD falling edge
					err_overrun_next   <= '0';
					err_break_next     <= '0';
					err_parity_next    <= '0';
					err_frame_next     <= '0';
					rx_state_next      <= trx_start;
					rx_buffer_next     <= (others => '0');
					rx_bit_cnt_next    <= byte_size_reg;
				end if;
				
			when trx_start =>
				
				
			when trx_data =>
				
				
			when trx_parity =>
			when trx_stop =>
		end case;
	end process;
	
	process (clk) begin
		if (rising_edge(clk)) then
			if (rst_n = '0') then
				rx            <= '0';
				err_overrun   <= '0';
				err_break     <= '0';
				err_parity    <= '0';
				err_frame     <= '0';
				rx_state      <= idle;
				rx_buffer     <= (others => '0');
				rx_bit_cnt    <= (others => '0');
			else
				rx            <= rx_next;
				err_overrun   <= err_overrun_next  ;
				err_break     <= err_break_next    ;
				err_parity    <= err_parity_next   ;
				err_frame     <= err_frame_next    ;
				rx_state      <= rx_state_next     ;
				rx_buffer     <= rx_buffer_next    ;
				rx_bit_cnt    <= rx_bit_cnt_next   ;
			end if;
		end if;
	end process;
end arch;
