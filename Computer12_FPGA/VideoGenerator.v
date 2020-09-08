module BlockPosAdder(
	input [5:0] p1_block,
	input [3:0] p1_pixel,
	input [5:0] p2_block,
	input [3:0] p2_pixel,
	output reg [5:0] q_block,
	output reg [3:0] q_pixel
);
	reg [4:0] pixel_sum;
	always @(*) begin
		pixel_sum = {1'b0, p1_pixel} + p2_pixel;
		if (pixel_sum >= 4'd12) begin
			q_pixel = pixel_sum - 4'd12;
			q_block = p1_block + p2_block + 1'b1;
		end
		else begin
			q_pixel = pixel_sum;
			q_block = p1_block + p2_block;
		end
	end
endmodule

module VideoScanlineMemory(
	input [7:0] address,
	input clock,
	input [11:0] data,
	input wren,
	output reg [11:0] q
);
	reg [11:0] mem[255:0];
	integer i;
	integer j;
	initial begin
		j = 1;
		for (i = 0; i < 256; i = i + 1) begin
			j = (j * 23) % 20000003;
			mem[i] = j[13:2];
		end
	end
	always @(posedge clock) begin
		if (wren) mem[address] <= data;
		q <= mem[address];
	end
endmodule

module PixelTranslator(
	input mode,
	input [5:0] in_a,
	input [5:0] in_b,
	output reg [11:0] out_a,
	output reg [11:0] out_b
);
	integer i;
	always @(*) begin
		if (mode) begin
			for (i = 0; i < 6; i = i + 2) begin
				out_a[2*i +: 4] = {2{in_a[i +: 2]}};
				out_b[2*i +: 4] = {2{in_b[i +: 2]}};
			end
		end
		else begin
			for (i = 0; i < 6; i = i + 1) begin
				out_a[2*i +: 2] = {1'b0, in_a[i]};
				out_b[2*i +: 2] = {1'b1, in_b[i]};
			end
		end
	end
endmodule

module VideoGenerator(
	input clk,
	input rst,
	output [13:0] addr,
	input [11:0] data,
	output [11:0] video_rgb,
	output video_hsync,
	output reg video_vsync
);
	assign addr = 14'b0;
	
	reg [9:0] vga_x; // x = 0.1023
	reg [9:0] vga_y; // y = 0..624
	
	wire [5:0] x_block_start = 6'o00;
	wire [3:0] x_pixel_start = 4'o00;
	wire [5:0] y_block_start = 6'o00;
	wire [3:0] y_pixel_start = 4'o00;
	
	reg [5:0] x_block; // x_block = 0..63
	wire [5:0] x_block_next = x_block + 6'd1;
	reg [3:0] x_pixel; // x_pixel = 0..11
	reg [5:0] y_block_base; // y_block = 0..47
	reg [3:0] y_pixel_base; // y_pixel = 0..11
	wire [5:0] y_block;
	wire [3:0] y_pixel;
	
	reg [11:0] video_color;
	wire vga_y_wrap = (vga_y == 624);
	wire [9:0] next_vga_y = vga_y_wrap ? 10'd0 : (vga_y + 10'd1);
	wire video_vsync_line = (vga_y >= 571) & (vga_y < 573);
	wire video_active = (vga_x >= 304) & (vga_y < 540);
	assign video_hsync = (vga_x >= 64) & (vga_x < 136);
	assign video_rgb = video_color & {12{video_active}};
	
	reg [7:0] scmem_addr;
	wire [11:0] scmem_data_in = 12'b0;
	wire scmem_write = 1'b0;
	wire [11:0] scmem_data_out;	
	reg [11:0] pixels;
	
	BlockPosAdder y_pos_adder(
		.p1_block(y_block_base),
		.p1_pixel(y_pixel_base),
		.p2_block(y_block_start),
		.p2_pixel(y_pixel_start),
		.q_block(y_block),
		.q_pixel(y_pixel)
	);
	
	VideoScanlineMemory scmem(
		.address(scmem_addr),
		.clock(clk),
		.data(scmem_data_in),
		.wren(scmem_write),
		.q(scmem_data_out)
	);
	
	always @(posedge clk or negedge rst) begin : vga_timing
		if (!rst) begin
			vga_x <= 10'b0;
			vga_y <= 10'b0;
		end
		else begin
			vga_x <= vga_x + 10'b1;
			if (vga_x == 1023) begin
				vga_y <= next_vga_y;
			end
			if (vga_x == 63) begin
				video_vsync <= video_vsync_line;
			end
		end
	end
	
	always @(posedge clk or negedge rst) begin : block_pixel_coords
		if (!rst) begin
		end
		else begin
			if (vga_x == 289) begin
				x_pixel <= x_pixel_start;
				x_block <= x_block_start - 6'd1;
			end
			else if (x_pixel >= 11) begin
				x_pixel <= 4'b0;
				x_block <= x_block + 6'b1;
			end
			else begin
				x_pixel <= x_pixel + 4'b1;
			end
			if (vga_x == 1023) begin
				if (vga_y_wrap) begin
					y_block_base <= 6'b0;
					y_pixel_base <= 4'b0;
				end
				else if (y_pixel_base >= 11) begin
					y_block_base <= y_block_base + 6'b1;
					y_pixel_base <= 4'b0;
				end
				else begin
					y_pixel_base <= y_pixel_base + 4'b1;
				end
			end
		end
	end
	
	always @(*) begin : scmem_addressing
		scmem_addr = 8'b0;
		if (vga_x >= 290) begin
			if (~x_pixel[0]) begin
				scmem_addr = {1'b0, x_block[5:1], pixels[2 * x_pixel[3:1] +: 2]};
			end
			else if (x_pixel == 9) begin
				scmem_addr = {2'b10, x_block_next};
			end
		end
	end

	always @(posedge clk) begin : scmem_display
		if (x_pixel[0]) begin
			video_color <= scmem_data_out;
		end
		else if (x_pixel == 10) begin
			pixels <= scmem_data_out;
		end
	end
endmodule
