module Computer12(
	input clk50,
	input rst_in,
	output [11:0] video_rgb,
	output video_hsync,
	output video_vsync
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
		.addr(mem_addr),
		.data(mem_data),
		.video_rgb(video_rgb),
		.video_hsync(video_hsync),
		.video_vsync(video_vsync)
	);
endmodule
