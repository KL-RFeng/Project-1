-------------------------------------------------------------
--
-- Author: Kurt Lehmann 
--
-- Description:
-- lab7_top is a sine wave generator using the Sine look-up table that will be
-- generated from the Xilinx Vivado IP catalog's DDS compiler.
-- BTNC is the overall reset for all sequential logic
-- SW(2:0) is used to set the output frequency of the sine wave
-- SW(5:3) is used to set the volume level of the output
-- SW(15) is used to turn on and off the amplifier network for the audio output

--------------------------------------------------------------------------------------------

library IEEE; 
use ieee.std_logic_1164.all; 
use ieee.numeric_std.all; 
use work.all;

entity lab7_top is
    Port ( CLK100MHZ : in STD_LOGIC;
           BTNC : in STD_LOGIC;
           SW : in STD_LOGIC_VECTOR (15 downto 0);
           AN : out STD_LOGIC_VECTOR (7 downto 0);
           SEG7_CATH : out STD_LOGIC_VECTOR (7 downto 0);
           AUD_PWM : out STD_LOGIC;
           AUD_SD : out STD_LOGIC);
end lab7_top;

architecture Behavioral of lab7_top is

component sine_lut_dds
Port ( 
       aclk : in std_logic;
       s_axis_phase_tvalid : in std_logic;
       s_axis_phase_tdata : in std_logic_vector (7 downto 0);
       m_axis_data_tvalid : out std_logic;              
       m_axis_data_tdata : out std_logic_vector (15 downto 0)
    );
end component;
--------- signal declarations ----------------------------------------------------
signal reset : std_logic; 

signal cntr : unsigned(9 downto 0);  -- 781 which is the highest count (due to MaxCnt) needs 10 bits to represent 781 as a binary number 1100001101
signal cntrAccu : unsigned(7 downto 0);
signal cntrAccu_DC : unsigned(7 downto 0);
signal accumOut : std_logic_vector(7 downto 0);
signal enable : std_logic;
--constant MaxCnt : integer :=  391; -- (1/100,000,000 Hz clock)(781) =  7.81 us   7.81 us * 256 = 2 ms period of 500 Hz
signal MaxCnt : integer; -- (1/100,000,000 Hz clock)(781) =  7.81 us   7.81 us * 256 = 2 ms period of 500 Hz

--Seg7_Controller Sigs
signal clear : std_logic; 
signal pulseCnt1KHz : unsigned(16 downto 0); --17 bits
constant maxCount1KHz : unsigned(16 downto 0) := to_unsigned(100000, 17); 
signal cntr3bit : unsigned(2 downto 0); 
signal setAnode : std_logic_vector(7 downto 0);
signal selChar : std_logic_vector(3 downto 0);
signal seg7 : std_logic_vector (7 downto 0);   

Signal FreqDisp : STD_LOGIC_VECTOR (15 downto 0); 
signal char2 : STD_LOGIC_VECTOR(3 downto 0);
signal char3 : STD_LOGIC_VECTOR (3 downto 0);
Signal VolDisp : STD_LOGIC_VECTOR (15 downto 0); 
signal char4 : STD_LOGIC_VECTOR(3 downto 0);
signal char5 : STD_LOGIC_VECTOR (3 downto 0);
signal char6 : STD_LOGIC_VECTOR(3 downto 0);

signal sineOut : STD_LOGIC_VECTOR (15 downto 0); 
--signal sineOut_top10 : unsigned (9 downto 0); -- top 10 bits use

--Volume Level Shifter PWM signals
signal sineOut_MSB : STD_LOGIC_VECTOR (0 downto 0);  
signal sineOut_MSB_invert : STD_LOGIC_VECTOR (0 downto 0);  
signal sineOut_btm_bits : STD_LOGIC_VECTOR (14 downto 0); 
--signal sineOut_MSB_invert_plus_btm_bits : STD_LOGIC_VECTOR (15 downto 0); 
signal sineOut_MSB_invert_plus_btm_bits : unsigned (15 downto 0); 
--signal sineOutVol_adjust :  STD_LOGIC_VECTOR (15 downto 0); 
signal sineOutVol_adjust :  unsigned (15 downto 0); 
signal shift_value : integer := 0;  --

