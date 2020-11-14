# Computer12
A fully-functional 12-bit computer, including a CPU, RAM, video generator and keyboard input, implemented on a FPGA. The CPU has a clock speed of 36 megahertz and uses a custom instruction set. The current design takes 3 clock cycles to execute each instruction. The screen resolution is 360x240 pixels, but this is scaled up to 800x600 for output by the video generator.

There are 7 general-purpose registers, each of which is 12 bits wide, labelled from A to G. In addition, there are 4 24-bit registers to hold memory addresses, labelled AP, BP, CP and IP. IP is the Instruction Pointer; modifying it causes the processor to start executing code a new location.

Every instruction is either 1 or 2 words (12 or 24 bits) wide. The first word of an instruction specifies the operation and the registers to operate on, and the second word (if present) is an immediate data value for that instruction. Most instructions require two values to be specified (a source register and a destination register), but some only require one.
