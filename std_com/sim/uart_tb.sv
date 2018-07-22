`timescale 1ns / 1ps

module uart_tb();
	localparam MULTI_SAMPLE_WIDTH   = 4;
	localparam BAUD_WIDTH           = 16;
	
	localparam DEFAULT_BAUD         = 868;
	localparam DEFAULT_BYTE_SIZE    = 8;
	localparam DEFAULT_PARITY       = 0;
	localparam DEFAULT_STOP_BITS    = 1;
	localparam DEFAULT_MULTI_SAMPLE = 2; 
	
	reg [8:0] test_data;
	reg       test_send;
	
	reg tx_busy_reg;
	
	reg [8:0] rcv_data;
	
	reg clk  ;
	reg rst_n;
	
	wire trx_rxd;
	wire trx_txd;
	
	wire [8:0] trx_rx_data;
	wire       trx_rx     ;
	
	wire [8:0] trx_tx_data;
	wire       trx_tx     ;
	wire       trx_rts    ;
	wire       trx_cts    ;
	
	wire trx_tx_busy   ;
	wire trx_rx_busy   ;
	
	wire trx_err_break ;
	wire trx_err_parity;
	wire trx_err_frame ;
	
	wire trx_config_set  ;
	wire trx_config_ack  ;
	
	wire trx_use_cts_rts ;
	
	wire [BAUD_WIDTH-1:0] trx_clk_per_baud;
	wire [3:0]            trx_byte_size   ;
	wire                  trx_parity      ;
	wire [1:0]            trx_stop_bits   ;
	
	wire [MULTI_SAMPLE_WIDTH-1:0] trx_multi_sample;
	
	assign trx_rxd = trx_txd;
	
	assign trx_tx_data = test_data;
	assign trx_tx      = test_send;
	assign trx_cts     = 0;
	
	assign trx_config_set   = 0;
	
	assign trx_use_cts_rts  = 0;
	
	assign trx_clk_per_baud = DEFAULT_BAUD     ;
	assign trx_byte_size    = DEFAULT_BYTE_SIZE;
	assign trx_parity       = DEFAULT_PARITY   ;
	assign trx_stop_bits    = DEFAULT_STOP_BITS;
	
	assign trx_multi_sample = DEFAULT_MULTI_SAMPLE;

	uart #(
		.MULTI_SAMPLE_WIDTH  (MULTI_SAMPLE_WIDTH  ), // Baud rate config port width.
		.BAUD_WIDTH          (BAUD_WIDTH          ), // Multi-sample config port width.
		
		.DEFAULT_BAUD        (DEFAULT_BAUD        ), // Default clock counts per bit.
		.DEFAULT_BYTE_SIZE   (DEFAULT_BYTE_SIZE   ), // Default to 8-bit byte size.
		.DEFAULT_PARITY      (DEFAULT_PARITY      ), // Default to no parity bit.
		.DEFAULT_STOP_BITS   (DEFAULT_STOP_BITS   ), // Default to one stop bit.
		.DEFAULT_MULTI_SAMPLE(DEFAULT_MULTI_SAMPLE)  // Default to no multi-sampling.
	) trx (
		// Physical layer interface.
		
		.rxd(trx_rxd), // : in  std_logic;
		.txd(trx_txd), // : out std_logic;
		
		// Control interface.
		
		.rx_data(trx_rx_data), // : out std_logic_vector(8 downto 0);
		.rx     (trx_rx     ), // : out std_logic;
		
		.tx_data(trx_tx_data), // : in  std_logic_vector(8 downto 0);
		.tx     (trx_tx     ), // : in  std_logic;
		.rts    (trx_rts    ), // : out std_logic;
		.cts    (trx_cts    ), // : in  std_logic;
		
		// State reporting interface.
		
		.tx_busy    (trx_tx_busy   ), // : out std_logic;
		.rx_busy    (trx_rx_busy   ), // : out std_logic;
		
		.err_break  (trx_err_break ), // : out std_logic;
		.err_parity (trx_err_parity), // : out std_logic;
		.err_frame  (trx_err_frame ), // : out std_logic;
		
		// Configuration interface.
		
		.config_set  (trx_config_set  ), // : in  std_logic;
		.config_ack  (trx_config_ack  ), // : out std_logic;
		
		.use_cts_rts (trx_use_cts_rts ), // : in std_logic;
		
		.clk_per_baud(trx_clk_per_baud), // : in std_logic_vector(BAUD_WIDTH-1 downto 0);
		.byte_size   (trx_byte_size   ), // : in std_logic_vector(3 downto 0);
		.parity      (trx_parity      ), // : in std_logic;
		.stop_bits   (trx_stop_bits   ), // : in std_logic_vector(1 downto 0);
		
		.multi_sample(trx_multi_sample), // : in std_logic_vector(MULTI_SAMPLE_WIDTH-1 downto 0);
		
		// System interface.
		
		.clk  (clk  ), // : in std_logic;
		.rst_n(rst_n)  // : in std_logic
	);
	
	initial begin
		test_data <= 0;
		test_send <= 0;
	
		clk   <= 0;
		rst_n <= 0;
		
		#20;
		
		rst_n <= 1;
	end
	
	always #5 clk <= !clk;
	
	always @(posedge(clk)) begin
		tx_busy_reg <= trx_tx_busy;
		
		if (rst_n == 1'b0) begin
			test_data <= 0;
			test_send <= 1;
		end else begin
			if (tx_busy_reg == 1'b1 && trx_tx_busy == 1'b0) begin
				test_send <= 1'b1;
				test_data <= test_data + 1;
			end
			
			if (test_send == 1'b1) begin
				test_send <= 1'b0;
			end
			
			if (trx_rx == 1'b1) begin
				rcv_data <= trx_rx_data;
			end
		end
	end
endmodule
