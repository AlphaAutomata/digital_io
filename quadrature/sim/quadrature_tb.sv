`timescale 1ns / 1ps

module quadrature_tb();
	localparam COUNTER_WIDTH = 32;
	
	localparam [3:0][1:0] pattern = {
		2'b01,
		2'b00,
		2'b10,
		2'b11
	};
	
	integer num_stages;
	integer time_increment;
	integer stage_increment;
	
	integer time_counter;
	
	reg [1:0] stage;
	
	reg clk;
	reg rst_n;
	
	reg in_a;
	reg in_b;
		
	wire hw_err;
		
	wire [COUNTER_WIDTH-1:0] displacement          ;
	wire                     displacement_updated  ;
	wire                     clear_displacement    ;
	
	wire [COUNTER_WIDTH-1:0] phase_offset          ;
	wire                     phase_offset_valid    ;
		
	wire [COUNTER_WIDTH-1:0] antiphase_offset      ;
	wire                     antiphase_offset_valid;
	
	wire [COUNTER_WIDTH-1:0] a_pulse_width         ;
	wire                     a_pulse_polarity      ;
	wire                     a_pulse_valid         ;
	
	wire [COUNTER_WIDTH-1:0] b_pulse_width         ;
	wire                     b_pulse_polarity      ;
	wire                     b_pulse_valid         ;
	
	assign clear_displacement = 0;
	
	quadrature #(
		.COUNTER_WIDTH(COUNTER_WIDTH)
	) dec (
		.in_a(in_a),
		.in_b(in_b),
		
		.hw_err(hw_err),
		
		.displacement          (displacement          ),
		.displacement_updated  (displacement_updated  ),
		.clear_displacement    (clear_displacement    ),
		
		.phase_offset          (phase_offset          ),
		.phase_offset_valid    (phase_offset_valid    ),
		
		.antiphase_offset      (antiphase_offset      ),
		.antiphase_offset_valid(antiphase_offset_valid),
		                    
		.a_pulse_width         (a_pulse_width         ),
		.a_pulse_polarity      (a_pulse_polarity      ),
		.a_pulse_valid         (a_pulse_valid         ),
		                    
		.b_pulse_width         (b_pulse_width         ),
		.b_pulse_polarity      (b_pulse_polarity      ),
		.b_pulse_valid         (b_pulse_valid         ),
		
		.clk  (clk  ),
		.rst_n(rst_n)
	);
	
	initial begin
		stage <= 0;
		
		clk <= 0;
		rst_n <= 0;
		
		in_a <= 1;
		in_b <= 0;
		
		#20;
		
		rst_n <= 1;
	end
	
	always #5 clk <= !clk;
	
	always @(posedge(clk)) begin
		if (rst_n == 0) begin
			num_stages      <= $urandom % 20;
			time_increment  <= $urandom % 20;
			stage_increment <= $urandom % 2;
			
			time_counter  <= $urandom % 20;
		end else begin
			if (time_counter == 0) begin
				time_counter <= time_increment;
				
				if (stage_increment == 1) begin
					stage <= stage + 1;
				end else begin
					stage <= stage - 1;
				end
				
				in_a <= pattern[stage][1];
				in_b <= pattern[stage][0];
				
				if (num_stages == 0) begin
					num_stages      <= $urandom % 20;
					time_increment  <= $urandom % 20;
					stage_increment <= $urandom % 2;
				end else begin
					num_stages <= num_stages - 1;
				end
			end else begin
				time_counter <= time_counter - 1;
			end
		end
	end
endmodule