-- PWM signals
signal duty_cycle : unsigned(9 downto 0);
signal pwm_out : std_logic;
signal pwm_cnt : unsigned(9 downto 0);
signal cntrPWM : unsigned(9 downto 0);
-------------------------------------------------------------------------------------------------------

begin
reset <= BTNC; -- BTNC is the overall reset for all sequential logic

-- 8 to 1 Frequency Selection MUX via Max Sample Rate Count (MaxCnt)
process(CLK100MHZ, reset) 
begin
   if(reset = '1') then 
     MaxCnt <= 0; 
   elsif(rising_edge(CLK100MHZ)) then 
        case SW(2 downto 0) is
            when "000" => MaxCnt <=  0;   -- 0 Hz
            when "001" => MaxCnt <=  781; -- 500 Hz
            when "010" => MaxCnt <=  391; -- 1000 Hz
            when "011" => MaxCnt <=  260; -- 1500 Hz
            when "100" => MaxCnt <=  195; -- 2000 Hz
            when "101" => MaxCnt <=  156; -- 2500 Hz
            when "110" => MaxCnt <=  130; -- 3000 Hz
            when "111" => MaxCnt <=  112; -- 3500 Hz
            when others => MaxCnt <= 0;
        end case;
   end if; 
end process;

-- Counter to generate enable pulse
process(CLK100MHZ, reset)
begin
    if(reset = '1') then
        cntr <= (others => '0');
    elsif(rising_edge(CLK100MHZ)) then
        if(cntr < MaxCnt) then
            cntr <= cntr + 1;
        else
            cntr <= (others => '0');
        end if;
    end if;
end process;
enable <= '1' when cntr = MaxCnt else '0';


--Phase Accumulator (free running counter that wraps around to zero after 2^8 or 256 counts) because --> signal cntrAccu : unsigned(7 downto 0);
process(CLK100MHZ, reset)
begin
    if(reset = '1') then
        cntrAccu <= (others => '0');
    elsif(rising_edge(CLK100MHZ)) then
    if(enable = '1') then
       cntrAccu <= cntrAccu + 1;
   end if;
  end if;
end process;

--------  sine_lut_dds ----------------------------------------------------

cntrAccu_DC <= cntrAccu when MaxCnt > 0 else "00000000";
accumOut <= std_logic_vector(cntrAccu_DC); -- convert from unsigned to std_logic_vector for input to sineGen: sine_lut_dds  s_axis_phase_tdata => accumOut,

sineGen: sine_lut_dds port map (
aclk => CLK100MHZ,
s_axis_phase_tvalid => '1',
s_axis_phase_tdata => accumOut,
m_axis_data_tdata => sineOut 
);

-----------Level Adjust------------------------------------------------------------------------------
-- inverting the MSB of the m_axis_data_tdata signal (s/a sineOut signal from the DDS) 
sineOut_MSB <= sineOut(15 downto 15); -- slice the vector for MSB from output of sineGen: sine_lut_dds  m_axis_data_tdata => sineOut 
sineOut_MSB_invert <= not sineOut_MSB;
sineOut_btm_bits <= sineOut(14 downto 0);
sineOut_MSB_invert_plus_btm_bits <= unsigned(sineOut_MSB_invert & sineOut_btm_bits);

