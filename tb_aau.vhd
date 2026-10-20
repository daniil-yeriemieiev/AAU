----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 21.10.2025 10:07:27
-- Design Name: 
-- Module Name: tb_aau - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_aau is

end tb_aau;

architecture Behavioral of tb_aau is
-- timing definition
constant c_CLK_per : time  := 10 ns;
constant c_SCLK_per : time := 1 us;
-- design parameters
constant c_DATA_W : natural := 16;

-- SPI IF as records
type t_SPI_MOSI is record
    SCLK : std_logic;
    CS_b : std_logic;
    MOSI : std_logic;
end record;

type t_SPI_MISO is record
    MISO : std_logic;
end record;

-- TB control signals 
signal run_clk_gen : std_logic;

-- DUT IF signals
signal clk, rst : std_logic;
signal dut_mosi : t_SPI_MOSI;
signal dut_miso : t_SPI_MISO;

-- BFM SPI MASTER
procedure send_frame(constant data_in  : in  integer;
                     variable data_out : out integer;
                     
                     signal spi_mosi   : out t_SPI_MOSI;
                     signal spi_miso   : in  t_SPI_MISO) is
variable data2send, data_rcv : std_logic_vector(c_DATA_W-1 downto 0);
begin
    data2send := std_logic_vector(to_signed(data_in, c_DATA_W));
    spi_mosi.cs_b <= '0';
    for idx in 0 to c_DATA_W-1 loop
        wait for c_SCLK_per/2;
        spi_mosi.sclk <= '0';
        -- Master sets output signal on SCLK falling edge
        spi_mosi.mosi <= data2send(idx);
        wait for c_SCLK_per/2;
        spi_mosi.sclk <= '1';
        -- Master samples input data on SCLK rising edge
        data_rcv(idx) := spi_miso.miso;
    end loop;
    wait for c_SCLK_per/2;
    spi_mosi.cs_b <= '1';
    data_out := to_integer(signed(data_rcv));
end procedure;                     

-- test procedures
procedure tc_dummy (signal spi_mosi   : out t_SPI_MOSI;
                    signal spi_miso   : in  t_SPI_MISO) is
    variable fr_1, fr_2 : integer;
begin                    
     -- send first packet
     send_frame(1000, fr_1, spi_mosi, spi_miso);
     wait for c_SCLK_per*2;
     send_frame(10000, fr_2, spi_mosi, spi_miso);
     wait for c_SCLK_per*2;
     report "FR1 : " & integer'image(fr_1) & 
          "  FR2 : " & integer'image(fr_2);
     
     -- send second packet
     send_frame(0, fr_1, spi_mosi, spi_miso);
     wait for c_SCLK_per*2;
     send_frame(0, fr_2, spi_mosi, spi_miso);
     wait for c_SCLK_per*2;
     report "FR1 : " & integer'image(fr_1) & 
          "  FR2 : " & integer'image(fr_2);
     
     if fr_1 /= 11000 then
        report "chyba souctu" severity error;
    end if; 
     
end procedure;

               
begin

-- DUT instance
i_dut : entity work.top_aau(structural)
    port map (
        clk     => clk,
        rst_in  => rst,
        
        SCLK    => dut_mosi.sclk,
        CS_b    => dut_mosi.cs_b,
        MOSI    => dut_mosi.mosi,
        MISO    => dut_miso.miso
    );

-- TB loopback
--dut_miso.miso <= dut_mosi.mosi;

p_clk_bfm : process begin
    if run_clk_gen = '1' then
        clk <= '0';
        wait for c_CLK_per/2;
        clk <= '1';
        wait for c_CLK_per/2;
    else 
        wait until  run_clk_gen = '1';
    end if; 
end process;

p_stimuli : process 
    variable tmp : integer;
begin
    -- initial signal assignment
    dut_mosi.cs_b <= '1';
    dut_mosi.sclk <= '1';
    -- start clock generator
    run_clk_gen <= '1';
    -- reset sequence (asynchronous reset)
    rst <= '1';
    wait for 10*c_CLK_per;
    rst <= '0';
    wait for 10*c_CLK_per;

    -- Run tests --
    --send_frame(100, tmp, dut_mosi, dut_miso); 
    --report "Result is " & integer'image(tmp);
    
    tc_dummy(dut_mosi, dut_miso);
    
    wait for 10*c_CLK_per;
    -- kill clock generator to stop simulation
    run_clk_gen <= '0';
    report "Simulation done" severity note;
    wait;
end process;

end Behavioral;