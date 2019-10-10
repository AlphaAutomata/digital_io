library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity pw_bit_cell is
    generic (
        COUNTER_WIDTH : integer := 32;

        DATA_AXIS_DATA_WIDTH : integer := 8;
        CFG_AXIS_DATA_WIDTH  : integer := 96
    );
    port (
        txd : out std_logic;

        data_s_axis_tdata  : in  std_logic_vector(DATA_AXIS_DATA_WIDTH-1 downto 0);
        data_s_axis_tlast  : in  std_logic;
        data_s_axis_tvalid : in  std_logic;
        data_s_axis_tready : out std_logic;

        cfg_s_axis_tdata  : in  std_logic_vector(CFG_AXIS_DATA_WIDTH-1 downto 0);
        cfg_s_axis_tvalid : in  std_logic;
        cfg_s_axis_tready : out std_logic;

        aclk    : in std_logic;
        aresetn : in std_logic
    );
end pw_bit_cell;

architecture arch of pw_bit_cell is
    type state is (idle, tx_bit_high, tx_bit_low, tx_stop);

    signal tx_state      : state;
    signal tx_state_next : state;

    signal tx_buffer      : std_logic_vector(DATA_AXIS_DATA_WIDTH-1 downto 0);
    signal tx_buffer_next : std_logic_vector(DATA_AXIS_DATA_WIDTH-1 downto 0);

    signal data_period_bits       : std_logic_vector(COUNTER_WIDTH-1 downto 0);
    signal data_high_time_hi_bits : std_logic_vector(COUNTER_WIDTH-1 downto 0);
    signal data_high_time_lo_bits : std_logic_vector(COUNTER_WIDTH-1 downto 0);

    signal period      : std_logic_vector(COUNTER_WIDTH-1 downto 0);
    signal period_next : std_logic_vector(COUNTER_WIDTH-1 downto 0);

    signal high_time_hi      : std_logic_vector(COUNTER_WIDTH-1 downto 0);
    signal high_time_hi_next : std_logic_vector(COUNTER_WIDTH-1 downto 0);

    signal high_time_lo      : std_logic_vector(COUNTER_WIDTH-1 downto 0);
    signal high_time_lo_next : std_logic_vector(COUNTER_WIDTH-1 downto 0);

    signal bit_time_cnt      : std_logic_vector(COUNTER_WIDTH-1 downto 0);
    signal bit_time_cnt_next : std_logic_vector(COUNTER_WIDTH-1 downto 0);

    constant BIT_CNT_WIDTH : integer := integer(ceil(log2(real(DATA_AXIS_DATA_WIDTH))));

    signal bit_cnt      : std_logic_vector(BIT_CNT_WIDTH-1 downto 0);
    signal bit_cnt_next : std_logic_vector(BIT_CNT_WIDTH-1 downto 0);

    signal last      : std_logic;
    signal last_next : std_logic;
begin
    data_period_bits       <= cfg_s_axis_tdata(3*COUNTER_WIDTH-1 downto 2*COUNTER_WIDTH);
    data_high_time_hi_bits <= cfg_s_axis_tdata(2*COUNTER_WIDTH-1 downto COUNTER_WIDTH);
    data_high_time_lo_bits <= cfg_s_axis_tdata(COUNTER_WIDTH-1 downto 0);

    process (
        data_s_axis_tdata ,
        data_s_axis_tlast ,
        data_s_axis_tvalid,
        cfg_s_axis_tdata  ,
        cfg_s_axis_tvalid ,
        tx_state    ,
        tx_buffer   ,
        period      ,
        high_time_hi,
        high_time_lo,
        bit_time_cnt,
        bit_cnt     ,
        last        ,
        data_period_bits      ,
        data_high_time_hi_bits,
        data_high_time_lo_bits
    ) begin
        tx_state_next     <= tx_state    ;
        tx_buffer_next    <= tx_buffer   ;
        period_next       <= period      ;
        high_time_hi_next <= high_time_hi;
        high_time_lo_next <= high_time_lo;
        bit_time_cnt_next <= bit_time_cnt;
        bit_cnt_next      <= bit_cnt     ;
        last_next         <= last        ;

        case (tx_state) is
            when idle =>
                txd                <= '0';
                data_s_axis_tready <= '1';
                cfg_s_axis_tready  <= '1';

                if (data_s_axis_tvalid = '1') then
                    tx_state_next  <= tx_bit_high;
                    tx_buffer_next <= data_s_axis_tdata;
                    if (cfg_s_axis_tvalid = '1') then
                        bit_time_cnt_next <= data_period_bits;
                    else
                        bit_time_cnt_next <= period;
                    end if;
                    bit_cnt_next <= (others => '1');
                    last_next    <= data_s_axis_tlast;
                end if;
                if (cfg_s_axis_tvalid = '1') then
                    period_next       <= data_period_bits;
                    high_time_hi_next <= data_high_time_hi_bits;
                    high_time_lo_next <= data_high_time_lo_bits;
                end if;

            when tx_bit_high =>
                txd                <= '1';
                data_s_axis_tready <= '0';
                cfg_s_axis_tready  <= '0';

                if (tx_buffer(to_integer(unsigned(bit_cnt))) = '1') then
                    if (unsigned(bit_time_cnt) < unsigned(period)-unsigned(high_time_hi)) then
                        tx_state_next <= tx_bit_low;
                    end if;
                else
                    if (unsigned(bit_time_cnt) < unsigned(period)-unsigned(high_time_lo)) then
                        tx_state_next <= tx_bit_low;
                    end if;
                end if;
                bit_time_cnt_next <= std_logic_vector(unsigned(bit_time_cnt) - 1);

            when tx_bit_low =>
                txd                <= '0';
                data_s_axis_tready <= '0';
                cfg_s_axis_tready  <= '0';

                if (unsigned(bit_time_cnt) = 0) then
                    if (unsigned(bit_cnt) = 0) then
                        if (last = '1') then
                            tx_state_next <= tx_stop;
                        else
                            tx_state_next <= idle;
                        end if;
                    else
                        tx_state_next     <= tx_bit_high;
                        bit_time_cnt_next <= period;
                        bit_cnt_next      <= std_logic_vector(unsigned(bit_cnt) - 1);
                    end if;
                else
                    bit_time_cnt_next <= std_logic_vector(unsigned(bit_time_cnt) - 1);
                end if;

            when tx_stop =>
                txd                <= '0';
                data_s_axis_tready <= '0';
                cfg_s_axis_tready  <= '0';

                if (unsigned(bit_time_cnt) = 0) then
                    tx_state_next <= idle;
                end if;
                bit_time_cnt_next <= std_logic_vector(unsigned(bit_time_cnt) - 1);

        end case;
    end process;

    process (aclk) begin
        if (rising_edge(aclk)) then
            if (aresetn = '0') then
                tx_state     <= idle;
                tx_buffer    <= (others => '0');
                period       <= (others => '0');
                high_time_hi <= (others => '0');
                high_time_lo <= (others => '0');
                bit_time_cnt <= (others => '0');
                bit_cnt      <= (others => '0');
                last         <= '0';
            else
                tx_state     <= tx_state_next    ;
                tx_buffer    <= tx_buffer_next   ;
                period       <= period_next      ;
                high_time_hi <= high_time_hi_next;
                high_time_lo <= high_time_lo_next;
                bit_time_cnt <= bit_time_cnt_next;
                bit_cnt      <= bit_cnt_next     ;
                last         <= last_next        ;
            end if;
        end if;
    end process;
end arch;