----------Volume Level Shifter------------------------------------------------------------------------------
-- 8 to 1 Volume Selection MUX
process(CLK100MHZ, reset) 
begin
   if(reset = '1') then 
     shift_value <= 0; 
   elsif(rising_edge(CLK100MHZ)) then 
        case SW(5 downto 3) is
            when "000" => shift_value <=  7; --0%
            when "001" => shift_value <=  6; --13%
            when "010" => shift_value <=  5; --29%
            when "011" => shift_value <=  4; --43%
            when "100" => shift_value <=  3; --57%
            when "101" => shift_value <=  2; --71%
            when "110" => shift_value <=  1; --86%
            when "111" => shift_value <=  0; --100%
            when others => shift_value <= 0;
        end case;
   end if; 
end process;

sineOutVol_adjust <= sineOut_MSB_invert_plus_btm_bits srl shift_value;


--------- Pulse Width Modulation (PWM)----------------------------------------------------------------------
 -- seperate entity make

duty_cycle <= sineOutVol_adjust(15 downto 6); -- slice the vector for top 10 bits

-- PWM Counter
process(CLK100MHZ, reset)
begin
    if(reset = '1') then
        pwm_cnt <= (others => '0');
     elsif(rising_edge(CLK100MHZ)) then
        if(pwm_cnt < 1023) then
            pwm_cnt <= pwm_cnt + 1;
        else
            pwm_cnt <= (others => '0');
        end if;
    end if;
end process;

pwm_out <= '1' when pwm_cnt < duty_cycle else '0'; -- note at 1023, the value is zero to prevent a constant DC output

AUD_PWM <= pwm_out; -- Drive the input of the filter (AUD_PWM) with pwm_out signal
AUD_SD  <= SW(15); -- SW(15) turns on and off the amplifier network for the audio output, setting SW(15) to '1' will cause the audio output to turn-on/vice-versa. 

----- Seg7_Controller -----------------------------------------------------------------------------

 -- 1 kHz Pulse Generator 
process(CLK100MHZ, reset)
    begin 
        if(reset = '1') then 
            pulseCnt1KHz <= (others=>'0'); 
    elsif(rising_edge(CLK100MHZ)) then 
        if (clear = '1') then 
            pulseCnt1KHz <= (others=>'0');
        else 
             pulseCnt1KHz <= pulseCnt1KHz + 1; -- upcounter
        end if; 
    end if; 
end process; 
clear <= '1' when (pulseCnt1KHz = maxCount1KHz) else '0'; 

-- Anode 3-bit Counter   
process(CLK100MHZ, reset) 
begin
   if(reset = '1') then 
     cntr3bit <= (others => '0'); 
   elsif(rising_edge(CLK100MHZ)) then 
      if(clear = '1') then
   	    cntr3bit <= cntr3bit + 1;
   	  end if; 
   end if; 

end process;

-- 3 to 8 Anode Decoder Active Low
process(CLK100MHZ, reset) 
begin
   if(reset = '1') then 
     setAnode <= (others => '0');
   elsif(rising_edge(CLK100MHZ)) then 
        case cntr3bit is
            when "000" => setAnode <=  "11111110"; -- digit 1 on
            when "001" => setAnode <=  "11111101"; -- digit 2 on
            when "010" => setAnode <=  "11111011"; -- digit 3 on
            when "011" => setAnode <=  "11110111"; -- digit 4 on
            when "100" => setAnode <=  "11101111"; -- digit 5 on
            when "101" => setAnode <=  "11011111"; -- digit 6 on
            when "110" => setAnode <=  "10111111"; -- digit 7 on
            when "111" => setAnode <=  "01111111"; -- digit 8 on
            when others => setAnode <=  "11111111"; -- no digit on             
        end case;
   end if; 
AN <= std_logic_vector(setAnode);   --AN is anodeSelect
end process;

--Frequency Display Mapping:
process(CLK100MHZ, reset) 
begin
   if(reset = '1') then 
     FreqDisp <= (others => '0');
   elsif(rising_edge(CLK100MHZ)) then 
        case SW(2 downto 0) is
            when "000" => FreqDisp <=  x"0000";
            when "001" => FreqDisp <=  x"0500";
            when "010" => FreqDisp <=  x"1000";
            when "011" => FreqDisp <=  x"1500";
            when "100" => FreqDisp <=  x"2000";
            when "101" => FreqDisp <=  x"2500";
            when "110" => FreqDisp <=  x"3000";
            when "111" => FreqDisp <=  x"3500";
            when others => FreqDisp <= x"0000";
        end case;
   end if; 
