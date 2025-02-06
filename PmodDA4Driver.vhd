------------------------------------------------------------------------
-- Engineer:    Dalmasso Loic
-- Create Date: 05/02/2025
-- Module Name: PmodDA4Driver
-- Description:
--      Pmod DA4 Driver for the 8 Channels 12-bit Digital-to-Analog Converter AD5628. The communication with the DAC uses the SPI protocol (Write only)
--      User can specify the SPI Serial Clock Frequency (up to 50 MHz).
--
-- Usage:
--		The o_ready signal (set to '1') indicates the PmodDA4Driver is ready to receive new data (command, address and digital value).
--		Once data are set, the i_enable signal can be triggered (set to '1') to begin transmission.
--		The o_ready signal is set to '0' to acknowledge the receipt and the application of the new data.
--		When the transmission is complete, the o_ready is set to '1' and the PmodDA4Driver is ready for new transmission.
--
--      Commands
--      | C3 | C3 | C3 | C3 | Description
--      |  0 |  0 |  0 |  0 | Write to Input Register n
--      |  0 |  0 |  0 |  1 | Update DAC Register n
--      |  0 |  0 |  1 |  0 | Write to Input Register n, update all (software /LDAC)
--      |  0 |  0 |  1 |  1 | Write to and update DAC Channel n
--      |  0 |  1 |  0 |  0 | Power down/power up DAC
--      |  0 |  1 |  0 |  1 | Load clear code register
--      |  0 |  1 |  1 |  0 | Load /LDAC register
--      |  0 |  1 |  1 |  1 | Reset (power-on reset)
--      |  1 |  0 |  0 |  0 | Set up internal REF register
--      |  - |  - |  - |  - | Reserved
--
--      Address
--      | A3 | A2 | A1 | A0 | Description
--      |  0 |  0 |  0 |  0 | DAC Channel A
--      |  0 |  0 |  0 |  1 | DAC Channel B
--      |  0 |  0 |  1 |  0 | DAC Channel C
--      |  0 |  0 |  1 |  1 | DAC Channel D
--      |  0 |  1 |  0 |  0 | DAC Channel E
--      |  0 |  1 |  0 |  1 | DAC Channel F
--      |  0 |  1 |  1 |  0 | DAC Channel G
--      |  0 |  1 |  1 |  1 | DAC Channel H
--      |  1 |  1 |  1 |  1 | DAC All Channels
--
-- Generics
--		sys_clock: System Input Clock Frequency (Hz)
--      spi_clock: SPI Serial Clock Frequency (up to 50 MHz)
-- Ports
--		Input 	-	i_sys_clock: System Input Clock
--		Input 	-	i_enable: Module Enable ('0': Disable, '1': Enable)
--		Input 	-	i_command: DAC Command (4 bits)
--		Input 	-	i_addr: DAC Address Register (4 bits)
--		Input 	-	i_digital_value: DAC Value (12 bits)
--		Output 	-	o_ready: Ready to convert Next Digital Value ('0': NOT Ready, '1': Ready)
--		Output 	-	o_sclk: SPI Serial Clock
--		Output 	-	o_mosi: SPI Master Output Slave Input Data line
--		Output 	-	o_ss: SPI Slave Select Line ('0': Enable, '1': Disable)
------------------------------------------------------------------------

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY PmodDA4Driver is

GENERIC(
	sys_clock: INTEGER := 100_000_000;
	spi_clock: INTEGER range 1 to 50_000_000 := 1_000_000
);

PORT(
	i_sys_clock: IN STD_LOGIC;
    i_enable: IN STD_LOGIC;
    i_command: IN UNSIGNED(3 downto 0);
    i_addr: IN UNSIGNED(3 downto 0);
	i_digital_value: IN UNSIGNED(11 downto 0);
    o_ready: OUT STD_LOGIC;
	o_sclk: OUT STD_LOGIC;
    o_mosi: OUT STD_LOGIC;
	o_ss: OUT STD_LOGIC
);

END PmodDA4Driver;

ARCHITECTURE Behavioral of PmodDA4Driver is

------------------------------------------------------------------------
-- Constant Declarations
------------------------------------------------------------------------
-- AD5628 Don't Care Bit
constant AD5628_DONT_CARE_BIT: STD_LOGIC := '0';

-- SPI Clock Dividers
constant CLOCK_DIV: INTEGER := sys_clock / spi_clock;
constant CLOCK_DIV_X2: INTEGER := CLOCK_DIV /2;

-- SPI SCLK IDLE Bit
constant SCLK_IDLE_BIT: STD_LOGIC := '1';

-- SPI MOSI IDLE Bit
constant MOSI_IDLE_BIT: STD_LOGIC := '0';

-- SPI Disable Slave Select Line
constant DISABLE_SS_LINE: STD_LOGIC := '1';

------------------------------------------------------------------------
-- Signal Declarations
------------------------------------------------------------------------
-- Pmod DA4 Input Registers
signal enable_reg: STD_LOGIC := '0';
signal command_reg: UNSIGNED(3 downto 0) := (others => '0');
signal addr_reg: UNSIGNED(3 downto 0) := (others => '0');
signal digital_value_reg: UNSIGNED(11 downto 0) := (others => '0');

-- SPI Master States
TYPE spiState is (IDLE, LOAD_INPUTS, START_TX, BYTES_TX, WAITING);
signal state: spiState := IDLE;
signal next_state: spiState;

-- SPI Clock Divider
signal spi_clock_divider: INTEGER range 0 to CLOCK_DIV-1 := 0;
signal spi_clock_rising: STD_LOGIC := '0';
signal spi_clock_falling: STD_LOGIC := '0';

