`timescale 1ns / 1ps

module prio_enc_tb();
    localparam CODE_WIDTH_0 = 1;
    localparam CODE_WIDTH_1 = 2;
    localparam CODE_WIDTH_2 = 3;

    reg  [2**CODE_WIDTH_0-1:0] dut0_data;
    wire [CODE_WIDTH_0-1:0]    dut0_code;

    reg  [2**CODE_WIDTH_1-1:0] dut1_data;
    wire [CODE_WIDTH_1-1:0]    dut1_code;

    reg  [2**CODE_WIDTH_2-1:0] dut2_data;
    wire [CODE_WIDTH_2-1:0]    dut2_code;

    prio_enc #(
        .CODE_WIDTH(CODE_WIDTH_0)
    ) dut0 (
        .data(dut0_data), // : in  std_logic_vector(2**CODE_WIDTH-1 downto 0);
        .code(dut0_code)  // : out std_logic_vector(CODE_WIDTH-1 downto 0)
    );

    prio_enc #(
        .CODE_WIDTH(CODE_WIDTH_1)
    ) dut1 (
        .data(dut1_data), // : in  std_logic_vector(2**CODE_WIDTH-1 downto 0);
        .code(dut1_code)  // : out std_logic_vector(CODE_WIDTH-1 downto 0)
    );

    prio_enc #(
        .CODE_WIDTH(CODE_WIDTH_2)
    ) dut2 (
        .data(dut2_data), // : in  std_logic_vector(2**CODE_WIDTH-1 downto 0);
        .code(dut2_code)  // : out std_logic_vector(CODE_WIDTH-1 downto 0)
    );

    initial begin
        dut0_data <= 0;
        dut1_data <= 0;
        dut2_data <= 0;
    end

    always #5 begin
        dut0_data <= dut0_data + 1;
        dut1_data <= dut1_data + 1;
        dut2_data <= dut2_data + 1;
    end
endmodule
