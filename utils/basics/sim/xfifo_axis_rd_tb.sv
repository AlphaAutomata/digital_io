`timescale 1ns / 1ps

module xfifo_axis_rd_tb();
    localparam AXIS_DATA_WIDTH = 32;

    localparam [31:0] fifo_wren_test_mask         = 32'hFF0A42C0;
    localparam [31:0] dut_m_axis_tready_test_mask = 32'hDEADBEEF;

    reg [4:0] test_mask_idx;

    reg clk;
    reg rst;

    wire                       dut_fifo_rden    ;
    wire [AXIS_DATA_WIDTH-1:0] dut_fifo_do      ;
    wire                       dut_fifo_empty   ;

    wire [AXIS_DATA_WIDTH-1:0] dut_m_axis_tdata ;
    wire                       dut_m_axis_tvalid;
    reg                        dut_m_axis_tready;

    wire                       dut_aclk         ;
    wire                       dut_aresetn      ;

    reg                        fifo_wren       ;
    reg  [AXIS_DATA_WIDTH-1:0] fifo_di         ;
    wire [8:0]                 fifo_wrcount    ;
    wire                       fifo_almostfull ;
    wire                       fifo_full       ;
    wire                       fifo_wrerr      ;

    wire                       fifo_rden       ;
    wire [AXIS_DATA_WIDTH-1:0] fifo_do         ;
    wire [8:0]                 fifo_rdcount    ;
    wire                       fifo_almostempty;
    wire                       fifo_empty      ;
    wire                       fifo_rderr      ;

    wire                       fifo_clk        ;
    wire                       fifo_rst        ;

    assign dut_aclk    = clk;
    assign dut_aresetn = !rst;

    xfifo_axis_rd #(
        .AXIS_DATA_WIDTH(AXIS_DATA_WIDTH) // : integer := 32
    ) dut (
        .fifo_rden    (dut_fifo_rden    ), // : out std_logic;
        .fifo_do      (dut_fifo_do      ), // : in  std_logic_vector(AXIS_DATA_WIDTH-1 downto 0);
        .fifo_empty   (dut_fifo_empty   ), // : in  std_logic;

        .m_axis_tdata (dut_m_axis_tdata ), // : out std_logic_vector(AXIS_DATA_WIDTH-1 downto 0);
        .m_axis_tvalid(dut_m_axis_tvalid), // : out std_logic;
        .m_axis_tready(dut_m_axis_tready), // : in  std_logic;

        .aclk         (dut_aclk         ), // : in std_logic;
        .aresetn      (dut_aresetn      )  // : in std_logic
    );

    assign fifo_rden      = dut_fifo_rden;
    assign dut_fifo_do    = fifo_do;
    assign dut_fifo_empty = fifo_empty;

    assign fifo_clk = clk;
    assign fifo_rst = rst;

    FIFO_SYNC_MACRO #(
        .DEVICE             ("7SERIES"      ), // Target Device: "7SERIES"
        .ALMOST_EMPTY_OFFSET(9'h080         ), // Sets the almost empty threshold
        .ALMOST_FULL_OFFSET (9'h080         ), // Sets almost full threshold
        .DATA_WIDTH         (AXIS_DATA_WIDTH), // Valid values are 1-72 (37-72 only valid when FIFO_SIZE="36Kb")
        .DO_REG             (0              ), // Optional output register (0 or 1)
        .FIFO_SIZE          ("18Kb"         )  // Target BRAM: "18Kb" or "36Kb"
    ) fifo (
        .WREN       (fifo_wren       ), // 1-bit input write enable
        .DI         (fifo_di         ), // Input data, width defined by DATA_WIDTH parameter
        .WRCOUNT    (fifo_wrcount    ), // Output write count, width determined by FIFO depth
        .ALMOSTFULL (fifo_almostfull ), // 1-bit output almost full
        .FULL       (fifo_full       ), // 1-bit output full
        .WRERR      (fifo_wrerr      ), // 1-bit output write error

        .RDEN       (fifo_rden       ), // 1-bit input read enable
        .DO         (fifo_do         ), // Output data, width defined by DATA_WIDTH parameter
        .RDCOUNT    (fifo_rdcount    ), // Output read count, width determined by FIFO depth
        .ALMOSTEMPTY(fifo_almostempty), // 1-bit output almost empty
        .EMPTY      (fifo_empty      ), // 1-bit output empty
        .RDERR      (fifo_rderr      ), // 1-bit output read error

        .CLK        (fifo_clk        ), // 1-bit input clock
        .RST        (fifo_rst        )  // 1-bit input reset
    );

    initial begin
        test_mask_idx <= 0;

        dut_m_axis_tready <= 0;

        fifo_wren <= 0;
        fifo_di   <= 0;

        clk <= 0;
        rst <= 1;

        #200;

        rst <= 0;
    end

    always #5 clk <= !clk;

    always @(posedge(clk)) begin
        if (rst == 0) begin
            test_mask_idx <= test_mask_idx + 1;

            dut_m_axis_tready <= dut_m_axis_tready_test_mask[test_mask_idx];

            fifo_wren <= fifo_wren_test_mask[test_mask_idx];
            fifo_di   <= fifo_di + 1;
        end
    end
endmodule
