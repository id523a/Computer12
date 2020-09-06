module VideoGenerator(
	input clk,
	input rst,
	output [13:0] addr,
	input [11:0] data,
	output [11:0] video_rgb,
	output video_hsync,
	output video_vsync
);
	assign addr = 14'b0;
	
	reg [9:0] x; // x = 0.1023
	reg [9:0] y; // y = 0..624
	
	wire y_wrap = (y == 624);
	wire [9:0] next_y = y_wrap ? 0 : (y + 1);
	
	wire [11:0] video_color = x == y ? 12'h69E : 12'h347;
	
	assign video_hsync = (x >= 784) & (x < 856);
	assign video_vsync = (y >= 571) & (y < 573);
	wire video_active = (x < 720) & (y < 540);
	assign video_rgb = video_color & {12{video_active}};

	always @(posedge clk or negedge rst) begin
		if (!rst) begin
			x <= 10'b0;
			y <= 10'b0;
		end
		else begin
			x <= x + 1;
			if (x == 783) begin
				y <= next_y;
			end
		end
	end
	
endmodule
