module Processor12(
	input clk,
	input rst,
	input [23:0] irq,
	input [11:0] data_in,
	output [11:0] data_out,
	output [23:0] address
);
	reg [2:0] state;
	always @(posedge clk or negedge rst) begin
		if (!rst) begin
			state <= 3'b000;
		end
		else begin
			if (state[0])
				state <= 3'b010;
			else if (state[1])
				state <= 3'b100;
			else
				state <= 3'b001;
		end
	end
	assign data_out = {9'b0, state};
endmodule

`timescale 1ns/1ps
module Processor12_test();
	reg clk;
	reg rst;
	wire [11:0] data_out;
	wire [23:0] address;
	Processor12 DUT(clk, rst, 24'b0, 12'b0, data_out, address);
	initial begin
		clk = 0;
		repeat (1000) begin
			#25
			clk = 1;
			#25
			clk = 0;
		end
	end
	initial begin
		rst = 0;
		#125
		rst = 1;
	end
endmodule
