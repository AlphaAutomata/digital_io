`timescale 1ns / 1ps

module pw_bit_tb();
    localparam COUNTER_WIDTH        = 8;
    localparam DATA_AXIS_DATA_WIDTH = 8;
    localparam CFG_AXIS_DATA_WIDTH  = COUNTER_WIDTH * 3;

    wire txd; // : out std_logic;

    reg  [DATA_AXIS_DATA_WIDTH-1:0] data_s_axis_tdata ; // : in  std_logic_vector(DATA_AXIS_DATA_WIDTH-1 downto 0);
    reg                             data_s_axis_tlast ; // : in  std_logic;
    reg                             data_s_axis_tvalid; // : in  std_logic;
    wire                            data_s_axis_tready; // : out std_logic;

    reg  [CFG_AXIS_DATA_WIDTH-1:0] cfg_s_axis_tdata ; // : in  std_logic_vector(CFG_AXIS_DATA_WIDTH-1 downto 0);
    reg                            cfg_s_axis_tvalid; // : in  std_logic;
    wire                           cfg_s_axis_tready; // : out std_logic;

    reg  aclk   ; // : in std_logic;
    reg  aresetn; // : in std_logic

    pw_bit_cell #(
        .COUNTER_WIDTH(COUNTER_WIDTH), // : integer := 32;

        .DATA_AXIS_DATA_WIDTH(DATA_AXIS_DATA_WIDTH), // : integer := 8;
        .CFG_AXIS_DATA_WIDTH (CFG_AXIS_DATA_WIDTH )  // : integer := COUNTER_WIDTH * 2
    ) dut (
        .txd(txd), // : out std_logic;

        .data_s_axis_tdata (data_s_axis_tdata ), // : in  std_logic_vector(DATA_AXIS_DATA_WIDTH-1 downto 0);
        .data_s_axis_tlast (data_s_axis_tlast ), // : in  std_logic;
        .data_s_axis_tvalid(data_s_axis_tvalid), // : in  std_logic;
        .data_s_axis_tready(data_s_axis_tready), // : out std_logic;

        .cfg_s_axis_tdata (cfg_s_axis_tdata ), // : in  std_logic_vector(CFG_AXIS_DATA_WIDTH-1 downto 0);
        .cfg_s_axis_tvalid(cfg_s_axis_tvalid), // : in  std_logic;
        .cfg_s_axis_tready(cfg_s_axis_tready), // : out std_logic;

        .aclk   (aclk   ), // : in std_logic;
        .aresetn(aresetn)  // : in std_logic
    );

    initial begin
        data_s_axis_tdata  <= 0; // : in  std_logic_vector(DATA_AXIS_DATA_WIDTH-1 downto 0);
        data_s_axis_tlast  <= 0; // : in  std_logic;
        data_s_axis_tvalid <= 0; // : in  std_logic;

        cfg_s_axis_tdata  <= 0; // : in  std_logic_vector(CFG_AXIS_DATA_WIDTH-1 downto 0);
        cfg_s_axis_tvalid <= 0; // : in  std_logic;

        aclk    <= 0; // : in std_logic;
        aresetn <= 0; // : in std_logic

        #20;

        aresetn <= 1;
    end

    always #5 aclk <= !aclk;

    always @(posedge(aclk)) begin
        if (aresetn == 1'b0) begin
            data_s_axis_tdata  <= 8'b11001100;
            data_s_axis_tlast  <= 1'b1;
            data_s_axis_tvalid <= 1'b1;
    
            cfg_s_axis_tdata  <= { 8'd100, 8'd75, 8'd25 };
            cfg_s_axis_tvalid <= 1'b1;
        end else begin
            if (data_s_axis_tready == 1'b1) begin
                data_s_axis_tvalid <= 1'b0;
            end
            if (cfg_s_axis_tready == 1'b1) begin
                cfg_s_axis_tvalid <= 1'b0;
            end
        end
    end
endmodule