end process;
char2 <= FreqDisp(11 downto 8); -- to display third hex digit 
char3 <= FreqDisp(15 downto 12); -- to display fourth hex digit

--Volume Display Mapping:
process(CLK100MHZ, reset) 
begin
   if(reset = '1') then 
     VolDisp <= (others => '0');
   elsif(rising_edge(CLK100MHZ)) then 
        case SW(5 downto 3) is
            when "000" => VolDisp <=  x"0000";
            when "001" => VolDisp <=  x"0013";
            when "010" => VolDisp <=  x"0029";
            when "011" => VolDisp <=  x"0043";
            when "100" => VolDisp <=  x"0057";
            when "101" => VolDisp <=  x"0071";
            when "110" => VolDisp <=  x"0086";
            when "111" => VolDisp <=  x"0100";
            when others => VolDisp <= x"0000";
        end case;
   end if; 
end process;
char4 <= VolDisp(3 downto 0); -- to display third hex digit 
char5 <= VolDisp(7 downto 4); -- to display fourth hex digit
char6 <= VolDisp(11 downto 8); -- to display fourth hex digit

-- 8 to 1 Character Selection MUX
process(CLK100MHZ, reset) 
begin
   if(reset = '1') then 
     selChar <= (others => '0');
   elsif(rising_edge(CLK100MHZ)) then 
        case cntr3bit is
            when "000" => selChar <=  x"0";
            when "001" => selChar <=  x"0";
            when "010" => selChar <=  char2;
            when "011" => selChar <=  char3;
            when "100" => selChar <=  char4;
            when "101" => selChar <=  char5;
            when "110" => selChar <=  char6;
            when "111" => selChar <=  x"0";
            when others => selChar <= x"0";
        end case;
   end if; 
end process;

-- 7-Segment Encoder
process(CLK100MHZ, reset) 
begin
   if(reset = '1') then 
     seg7 <= (others => '0');
   elsif(rising_edge(CLK100MHZ)) then 
        case selChar is
            when x"0" => seg7 <=  "11000000"; -- 7-SEGMENT displays 0
            when x"1" => seg7 <=  "11111001"; -- 7-SEGMENT displays 1           
            when x"2" => seg7 <=  "10100100"; -- 7-SEGMENT displays 2
            when x"3" => seg7 <=  "10110000"; -- 7-SEGMENT displays 3          
            when x"4" => seg7 <=  "10011001"; -- 7-SEGMENT displays 4
            when x"5" => seg7 <=  "10010010"; -- 7-SEGMENT displays 5            
            when x"6" => seg7 <=  "10000010"; -- 7-SEGMENT displays 6
            when x"7" => seg7 <=  "11111000"; -- 7-SEGMENT displays 7           
            when x"8" => seg7 <=  "10000000"; -- 7-SEGMENT displays 8
            when x"9" => seg7 <=  "10010000"; -- 7-SEGMENT displays 9            
            when x"A" => seg7 <=  "10001000"; -- 7-SEGMENT displays A
            when x"B" => seg7 <=  "10000011"; -- 7-SEGMENT displays B          
            when x"C" => seg7 <=  "11000110"; -- 7-SEGMENT displays C
            when x"D" => seg7 <=  "10100001"; -- 7-SEGMENT displays D           
            when x"E" => seg7 <=  "10000110"; -- 7-SEGMENT displays E
            when others => seg7 <=  "10001110"; -- 7-SEGMENT displays F            
        end case;
   end if; 
SEG7_CATH  <=  seg7;   
end process;

end Behavioral;

