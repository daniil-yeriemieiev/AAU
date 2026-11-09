
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity spi_if is
    port (
        clk       : in  std_logic;
        rst       : in  std_logic;

        -- SPI interface
        SCLK      : in  std_logic;
        CS_b      : in  std_logic;
        MOSI      : in  std_logic;
        MISO      : out std_logic;

        -- Packet Controller interface
        fr_start  : out std_logic;
        fr_end    : out std_logic;
        fr_error  : out std_logic;

        data_out  : out std_logic_vector(15 downto 0);
        data_in   : in  std_logic_vector(15 downto 0);
        load_data : in  std_logic
    );
end entity spi_if;

architecture rtl of spi_if is
-- firststep synchroniyation SCLK
signal sclk_meta : std_logic;
-- Secondstep synchroniyation SCLK
signal sclk_sync : std_logic;
 --  Value of SCLK from previous clk tact
signal sclk_prev : std_logic;
-- Impulses for identifing  SCLK edges
signal sclk_re   : std_logic; -- Rising edge
signal sclk_fe : std_logic; -- Falling edge
-- firststep synchroniyation CS_b
signal cs_meta : std_logic;
-- Secondstep synchroniyation CS_b
signal cs_sync : std_logic;
--  Value of CS_b from previous clk tact
signal cs_prev : std_logic;
-- Impulses for identifing  CS_b edges
signal cs_re   : std_logic; -- Rising edge
signal cs_fe   : std_logic;-- Falling edge
-- firststep synchroniyation MOSI
signal mosi_meta : std_logic;
-- Secondstep synchroniyation MOSI
signal mosi_sync : std_logic;
-- 16-bit shift register for received SPI data (MOSI)
signal rx_shift : std_logic_vector(15 downto 0);
-- 16-bit shift register for transmitted SPI data (MISO)
signal tx_shift : std_logic_vector(15 downto 0);
-- 5-bit counter for the number of received bits
-- Counts up to 17 to detect frames longer than 16 bits
signal bit_counter : unsigned(4 downto 0);
-- Indicates that an SPI frame is active
-- Prevents processing a frame interrupted by reset
signal frame_active : std_logic;

begin
 -- 1.  SCLK Synchronization
    p_sclk_sync : process(clk)
begin
    if rising_edge(clk) then
        sclk_meta <= SCLK;
        sclk_sync <= sclk_meta;
    end if;
end process;
 -- 2. Memorizing previous SCLK
    p_sclk_edge : process(clk)
begin
    if rising_edge(clk) then
            sclk_prev <= sclk_sync;
        end if;
end process;
--3.  CS_b Synchronization
    p_cs_sync : process(clk)
begin
    if rising_edge(clk) then
        cs_meta <= CS_b ;
        cs_sync <= cs_meta ;
    end if;
end process;
-- 4. Memorizing previous CS_b
    p_cs_edge : process(clk)
begin
    if rising_edge(clk) then
            cs_prev <= cs_sync;
        end if;
end process;
--5.  MOSI Synchronization
    p_mosi_sync : process(clk)
begin
    if rising_edge(clk) then
        mosi_meta <= MOSI ;
        mosi_sync <= mosi_meta ;
    end if;
end process;
-- 6.Receive 16-bit SPI data, LSb first
p_rx_shift : process(clk)
begin
    if rising_edge(clk) then
        if rst = '1' then
            rx_shift <= (others => '0');
        elsif cs_fe = '1' then
        rx_shift <= (others => '0');
        elsif (cs_sync = '0' and sclk_re = '1') then
        if frame_active = '1' then 
        rx_shift <= mosi_sync & rx_shift(15 downto 1);
        end if;
        end if;
    end if;
end process;
-- 7. Transmit shift register
-- Loads parallel data from Packet Controller
-- and shifts data for serial transmission via MISO
p_tx_shift : process(clk)
begin
    if rising_edge(clk) then
        if rst = '1' then
            tx_shift <= (others => '0');
        elsif load_data = '1' then
        tx_shift <= data_in;
         elsif (cs_sync = '0'   and sclk_fe = '1' and bit_counter > 0) then
         if frame_active = '1' then 
        tx_shift <= '0' & tx_shift(15 downto 1);
   end if;
   end if;
end if;
end process;

-- 8. Received bit counter
-- Counts SCLK rising edges during an active frame
p_bit_counter : process(clk)
begin
if rising_edge(clk) then
        if rst = '1' then 
        bit_counter <= (others => '0');
        elsif cs_fe = '1' then
         bit_counter <= (others => '0');
       elsif (cs_sync = '0' and sclk_re = '1') then
        if frame_active = '1' then 
             if bit_counter < 17 then
        bit_counter <= (bit_counter +1);
    end if;
    end if;
    end if;
end if;
end process;
-- 9. Frame validation
-- Generates frame start-end pulses and reports invalid frame 
-- Updates data_out ONLY after receiving exactly 16 bits
p_frame_check : process(clk)
begin
    if rising_edge(clk) then
     if rst = '1' then
      data_out <= (others => '0');
      fr_end <= '0' ;
    fr_error <= '0'  ;
    fr_start <= '0'  ;
      else
     fr_end <= '0' ;
    fr_error <= '0'  ;
    fr_start <= '0'  ;
  if cs_fe = '1' then 
     fr_start<= '1';  
     end if;
 if (cs_re = '1' and frame_active = '1') then 
     fr_end <= '1';
 if bit_counter  /= 16 then   
  fr_error <= '1' ;
  else  
  data_out  <= rx_shift;
  end if;
   end if;    
      end if;
     
end if;
end process;     

 -- 10. Frame activitz control
-- Tracks frame boundaries and ignores frames interrupted by reset
p_frame_active : process(clk)
begin
    if rising_edge(clk) then
        if rst = '1' then 
        frame_active <= '0';
        elsif cs_fe = '1' then
        frame_active <= '1';
        elsif cs_re = '1' then
        frame_active <= '0';
        
 end if;   
 end if;
 end process;
 -- 11. SPI serial output
-- Transmits the lsb  of the TX register MISO
MISO <= tx_shift(0);
-- 12.Rising Edge Detector (0 -> 1) for  SCLK
sclk_re <= sclk_sync and (not sclk_prev);
--13.Falling Edge Detector (1 -> 0)  for  SCLK
sclk_fe <= sclk_prev and (not sclk_sync);
-- 14.Rising Edge Detector (0 -> 1 for CS_b
cs_re <= cs_sync and (not cs_prev);
-- 15.Falling Edge Detector (1 -> 0) for CS_b
cs_fe <= cs_prev and (not cs_sync);
end architecture rtl;