-- SPI Transmission Bit Counter (31 bits)
signal bit_counter: UNSIGNED(4 downto 0) := (others => '0');
signal bit_counter_end: STD_LOGIC := '0';

-- SPI SCLK
signal sclk_out: STD_LOGIC := '0';

-- SPI MOSI Register
signal mosi_reg: UNSIGNED(31 downto 0) := (others => '0');

------------------------------------------------------------------------
-- Module Implementation
------------------------------------------------------------------------
begin

	------------------------------
	-- Pmod DA4 Input Registers --
	------------------------------
	process(i_sys_clock)
	begin

		if rising_edge(i_sys_clock) then

            -- Load Inputs
            if (state = IDLE) then
				enable_reg <= i_enable;
                command_reg <= i_command;
                addr_reg <= i_addr;
                digital_value_reg <= i_digital_value;
            end if;

        end if;
    end process;

	-----------------------
	-- SPI Clock Divider --
	-----------------------
	process(i_sys_clock)
	begin
		if rising_edge(i_sys_clock) then

			-- Reset SPI Clock Divider
			if (enable_reg = '0') or (spi_clock_divider = CLOCK_DIV-1) then
				spi_clock_divider <= 0;

			-- Increment SPI Clock Divider
			else
                spi_clock_divider <= spi_clock_divider +1;
			end if;
		end if;
	end process;

	---------------------
	-- SPI Clock Edges --
	---------------------
	process(i_sys_clock)
	begin
		if rising_edge(i_sys_clock) then

			-- SPI Clock Rising Edge
			if (spi_clock_divider = CLOCK_DIV-1) then
				spi_clock_rising <= '1';
			else
				spi_clock_rising <= '0';
			end if;

			-- SPI Clock Falling Edge
			if (spi_clock_divider = CLOCK_DIV_X2-1) then
				spi_clock_falling <= '1';
			else
				spi_clock_falling <= '0';
			end if;

		end if;
	end process;

	-----------------------
	-- SPI State Machine --
	-----------------------
    -- SPI State
	process(i_sys_clock)
	begin
		if rising_edge(i_sys_clock) then

			-- Next State (When SPI Clock Rising Edge)
			if (spi_clock_rising = '1') then
				state <= next_state;
			end if;
			
		end if;
	end process;

	-- SPI Next State
	process(state, enable_reg, bit_counter_end)
	begin
		case state is
			when IDLE =>    if (enable_reg = '1') then
                                next_state <= START_TX;
                            else
                                next_state <= IDLE;
							end if;

            -- Start TX
            when START_TX => next_state <= BYTES_TX;

			-- Bytes TX Cycle
			when BYTES_TX =>
							-- End of Bytes TX Cycle
							if (bit_counter_end = '1') then
                                next_state <= WAITING;
							else
								next_state <= BYTES_TX;
							end if;

            -- Waiting Time for Next Transmission
			when others => next_state <= IDLE;
		end case;
	end process;

	---------------------
	-- SPI Bit Counter --
	---------------------
	process(i_sys_clock)
	begin
		if rising_edge(i_sys_clock) then

			-- SPI Clock Rising Edge
			if (spi_clock_rising = '1') then

                -- Increment Bit Counter
                if (state = BYTES_TX) then
                    bit_counter <= bit_counter +1;
                
                -- Reset Bit Counter
				else
					bit_counter <= (others => '0');
				end if;
			end if;
		end if;
    end process;

	-- Bit Counter End
	bit_counter_end <= bit_counter(4) and bit_counter(3) and bit_counter(2) and bit_counter(1) and bit_counter(0);

	--------------------
	-- Pmod DA4 Ready --
	--------------------
    o_ready <= '1' when (state = IDLE) else '0';

    ---------------------
	-- SPI SCLK Output --
	---------------------
	process(i_sys_clock)
	begin
		if rising_edge(i_sys_clock) then

			-- SCLK Rising Edge
			if (spi_clock_rising = '1') then
				sclk_out <= '1';
			
			-- SCLK Falling Edge
			elsif (spi_clock_falling = '1') then
                sclk_out <= '0';
			
			end if;
		end if;
	end process;
	o_sclk <= SCLK_IDLE_BIT when state = IDLE or state = WAITING else sclk_out;

	----------------------------
	-- SPI Write Value (MOSI) --
	----------------------------
	process(i_sys_clock)
	begin

		if rising_edge(i_sys_clock) then
			
			-- Load MOSI Register
			if (state = START_TX) then

                -- Don't Care Bits
				mosi_reg(31 downto 28) <= (others => AD5628_DONT_CARE_BIT);

                -- Command Bits
                mosi_reg(27 downto 24) <= command_reg;

                -- Address Bits
                mosi_reg(23 downto 20) <= addr_reg;

                -- Data Bits
                mosi_reg(19 downto 8) <= digital_value_reg;

                -- Don't Care Bits
				mosi_reg(7 downto 0) <= (others => AD5628_DONT_CARE_BIT);

			-- Left-Shift MOSI Register 
			elsif (state = BYTES_TX) and (spi_clock_rising = '1') then
				mosi_reg <= mosi_reg(30 downto 0) & MOSI_IDLE_BIT;
			end if;

		end if;
	end process;
	o_mosi <= mosi_reg(31) when (state = BYTES_TX) or (state = WAITING) else MOSI_IDLE_BIT;

    ---------------------------
	-- SPI Slave Select Line --
	---------------------------
    o_ss <= DISABLE_SS_LINE when (state = IDLE) else not(DISABLE_SS_LINE);

end Behavioral;