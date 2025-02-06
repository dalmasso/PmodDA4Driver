------------------------------------------------------------------------
-- Engineer:    Dalmasso Loic
-- Create Date: 05/02/2025
-- Module Name: Top_PmodDA4Driver
-- Description:
--      Top Module including Pmod DA4 Driver for the 8 Channels 12-bit Digital-to-Analog Converter AD5628.
--
-- Ports
--		Input 	-	i_sys_clock: System Input Clock
--		Input 	-	i_reset: Module Reset ('0': No Reset, '1': Reset)
--		Input 	-	i_enable: Module Enable ('0': Disable, '1': Enable)
--		Input 	-	i_addr: DAC Address Register (4 bits)
--		Output 	-	o_sclk: SPI Serial Clock
--		Output 	-	o_mosi: SPI Master Output Slave Input Data line
--		Output 	-	o_ss: SPI Slave Select Line ('0': Enable, '1': Disable)
------------------------------------------------------------------------

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY Testbench_Top_PmodDA4Driver is
--  Port ( );
END Testbench_Top_PmodDA4Driver;

ARCHITECTURE Behavioral of Testbench_Top_PmodDA4Driver is

COMPONENT Top_PmodDA4Driver is

    PORT(
        i_sys_clock: IN STD_LOGIC;
        i_reset: IN STD_LOGIC;
        i_enable: IN STD_LOGIC;
        i_addr: IN UNSIGNED(3 downto 0);
        o_sclk: OUT STD_LOGIC;
        o_mosi: OUT STD_LOGIC;
        o_ss: OUT STD_LOGIC
    );

END COMPONENT;

signal sys_clock: STD_LOGIC := '0';
signal reset: STD_LOGIC := '0';
signal enable: STD_LOGIC := '0';
signal addr: UNSIGNED(3 downto 0):= (others => '0');
signal sclk: STD_LOGIC := '0';
signal mosi: STD_LOGIC := '0';
signal ss: STD_LOGIC := '0';

begin

-- Clock 100 MHz
sys_clock <= not(sys_clock) after 5 ns;

-- Reset
reset <= '1', '0' after 11 us;

-- Enable
enable <= '0', '1' after 111 us;

-- Address
addr <= x"0", x"1" after 111 us, x"2" after 130 us;

uut: Top_PmodDA4Driver
    
    PORT map(
        i_sys_clock => sys_clock,
        i_reset => reset,
        i_enable => enable,
        i_addr => addr,
        o_sclk => sclk,
        o_mosi => mosi,
        o_ss => ss);

end Behavioral;