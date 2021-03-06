# Numerically-Controlled-Oscillator

The numerically controlled oscillator (NCO) is written in VHDL for the NEXYS A7 (formerly NEXYS4) FPGA development board which is designed around the Xilinx Artix-7 FPGA.

The NCO utilizes a Sine look-up table that is generated from the Xilinx Vivado IP catalog’s DDS compiler. The design uses slider switches on the dev board to set the tone frequency and where a different set of switches sets the volume of the sine waveform.

Please access and download the Word doc "Theory and Implementation of NCO" for a fuller description of theory and implementation.

To configure the NCO and use it you will need the following dependencies:
* Xilinx Vivado       
* Xilinx Artix-7 FPGA or compatible board
* provided files in NCO VHDL code files folder
