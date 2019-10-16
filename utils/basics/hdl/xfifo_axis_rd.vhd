library ieee;
use ieee.std_logic_1164.all;

entity xfifo_axis_rd is
    generic (
        AXIS_DATA_WIDTH : integer := 32
    );
    port (
        fifo_rden  : out std_logic;
        fifo_do    : in  std_logic_vector(AXIS_DATA_WIDTH-1 downto 0);
        fifo_empty : in  std_logic;

        m_axis_tdata  : out std_logic_vector(AXIS_DATA_WIDTH-1 downto 0);
        m_axis_tvalid : out std_logic;
        m_axis_tready : in  std_logic;

        aclk    : in std_logic;
        aresetn : in std_logic
    );
end xfifo_axis_rd;

architecture arch of xfifo_axis_rd is
    signal fifo_do_valid : std_logic;

    signal m_axis_tdata_reg      : std_logic_vector(AXIS_DATA_WIDTH-1 downto 0);
    signal m_axis_tdata_reg_next : std_logic_vector(AXIS_DATA_WIDTH-1 downto 0);

    signal m_axis_tdata_reg_valid      : std_logic;
    signal m_axis_tdata_reg_valid_next : std_logic;
begin
    fifo_rden    <= (not fifo_empty) and (not m_axis_tdata_reg_valid_next);
    m_axis_tdata <=
        m_axis_tdata_reg when m_axis_tdata_reg_valid = '1' else
        fifo_do;
    m_axis_tvalid <= fifo_do_valid or m_axis_tdata_reg_valid;


    process (all) begin
        m_axis_tdata_reg_next       <= m_axis_tdata_reg;
        m_axis_tdata_reg_valid_next <= m_axis_tdata_reg_valid;

        if (fifo_do_valid = '1') then
            m_axis_tdata_reg_next <= fifo_do;
        end if;

        if (m_axis_tready = '1' and fifo_do_valid = '0') then
            m_axis_tdata_reg_valid_next <= '0';
        end if;
        if (m_axis_tready = '0' and fifo_do_valid = '1') then
            m_axis_tdata_reg_valid_next <= '1';
        end if;
    end process;

    process (aclk) begin
        if (rising_edge(aclk)) then
            if (aresetn = '0') then
                fifo_do_valid          <= '0';
                m_axis_tdata_reg       <= (others => '0');
                m_axis_tdata_reg_valid <= '0';
            else
                fifo_do_valid          <= fifo_rden;
                m_axis_tdata_reg       <= m_axis_tdata_reg_next;
                m_axis_tdata_reg_valid <= m_axis_tdata_reg_valid_next;
            end if;
        end if;
    end process;
end arch;
