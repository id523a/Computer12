module InterruptInput(
	input clk,
	input irq, // irq: positive edge triggered, not synchronized, must be 1 for at least 1 clock cycle
	input dismiss,
	output reg out
);
	reg irq_prev = 1'b0;
	
	always @(posedge clk) begin
		irq_prev <= irq;
		out <= (out | (irq & ~irq_prev)) & ~dismiss;
	end
endmodule

module PriorityEncoder #(
	parameter WIDTH_IN = 4,
	parameter WIDTH_OUT = 2
) (
	input [WIDTH_IN-1:0] in,
	input [WIDTH_OUT-1:0] default_val,
	output reg [WIDTH_OUT-1:0] out
);

	integer i;
	always @(*) begin
		out = default_val;
		for (i = WIDTH_IN-1; i >= 0; i = i - 1) begin
			if (in[i]) out = i;
		end
	end
endmodule

module InterruptController #(
	parameter INTERRUPT_LINES = 24
) (
	input clk,
	input rst,
	input [INTERRUPT_LINES-1:0] irq,
	input dismiss,
	input create,
	input [11:0] data_in,
	output [11:0] next_interrupt
);
	wire select_all = (data_in == 12'o7777);
	wire select_software = (data_in >= INTERRUPT_LINES);
	wire [INTERRUPT_LINES-1:0] irq_out;
	reg [11:0] software_interrupt;
	
	genvar idx;
	generate
		for (idx = 0; idx < INTERRUPT_LINES; idx = idx + 1) begin : gen_inputs
			InterruptInput irq_input(
				.clk(clk),
				.irq(irq[idx]),
				.dismiss(dismiss & ((data_in == idx) | select_all)),
				.out(irq_out[idx])
			);
		end
	endgenerate
	
	PriorityEncoder #(
		.WIDTH_IN(INTERRUPT_LINES),
		.WIDTH_OUT(12)
	) interrupt_finder(
		.in(irq_out),
		.default_val(software_interrupt),
		.out(next_interrupt)
	);
	
	always @(posedge clk or negedge rst) begin
		if (!rst) begin
			software_interrupt <= 12'o7777;
		end
		else if (select_software) begin
			if (dismiss) software_interrupt <= 12'o7777;
			if (create) software_interrupt <= data_in;
		end
	end
endmodule

`timescale 1ns/1ps
module InterruptController_test();
	reg clk = 1'b0;
	reg [5:0] irq_in = 6'b0;
	reg dismiss;
	reg create;
	reg [11:0] data_in;
	wire [11:0] next_interrupt;
	
	InterruptController #(
		.INTERRUPT_LINES(6)
	) DUT(
		.clk(clk),
		.irq(irq_in),
		.dismiss(dismiss),
		.create(create),
		.data_in(data_in),
		.next_interrupt(next_interrupt)
	);
	
	initial repeat (200) begin
		#10 clk = ~clk; 
	end
	
	initial begin
		#189 irq_in[2] = 1'b1;
		#1 irq_in[2] = 1'b0;
		#159 irq_in[0] = 1'b1;
		#1 irq_in[0] = 1'b0;
		#149 irq_in[1] = 1'b1;
		#1 irq_in[1] = 1'b0;
		#149 irq_in[3] = 1'b1;
		#1 irq_in[3] = 1'b0;
	end
	
	initial begin
		data_in = 12'o7777;
		dismiss = 1'b1;
		create = 1'b0;
		#20;
		dismiss = 1'b0;
		create = 1'b1;
		data_in = 12'o7000;
		#20;
		create = 1'b0;
		#400;
		data_in = 12'o0000;
		dismiss = 1'b1;
		#20;
		dismiss = 1'b0;
		#260;
		data_in = 12'o0001;
		dismiss = 1'b1;
		#20;
		data_in = 12'o0002;
		#20;
		dismiss = 1'b0;
		#100;
		dismiss = 1'b1;
		data_in = 12'o0003;
		#20;
	end
endmodule
