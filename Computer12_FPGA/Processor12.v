module Processor12(
	input clk,
	input rst,
	input [23:0] irq,
	input [11:0] data_in,
	output [11:0] data_out,
	output [23:0] address,
	output reg [2:0] state
);
	reg [23:0] PC;
	reg [11:0] instr_store;
	wire [11:0] instr;
	wire instr_has_immediate;
	
	InstructionDecoder(
		.instr(instr),
		.has_immediate(instr_has_immediate)
	);
	
	always @(posedge clk or negedge rst) begin : state_counter
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

	assign address = state[0] ? PC : 24'hxxxxxx;
	assign instr = state[1] ? data_in : instr_store;
	always @(posedge clk or negedge rst) begin : instruction_fetch
		if (!rst) begin
			PC <= 0;
			instr_store <= 0;
		end
		else begin
			if (state[0]) begin
				PC <= PC + 1;
			end
			if (state[1]) begin
				instr_store <= data_in;
			end
		end
	end
	assign data_out = instr;
endmodule

`timescale 1ns/1ps
module Processor12_test();
	reg clk;
	reg rst;
	reg [11:0] data_in;
	wire [11:0] data_out;
	wire [23:0] address;
	wire [2:0] state;
	
	always @(posedge clk) begin
		data_in <= address[11:0] | 12'h800;
	end
	Processor12 DUT(
		.clk(clk),
		.rst(rst),
		.irq(24'b0),
		.data_in(data_in),
		.data_out(data_out),
		.address(address),
		.state(state)
	);
	initial begin
		clk = 0;
		repeat (100) begin
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
