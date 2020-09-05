module Computer12(
	input clk,
	input rst,
	output [11:0] data_p2m
);
	wire [23:0] address;
	wire [11:0] data_m2p;
	wire mem_read;
	wire mem_write;
	TestMemory tm(address[11:0], clk, data_p2m, mem_write, data_m2p);
	Processor12 DUT(clk, rst, 24'b0, data_m2p, data_p2m, address, mem_read, mem_write);
endmodule
