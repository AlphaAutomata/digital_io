`timescale 1ns / 1ps

module pwm_cell_tb();
	localparam COUNTER_WIDTH       = 32;
	localparam ITERATIONS_PER_CASE = 3;
	
	localparam [15:0][2:0][COUNTER_WIDTH-1:0] test_cases = {
		{ 1000,  500,     0 },
		{ 1000,  500,    10 },
		{ 1000,  500,   -10 },
		{ 1000,    0,     0 },
		{ 1000,    0,    10 },
		{ 1000,    0,   -10 },
		{ 1000, 1000,     0 },
		{ 1000, 1000,    10 },
		{ 1000, 1000,   -10 },
		{ 2000,  750,     0 },
		{ 2000,  750,  1000 },
		{ 2000,  750, -1000 },
		{  750,  500,     0 },
		{  750,  500,     0 },
		{  750,  500,    50 },
		{  750,  500,   -50 }
	};
	
	integer iteration;
	integer test_case;
	
	wire pwm;
	
	reg  [COUNTER_WIDTH-1:0] counter             ;
	wire [COUNTER_WIDTH-1:0] counter_plus_period ;
	wire [COUNTER_WIDTH-1:0] counter_minus_period;
	
	reg                     count_dir;
	reg                     polarity ;
	reg [COUNTER_WIDTH-1:0] period   ;
	reg [COUNTER_WIDTH-1:0] duty     ;
	reg [COUNTER_WIDTH-1:0] phase    ;
	
	pwm_cell #(
		.COUNTER_WIDTH(COUNTER_WIDTH)
	) dut (
		.pwm(pwm),
		
		.counter             (counter             ),
		.counter_plus_period (counter_plus_period ),
		.counter_minus_period(counter_minus_period),
		
		.count_dir(count_dir),
		.polarity (polarity ),
		.period   (period   ),
		.duty     (duty     ),
		.phase    (phase    )
	);
	
	initial begin
		iteration <= ITERATIONS_PER_CASE;
		test_case <= 1;
		
		counter   <= 0;
		
		count_dir <= 1;
		polarity  <= $random;
		period    <= test_cases[0][2];
		duty      <= test_cases[0][1];
		phase     <= test_cases[0][0];
	end
	
	assign counter_plus_period =  counter + period;
	assign counter_minus_period = counter - period;
	
	always #10 begin
		if (count_dir == 1) begin
			if (counter >= period-1) begin
				if (iteration == 0) begin
					iteration <= ITERATIONS_PER_CASE;
					if (test_case == 15) begin
						test_case <= 0;
					end else begin
						test_case <= test_case + 1;
					end
				
					counter   <= 0;
				
					count_dir <= $random;
					polarity  <= $random;
					period    <= test_cases[test_case][2];
					duty      <= test_cases[test_case][1];
					phase     <= test_cases[test_case][0];
				end else begin
					iteration <= iteration - 1;
				end
				
				counter <= 0;
			end else begin
				counter <= counter + 1;
			end
		end else begin
			if (counter <= 0) begin
				if (iteration == 0) begin
					iteration <= ITERATIONS_PER_CASE;
					if (test_case == 15) begin
						test_case <= 0;
					end else begin
						test_case <= test_case + 1;
					end
				
					counter   <= 0;
				
					count_dir <= $random;
					polarity  <= $random;
					period    <= test_cases[test_case][2];
					duty      <= test_cases[test_case][1];
					phase     <= test_cases[test_case][0];
				end else begin
					iteration <= iteration - 1;
				end
				
				counter <= period - 1;
			end else begin
				counter <= counter - 1;
			end
		end
	end
endmodule
