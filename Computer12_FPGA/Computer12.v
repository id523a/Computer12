module Computer12(
	input clk,
	input rst,
	output [11:0] data_out,
	output [23:0] address
);
	Processor12 DUT(clk, rst, 24'b0, 12'b0, data_out, address);
endmodule
