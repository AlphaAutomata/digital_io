library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity pw_bit_cell is
    generic (
        COUNTER_WIDTH   : integer := 32;
        AXIS_DATA_WIDTH : integer := 8
    );
    port (
        txd : out std_logic;

        s_axis_tdata  : in  std_logic_vector(AXIS_DATA_WIDTH-1 downto 0);
        s_axis_tstrb  : in  std_logic_vector(AXIS_DATA_WIDTH/8-1 downto 0);
        s_axis_tlast  : in  std_logic;
        s_axis_tvalid : in  std_logic;
        s_axis_tready : out std_logic;

        period  : in std_logic_vector(COUNTER_WIDTH-1 downto 0);
        duty_hi : in std_logic_vector(COUNTER_WIDTH-1 downto 0);
        duty_lo : in std_logic_vector(COUNTER_WIDTH-1 downto 0);

        aclk    : in std_logic;
        aresetn : in std_logic
    );
end pw_bit_cell;

architecture arch of pw_bit_cell is
    type state is (idle, tx_bit_high, tx_bit_low, tx_stop);

    signal tx_state      : state;
    signal tx_state_next : state;

    signal tx_buffer      : std_logic_vector(AXIS_DATA_WIDTH-1 downto 0);
    signal tx_buffer_next : std_logic_vector(AXIS_DATA_WIDTH-1 downto 0);

    signal period_reg      : std_logic_vector(COUNTER_WIDTH-1 downto 0);
    signal period_reg_next : std_logic_vector(COUNTER_WIDTH-1 downto 0);

    signal high_time_hi      : std_logic_vector(COUNTER_WIDTH-1 downto 0);
    signal high_time_hi_next : std_logic_vector(COUNTER_WIDTH-1 downto 0);

    signal high_time_lo      : std_logic_vector(COUNTER_WIDTH-1 downto 0);
    signal high_time_lo_next : std_logic_vector(COUNTER_WIDTH-1 downto 0);

    signal bit_time_cnt      : std_logic_vector(COUNTER_WIDTH-1 downto 0);
    signal bit_time_cnt_next : std_logic_vector(COUNTER_WIDTH-1 downto 0);

    constant BIT_CNT_WIDTH : integer := integer(ceil(log2(real(AXIS_DATA_WIDTH))));

    signal bit_cnt_from_tstrb : std_logic_vector(BIT_CNT_WIDTH-1 downto 0);

    signal bit_cnt      : std_logic_vector(BIT_CNT_WIDTH-1 downto 0);
    signal bit_cnt_next : std_logic_vector(BIT_CNT_WIDTH-1 downto 0);

    signal last      : std_logic;
    signal last_next : std_logic;

    component prio_enc is
        generic (
            CODE_WIDTH : integer := 6
        );
        port (
            data : in  std_logic_vector(2**CODE_WIDTH-1 downto 0);
            code : out std_logic_vector(CODE_WIDTH-1 downto 0)
        );
    end component;

    signal bit_cnt_encoder_data : std_logic_vector(2**BIT_CNT_WIDTH-1 downto 0);
    signal bit_cnt_encoder_code : std_logic_vector(BIT_CNT_WIDTH-1 downto 0);
begin
    GEN_ENC_DATA : for i in 0 to AXIS_DATA_WIDTH/8-1 generate
    begin
        GEN_ENC_BYTE : for j in 0 to 7 generate
        begin
            bit_cnt_encoder_data(8*i+j) <= s_axis_tstrb(i);
        end generate GEN_ENC_BYTE;
    end generate GEN_ENC_DATA;

    bit_cnt_encoder : prio_enc
    generic map (
        CODE_WIDTH => BIT_CNT_WIDTH
    ) port map (
        data => bit_cnt_encoder_data,
        code => bit_cnt_encoder_code
    );

    bit_cnt_from_tstrb <= bit_cnt_encoder_code;

    process (all) begin
        tx_state_next     <= tx_state    ;
        tx_buffer_next    <= tx_buffer   ;
        period_reg_next   <= period_reg  ;
        high_time_hi_next <= high_time_hi;
        high_time_lo_next <= high_time_lo;
        bit_time_cnt_next <= bit_time_cnt;
        bit_cnt_next      <= bit_cnt     ;
        last_next         <= last        ;

        case (tx_state) is
            when idle =>
                txd           <= '0';
                s_axis_tready <= '1';

                if (s_axis_tvalid = '1') then
                    tx_state_next     <= tx_bit_high;
                    tx_buffer_next    <= s_axis_tdata;
                    bit_time_cnt_next <= std_logic_vector(unsigned(period)-1);
                    bit_cnt_next      <= bit_cnt_from_tstrb;
                    last_next         <= s_axis_tlast;
                end if;
                period_reg_next   <= std_logic_vector(unsigned(period)-1) ;
                high_time_hi_next <= duty_hi;
                high_time_lo_next <= duty_lo;

            when tx_bit_high =>
                txd           <= '1';
                s_axis_tready <= '0';

                if (tx_buffer(to_integer(unsigned(bit_cnt))) = '1') then
                    if (unsigned(bit_time_cnt) <= unsigned(period_reg)-unsigned(high_time_hi)+1) then
                        tx_state_next <= tx_bit_low;
                    end if;
                else
                    if (unsigned(bit_time_cnt) <= unsigned(period_reg)-unsigned(high_time_lo)+1) then
                        tx_state_next <= tx_bit_low;
                    end if;
                end if;
                bit_time_cnt_next <= std_logic_vector(unsigned(bit_time_cnt) - 1);

            when tx_bit_low =>
                txd           <= '0';
                s_axis_tready <= '0';

                if (unsigned(bit_time_cnt) = 0) then
                    if (unsigned(bit_cnt) = 0) then
                        if (last = '1') then
                            tx_state_next <= tx_stop;
                        else
                            tx_state_next <= idle;
                        end if;
                    else
                        tx_state_next     <= tx_bit_high;
                        bit_time_cnt_next <= period_reg;
                        bit_cnt_next      <= std_logic_vector(unsigned(bit_cnt) - 1);
                    end if;
                else
                    bit_time_cnt_next <= std_logic_vector(unsigned(bit_time_cnt) - 1);
                end if;

            when tx_stop =>
                txd           <= '0';
                s_axis_tready <= '0';

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
                period_reg   <= (others => '0');
                high_time_hi <= (others => '0');
                high_time_lo <= (others => '0');
                bit_time_cnt <= (others => '0');
                bit_cnt      <= (others => '0');
                last         <= '0';
            else
                tx_state     <= tx_state_next    ;
                tx_buffer    <= tx_buffer_next   ;
                period_reg   <= period_reg_next  ;
                high_time_hi <= high_time_hi_next;
                high_time_lo <= high_time_lo_next;
                bit_time_cnt <= bit_time_cnt_next;
                bit_cnt      <= bit_cnt_next     ;
                last         <= last_next        ;
            end if;
        end if;
    end process;
end arch;
