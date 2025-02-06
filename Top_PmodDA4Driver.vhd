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

ENTITY Top_PmodDA4Driver is

PORT(
	i_sys_clock: IN STD_LOGIC;
    i_reset: IN STD_LOGIC;
    i_enable: IN STD_LOGIC;
    i_addr: IN UNSIGNED(3 downto 0);
	o_sclk: OUT STD_LOGIC;
    o_mosi: OUT STD_LOGIC;
	o_ss: OUT STD_LOGIC
);

END Top_PmodDA4Driver;

ARCHITECTURE Behavioral of Top_PmodDA4Driver is

------------------------------------------------------------------------
-- Component Declarations
------------------------------------------------------------------------
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

------------------------------------------------------------------------
-- Signal Declarations
------------------------------------------------------------------------
-- Pmod DA4 Configuration Init
signal pmodda4_init_end: STD_LOGIC := '0';

-- Pmod DA4 Ready Handler
signal pmodda4_ready: STD_LOGIC := '0';
signal pmodda4_ready_reg: STD_LOGIC := '0';
signal pmodda4_ready_rising: STD_LOGIC := '0';

-- Pmod DA4 Input Register
signal command_reg: UNSIGNED(3 downto 0) := (others => '0');
signal address_reg: UNSIGNED(3 downto 0) := (others => '0');
signal digital_value_reg: UNSIGNED(11 downto 0) := (others => '0');
signal config_reg: UNSIGNED(7 downto 0) := (others => '0');

------------------------------------------------------------------------
-- Module Implementation
------------------------------------------------------------------------
begin

    ----------------------------
	-- Pmod DA4 Ready Handler --
	----------------------------
	process(i_sys_clock)
	begin

		if rising_edge(i_sys_clock) then
            pmodda4_ready_reg <= pmodda4_ready;
        end if;
    end process;
    pmodda4_ready_rising <= pmodda4_ready and not(pmodda4_ready_reg);

    -------------------
	-- Pmod DA4 Mode --
	-------------------
	process(i_sys_clock)
	begin

		if rising_edge(i_sys_clock) then

            -- Reset
            if (i_reset = '1') then
                pmodda4_init_end <= '0';

            -- Config Mode
            elsif (pmodda4_ready_rising = '1') then
                pmodda4_init_end <= '1';
            end if;
        end if;
    end process;

	------------------------------
	-- Digital Value Simulation --
	------------------------------
	process(i_sys_clock)
	begin

		if rising_edge(i_sys_clock) then

            -- Reset Digital Value
            if (i_reset = '1') then
                command_reg <= x"0";
                address_reg <= x"0";
                digital_value_reg <= x"000";
                config_reg <= x"00";
            
            -- Config Mode
            elsif (pmodda4_init_end = '0') then
                command_reg <= x"8";
                address_reg <= x"0";
                digital_value_reg <= x"000";
                config_reg <= x"01";

            -- Signal Mode
            else
                command_reg <= x"3";
                address_reg <= i_addr;
                digital_value_reg <= digital_value_reg;
                config_reg <= x"00";
            end if;

            -- Increment Digital Value
            if (pmodda4_ready_rising = '1') then
                digital_value_reg <= digital_value_reg +1;         
            end if;

        end if;
    end process;

    ---------------------
	-- Pmod DA4 Driver --
	---------------------
    inst_PmodDA4Driver: PmodDA4Driver
    generic map (
        sys_clock => 100_000_000,
        spi_clock => 1_000_000)
    
    port map (
        i_sys_clock => i_sys_clock,
        i_enable => i_enable,
        i_command => command_reg,
        i_addr => address_reg,
        i_digital_value => digital_value_reg,
        i_config => config_reg,
        o_ready => pmodda4_ready,
        o_sclk => o_sclk,
        o_mosi => o_mosi,
        o_ss => o_ss);

end Behavioral;