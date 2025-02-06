------------------------------------------------------------------------
-- Engineer:    Dalmasso Loic
-- Create Date: 05/02/2025
-- Module Name: PmodDA4Driver
-- Description:
--      Pmod DA4 Driver for the 8 Channels 12-bit Digital-to-Analog Converter AD5628. The communication with the DAC uses the SPI protocol (Write only)
--      User can specifies the SPI Serial Clock Frequency (up to 50 MHz).
--
-- Usage:
--		The o_ready signal (set to '1') indicates the PmodDA4Driver is ready to receive new data (command, address and digital value).
--		Once data are set, the i_enable signal can be triggered (set to '1') to begin transmission.
--		The o_ready signal is set to '0' to acknowledge the receipt and the application of the new data.
--		When the transmission is complete, the o_ready is set to '1' and the PmodDA4Driver is ready for new transmission.
--
--      Commands
--      | C3 | C2 | C1 | C0 | Description
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
--		Input 	-	i_digital_value: Digital Value to convert (12 bits)
--		Input 	-	i_config: DAC Configuration Bits (8 bits)
--		Output 	-	o_ready: Ready to convert Next Digital Value ('0': NOT Ready, '1': Ready)
--		Output 	-	o_sclk: SPI Serial Clock
--		Output 	-	o_mosi: SPI Master Output Slave Input Data line
--		Output 	-	o_ss: SPI Slave Select Line ('0': Enable, '1': Disable)
------------------------------------------------------------------------

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY Testbench_PmodDA4Driver is
--  Port ( );
END Testbench_PmodDA4Driver;

ARCHITECTURE Behavioral of Testbench_PmodDA4Driver is

COMPONENT PmodDA4Driver is

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
	i_config: IN UNSIGNED(7 downto 0);
    o_ready: OUT STD_LOGIC;
	o_sclk: OUT STD_LOGIC;
    o_mosi: OUT STD_LOGIC;
	o_ss: OUT STD_LOGIC
);

END COMPONENT;

signal sys_clock: STD_LOGIC := '0';
signal enable: STD_LOGIC := '0';
signal command: UNSIGNED(3 downto 0):= (others => '0');
signal addr: UNSIGNED(3 downto 0):= (others => '0');
signal digital_value: UNSIGNED(11 downto 0):= (others => '0');
signal config: UNSIGNED(7 downto 0):= (others => '0');
signal ready: STD_LOGIC := '0';
signal sclk: STD_LOGIC := '0';
signal mosi: STD_LOGIC := '0';
signal ss: STD_LOGIC := '0';

begin

-- Clock 100 MHz
sys_clock <= not(sys_clock) after 5 ns;

-- Enable
enable <= '0', '1' after 111 us, '0' after 114 us, '1' after 150 us, '0' after 153 us, '1' after 178 us, '0' after 237 us;

-- Inputs Sequence
process
begin
    -- Init
    command <= x"0";
    addr <= x"0";
    digital_value <= x"000";
    config <= x"00";
    wait for 111 us;
    
    -- Config Internal REF Register
    command <= x"8";
    addr <= x"0";
    digital_value <= x"000";
    config <= x"01";
    wait until ready = '0';
    
    -- Digital Value 1
    command <= x"F";
    addr <= x"2";
    digital_value <= x"123";
    config <= x"00";
    wait until ready = '0';
    
    -- Digital Value 2
    command <= x"9";
    addr <= x"8";
    digital_value <= x"765";
    config <= x"00";
    wait;
end process;

uut: PmodDA4Driver
    GENERIC map(
        sys_clock => 100_000_000,
        spi_clock => 1_000_000
    )
    
    PORT map(
        i_sys_clock => sys_clock,
        i_enable => enable,
        i_command => command,
        i_addr => addr,
        i_digital_value => digital_value,
        i_config => config,
        o_ready => ready,
        o_sclk => sclk,
        o_mosi => mosi,
        o_ss => ss);

end Behavioral;