module Computer12(
	input clk50,
	input rst_in,
	output [11:0] video_rgb,
	output video_hsync,
	output video_vsync,
	output [7:0] blinkenlights,
	inout ps2_key_clk,
	inout ps2_key_data
);
	wire pll_locked;
	wire rst = rst_in & pll_locked;
	wire clk;
	MainPLL main_pll_1(
		.areset(~rst_in),
		.inclk0(clk50),
		.c0(clk),
		.locked(pll_locked)
	);

	/*
	wire [13:0] mem_addr;
	wire [11:0] mem_data;
	VideoTestMemory mem(
		.address(mem_addr),
		.clock(clk),
		.q(mem_data)
	);
	VideoGenerator vgen(
		.clk(clk),
		.rst(rst),
		.vmem_addr(mem_addr),
		.vmem_data(mem_data),
		.video_rgb(video_rgb),
		.video_hsync(video_hsync),
		.video_vsync(video_vsync)
	);
	*/
	assign video_rgb = 12'b0;
	assign video_hsync = 1'b0;
	assign video_vsync = 1'b0;
	
	wire ps2_new_scancode;
	wire [7:0] ps2_scancode;
	ps2_keyboard #(
		.clk_freq(36_000_000),
		.debounce_counter_size(8)
	) ps2_keyboard_in(
		.clk(clk),
		.ps2_clk(ps2_key_clk),
		.ps2_data(ps2_key_data),
		.ps2_code(ps2_scancode),
		.ps2_code_new(ps2_new_scancode)
	);
	assign blinkenlights = ps2_scancode;
endmodule
