library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
use ieee.std_logic_misc.all;

entity prio_enc is
    generic (
        CODE_WIDTH : integer := 6
    );
    port (
        data : in  std_logic_vector(2**CODE_WIDTH-1 downto 0);
        code : out std_logic_vector(CODE_WIDTH-1 downto 0)
    );
end prio_enc;

architecture arch of prio_enc is
    constant FULL_WIDTH : integer := 2**CODE_WIDTH;
    constant HALF_WIDTH : integer := 2**(CODE_WIDTH-1);

    signal data_high : std_logic_vector(HALF_WIDTH-1 downto 0);
    signal data_low  : std_logic_vector(HALF_WIDTH-1 downto 0);

    signal flat_vector : std_logic_vector(2*FULL_WIDTH-1 downto 0);
begin
    flat_vector(2*FULL_WIDTH-1 downto FULL_WIDTH) <= data;

    GEN_REDUCTION : for i in 0 to CODE_WIDTH-1 generate
        constant RESULT_WIDTH : integer := 2**i;

        signal high : std_logic_vector(RESULT_WIDTH-1 downto 0);
        signal low  : std_logic_vector(RESULT_WIDTH-1 downto 0);
    begin
        high <= flat_vector(4*RESULT_WIDTH-1 downto 3*RESULT_WIDTH);
        low  <= flat_vector(3*RESULT_WIDTH-1 downto 2*RESULT_WIDTH);

        flat_vector(2*RESULT_WIDTH-1 downto RESULT_WIDTH) <=
            high when or_reduce(high) = '1' else
            low;

        code(i) <= '1' when or_reduce(high) = '1' else '0';
    end generate GEN_REDUCTION;
end arch;
