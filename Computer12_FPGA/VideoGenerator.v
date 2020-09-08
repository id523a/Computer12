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
	output reg [13:0] vmem_addr,
	input [11:0] vmem_data,
	output [11:0] video_rgb,
	output video_hsync,
	output reg video_vsync
);
	
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
	reg [11:0] scmem_data_in;
	reg scmem_write = 1'b0;
	wire [11:0] scmem_data_out;	
	reg [11:0] disp_pixels;
	
	reg [23:0] palette_indices;
	reg [5:0] read_pixels_a;
	reg [5:0] read_pixels_b;
	wire [11:0] read_pixels_dec_a;
	wire [11:0] read_pixels_dec_b;
	
	wire color_mode = 1'b0;
	
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
	
	PixelTranslator px_trans(
		.mode(color_mode),
		.in_a(read_pixels_a),
		.in_b(read_pixels_b),
		.out_a(read_pixels_dec_a),
		.out_b(read_pixels_dec_b)
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
	
	wire [4:0] prev_read_block = vga_x[7:3] - 5'b1;
	
	always @(*) begin : scmem_addressing
		scmem_addr = 8'b0;
		scmem_write = 1'b0;
		scmem_data_in = 12'b0;
		if (vga_x >= 290) begin
			if (~x_pixel[0]) begin
				scmem_addr = {1'b0, x_block[5:1], disp_pixels[2 * x_pixel[3:1] +: 2]};
			end
			else if (x_pixel == 9) begin
				scmem_addr = {2'b10, x_block_next};
			end
		end
		else if (vga_x <= 256 & ~vga_y[0]) begin
			case (vga_x[2:0])
				3'b011: begin // Store pixel data 0
					scmem_write = 1'b1;
					scmem_addr = {2'b10, vga_x[7:3], 1'b0};
					scmem_data_in = read_pixels_dec_a;
				end
				3'b100: begin // Store pixel data 1
					scmem_write = 1'b1;
					scmem_addr = {2'b10, vga_x[7:3], 1'b1};
					scmem_data_in = read_pixels_dec_b;
				end
				3'b101: begin // Store palette color 0
					scmem_write = 1'b1;
					scmem_addr = {1'b0, vga_x[7:3], 2'b00};
					scmem_data_in = vmem_data;
				end
				3'b110: begin // Store palette color 1
					scmem_write = 1'b1;
					scmem_addr = {1'b0, vga_x[7:3], 2'b01};
					scmem_data_in = vmem_data;
				end
				3'b111: begin // Store palette color 2
					scmem_write = 1'b1;
					scmem_addr = {1'b0, vga_x[7:3], 2'b10};
					scmem_data_in = vmem_data;
				end
				3'b000: begin // Store palette color 3
					scmem_write = 1'b1;
					scmem_addr = {1'b0, prev_read_block, 2'b11};
					scmem_data_in = vmem_data;
				end
				default: scmem_write = 1'b0;
			endcase
		end
	end

	always @(posedge clk) begin : scmem_display
		if (x_pixel[0]) begin
			video_color <= scmem_data_out;
		end
		else if (x_pixel == 10) begin
			disp_pixels <= scmem_data_out;
		end
	end
	
	always @(*) begin : vmem_addressing
		vmem_addr = 14'b0;
		if (vga_x <= 256 & ~vga_y[0]) begin
			casez (vga_x[2:0])
			3'b000: vmem_addr = {y_block, vga_x[7:3], 1'b0, y_pixel[3:2]};
			3'b001: vmem_addr = {y_block, vga_x[7:3], 1'b1, y_pixel[3:2]};
			3'b010: vmem_addr = {y_block, vga_x[7:3], 3'b011};
			3'b011: vmem_addr = {y_block, vga_x[7:3], 3'b111};
			3'b1zz: vmem_addr = {8'b11000000, palette_indices[6 * vga_x[1:0] +: 6]};
			endcase
		end
	end
	
	always @(posedge clk) begin : vmem_store_results
		if (vga_x <= 256 & ~vga_y[0]) begin
			casez (vga_x[2:0])
			3'b001: read_pixels_a <= vmem_data[6 * y_pixel[1] +: 6];
			3'b010: read_pixels_b <= vmem_data[6 * y_pixel[1] +: 6];
			3'b011: palette_indices[11:0] <= vmem_data;
			3'b100: palette_indices[23:12] <= vmem_data;
			endcase
		end
	end
endmodule
