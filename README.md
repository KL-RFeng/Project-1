# Numerically-Controlled-Oscillator -Theory and Implementation

The numerically controlled oscillator (NCO) is written in VHDL for the NEXYS A7 FPGA development board which is designed around the Xilinx Artix-7 FPGA.

Dependencies: 
Xilinx Vivado
Xilinx Artix-7 FPGA or compatible board

Overview:
The NCO utilizes the Sine look-up table that is generated from the Xilinx Vivado IP catalog’s DDS compiler. The design uses slider switches on the dev board to set the tone frequency where a different set of switches sets the volume of the sine waveform. 
Theory of Operation and Implementation:
To reach a desired frequency, we begin with the equation:

    1/[Output Frequency of Sine Wave] = (Maximum Phase Counts) * (Phase Increment Delay)    (1) 

The maximum phase counts is defined by the accumulator component  which is 8-bits (8-bit phase resolution) and the phase increment delay is defined as  T_clock multiplied by the max sample rate count.  Eq (1) becomes

    1/[Output Frequency of Sine Wave] = (2^8)(T_clock∙Max Sample Rate Count)

and for a 100 MHz clock, we get

    1/(Output Frequency of Sine Wave)=256(10 ns∙Max Sample Rate Count)                     (2) 

Solving for Max Sample Rate Count from Eq(2) gives

Max Sample Rate Count = 1/[Desired Output Frequency] * 100 MHz * 1/256 

where 100 Mhz is the clock rate and 256 is the 8-bit accumulator size and Max Sample Rate Count determines how often the counter generates an enable pulse.

Example for 500Hz     Sample Rate Count = (1/500) * 100MHz * 1/256 = 781

Calculations of Max Sample Rate Count values and corresponding frequencies are found in Table 1.

Table 1: Max Sample Rate Count for Different Frequencies
Desired Frequency		Max Sample Rate Count	            Switch Selction(2:0)
0 HZ		            Special Case	                    000
500Hz		            (1/500) * 100MHz * 1/256 = 781	    001
1000Hz		          (1/1000) * 100MHz * 1/256 = 391	    010
1500Hz		          (1/1500) * 100MHz * 1/256 = 260	    011
2000Hz		          (1/2000) * 100MHz * 1/256 = 195	    100
2500Hz		          (1/2500) * 100MHz * 1/256 = 156	    101
3000Hz		          (1/3000) * 100MHz * 1/256 = 130	    110
3500Hz		          (1/3500) * 100MHz * 1/256 = 112	    111

The eight different frequencies found in Table 1 are selectable by SW(2:0). 

The VHDL implementation of the above values by the SW is done by a 8 to 1 Frequency Selection MUX to select an assigned Max Sample Rate Count value (MaxCnt)

Next there is counter that generates an enable pulse when the counter reaches the max sample rate count value MaxCnt.

This followed by a phase accumulator where the enable pulse feeds an accumulator. The phase accumulator is a free running 8-bit counter (phase width is 8-bits) that wraps around to zero after 2^8 or 256 counts which increments every time the enable is pulsed high. This in turn generates the proper Theta/Phase that feeds the input to the Sine LUT DDS.
Next, the process of the sine DDS component is as follows: The DDS contains a sinusoid lookup table for the data values of a sinusoid which takes in a given phase value and outputs the appropriate magnitude value for the sinusoid. The slower the DDS steps through the sinusoid lookup table, the lower in resulting frequency of the output waveform and conversely, the faster the DDS steps through the lookup table, a higher the resulting frequency of the output waveform is. The speed the DDS steps through the sinusoid lookup table is governed by the Phase Increment Delay, where, recall

Phase Increment Delay = T_clock * Max Sample Rate Count

Therefore, we can see that larger Max Sample Rate Counts results stepping through the DDS LUT more slowly resulting in lower frequencies and vice-versa. 

The output sine wave then feeds the input to the Volume Level Shifter block. Volume level control is accomplished by shifting the output sine value to the right by the inverse of the settings of SW(5:3). In other words, take the binary values representing the instantaneous amplitudes values of the sinewave and perform shift right operations that will reduce/scale those values proportionally. More shifting results in more reduction in the values. Because we are taking the inverse of the settings of SW(5:3), a switch value of ‘111’ will not shift the sine LUT output at all so that is 100% volume. But a switch value of ‘010’ will shift the sine LUT output by a value of 5 bits. A switch value of ‘000’ will shift the sine LUT output by 7 bits to create the lowest volume level.

Finally, the sine shifted value feeds the input to the PWM Generator which is needed in order to convert the digital sine signal into an amplified analog signal capable of driving the mono-audio output of the dev board.
