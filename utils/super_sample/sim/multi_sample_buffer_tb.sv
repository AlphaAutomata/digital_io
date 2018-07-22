`timescale 1ns / 1ps

module multi_sample_buffer_tb();
	// test parameters
	
	localparam DEFAULT_BAUD         = 7;
	localparam DEFAULT_MULTI_SAMPLE = 2;
	
	// instance parameters
	
	localparam BAUD_WIDTH           = 16;  // Width of the baud rate configuration port.
	localparam MULTI_SAMPLE_WIDTH   = 4;   // Width of the multi-sample configuration port.
                                      
	// system signals
	
	reg clk;
	reg rst_n;
	
	// multi-sample buffer signals
	
	reg buff_rxd;
	
	reg  buff_rx_enable_n;
	wire buff_rx_data    ;
	wire buff_rx         ;
	
	wire [BAUD_WIDTH-1:0]         buff_clk_per_baud;
	wire [MULTI_SAMPLE_WIDTH-1:0] buff_multi_sample;
	
	// multi-sample buffer instance
	
	assign buff_clk_per_baud = DEFAULT_BAUD        ;
	assign buff_multi_sample = DEFAULT_MULTI_SAMPLE;
	
	multi_sample_buffer #(
		.BAUD_WIDTH        (BAUD_WIDTH          ), // Width of the baud rate configuration port.
		.MULTI_SAMPLE_WIDTH(MULTI_SAMPLE_WIDTH  )  // Width of the multi-sample config port.
	) buff (
		// Physical layer interface.
		
		.rxd(buff_rxd), // : in std_logic;
		
		// Control interface.
		
		.rx_enable_n(buff_rx_enable_n), // : in  std_logic;
		.rx_data    (buff_rx_data    ), // : out std_logic;
		.rx         (buff_rx         ), // : out std_logic;
		
		// Configuration interface.
		
		.clk_per_baud(buff_clk_per_baud), // : in std_logic_vector(BAUD_WIDTH-1 downto 0);
		.multi_sample(buff_multi_sample), // : in std_logic_vector(MULTI_SAMPLE_WIDTH-1 downto 0);
		
		// System interface.
		
		.clk  (clk  ), // : in std_logic;
		.rst_n(rst_n)  // : in std_logic
	);
	
	// simulation logic
	
	// initialize registers
	initial begin
		clk   <= 0;
		rst_n <= 0;
		
		buff_rxd <= 1;
		
		buff_rx_enable_n <= 1;
		
		#20;
		
		rst_n <= 1;
		
		#20;
		
		buff_rx_enable_n <= 0;
	end
	
	// 100MHz clock
	always #5 clk <= !clk;
	
	// test procedure
	always @(posedge(clk)) begin
		buff_rxd <= $random;
	end
endmodule
