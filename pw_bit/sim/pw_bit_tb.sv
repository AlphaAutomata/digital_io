`timescale 1ns / 1ps

module pw_bit_tb();
    localparam COUNTER_WIDTH   = 8;
    localparam AXIS_DATA_WIDTH = 8;

    wire txd; // : out std_logic;

    reg  [AXIS_DATA_WIDTH-1:0]   s_axis_tdata ; // : in  std_logic_vector(AXIS_DATA_WIDTH-1 downto 0);
    reg  [AXIS_DATA_WIDTH/8-1:0] s_axis_tstrb ; // : in  std_logic_vector(AXIS_DATA_WIDTH/8-1 downto 0);
    reg                          s_axis_tlast ; // : in  std_logic;
    reg                          s_axis_tvalid; // : in  std_logic;
    wire                         s_axis_tready; // : out std_logic;

    reg [COUNTER_WIDTH-1:0] period ; // : in  std_logic_vector(COUNTER_WIDTH-1 downto 0);
    reg [COUNTER_WIDTH-1:0] duty_hi; // : in  std_logic_vector(COUNTER_WIDTH-1 downto 0);
    reg [COUNTER_WIDTH-1:0] duty_lo; // : in  std_logic_vector(COUNTER_WIDTH-1 downto 0);

    reg aclk   ; // : in std_logic;
    reg aresetn; // : in std_logic

    pw_bit_cell #(
        .COUNTER_WIDTH  (COUNTER_WIDTH)  , // : integer := 32;
        .AXIS_DATA_WIDTH(AXIS_DATA_WIDTH)  // : integer := 8;
    ) dut (
        .txd(txd), // : out std_logic;

        .s_axis_tdata (s_axis_tdata ), // : in  std_logic_vector(AXIS_DATA_WIDTH-1 downto 0);
        .s_axis_tstrb (s_axis_tstrb ), // : in  std_logic_vector(AXIS_DATA_WIDTH/8-1 downto 0);
        .s_axis_tlast (s_axis_tlast ), // : in  std_logic;
        .s_axis_tvalid(s_axis_tvalid), // : in  std_logic;
        .s_axis_tready(s_axis_tready), // : out std_logic;

        .period (period ), // : in std_logic_vector(COUNTER_WIDTH-1 downto 0);
        .duty_hi(duty_hi), // : in std_logic_vector(COUNTER_WIDTH-1 downto 0);
        .duty_lo(duty_lo), // : in std_logic_vector(COUNTER_WIDTH-1 downto 0);

        .aclk   (aclk   ), // : in std_logic;
        .aresetn(aresetn)  // : in std_logic
    );

    initial begin
        s_axis_tdata  <= 0; // : in  std_logic_vector(AXIS_DATA_WIDTH-1 downto 0);
        s_axis_tstrb  <= -1; // : in  std_logic_vector(AXIS_DATA_WIDTH/8-1 downto 0);
        s_axis_tlast  <= 0; // : in  std_logic;
        s_axis_tvalid <= 0; // : in  std_logic;

        period  <= 0; // : in  std_logic_vector(COUNTER_WIDTH-1 downto 0);
        duty_hi <= 0; // : in  std_logic_vector(COUNTER_WIDTH-1 downto 0);
        duty_lo <= 0; // : in  std_logic_vector(COUNTER_WIDTH-1 downto 0);

        aclk    <= 0; // : in std_logic;
        aresetn <= 0; // : in std_logic

        #20;

        aresetn <= 1;
    end

    always #5 aclk <= !aclk;

    always @(posedge(aclk)) begin
        if (aresetn == 1'b0) begin
            s_axis_tdata  <= 8'b11001100;
            s_axis_tlast  <= 1'b1;
            s_axis_tvalid <= 1'b1;
    
            period  <= 8'd100;
            duty_hi <= 8'd75;
            duty_lo <= 8'd25;
        end else begin
            if (s_axis_tready == 1'b1) begin
                s_axis_tvalid <= 1'b0;
            end
        end
    end
endmodule
