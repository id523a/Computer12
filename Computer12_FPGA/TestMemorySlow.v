module LFSR31(
	input clock,
	output reg [30:0] state
);
	initial state = 31'o37064627;
	always @(posedge clock) begin
		state <= {state[29:0], ~(state[30] ^ state[27])};
	end
endmodule

module TestMemorySlow(
	input clock,
	input [11:0] address,
	input [11:0] data,
	input rden,
	input wren,
	output ready,
	output [11:0] q
);

	reg [2:0] cooldown = 3'd0;
	assign ready = (cooldown == 0);
	
	wire rden_filtered = rden & ready;
	wire wren_filtered = wren & ready;
	
	wire [11:0] q_raw;
	
	wire [30:0] time_rand;
	LFSR31 time_randomizer(
		.clock(clock),
		.state(time_rand)
	);
	
	TestMemory mem_backing(
		.address(address),
		.clock(clock),
		.data(data),
		.rden(rden_filtered),
		.wren(wren_filtered),
		.q(q_raw)
	);
	
	always @(posedge clock) begin
		if (cooldown > 0) begin
			cooldown <= cooldown - 3'd1;
		end
		else if (rden_filtered | wren_filtered) begin
			cooldown <= 3'd1 + time_rand[1:0];
		end
	end
	
	assign q = ready ? q_raw : 12'oxxxx;
endmodule
