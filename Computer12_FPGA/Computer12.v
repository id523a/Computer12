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
	wire rst_async = rst_in & pll_locked;
	wire clk;
	MainPLL main_pll_1(
		.areset(1'b0),
		.inclk0(clk50),
		.c0(clk),
		.locked(pll_locked)
	);
	
	reg rst_sync1 = 1'b0, rst = 1'b0;
	
	always @(posedge clk or negedge rst_async) begin
		if (!rst_async) begin
			{rst, rst_sync1} <= 2'b0;
		end
		else begin
			{rst, rst_sync1} <= {rst_sync1, 1'b1};
		end
	end
	
	wire [23:0] proc_mem_addr;
	wire [11:0] proc_p2m_data;
	reg [11:0] proc_m2p_data;
	wire proc_mem_write;
	
	wire [11:0] proc_pmem_data;
	wire [11:0] proc_vmem_data;
	
	wire pmem_activate = (proc_mem_addr >= 24'o00004000) && (proc_mem_addr < 24'o00100000);
	wire vmem_activate = (proc_mem_addr >= 24'o00100000) && (proc_mem_addr < 24'o00140000);
	wire kbd_activate = proc_mem_addr == 24'o00003000;
	reg pmem_active = 1'b0;
	reg vmem_active = 1'b0;
	reg kbd_active = 1'b0;
	
	wire [13:0] vgen_addr;
	wire [11:0] vgen_data;

	wire ps2_new_scancode;
	wire [7:0] ps2_scancode;
	
	tri0 [23:0] irq;
	
	always @(posedge clk) begin
		pmem_active <= pmem_activate;
		vmem_active <= vmem_activate;
		kbd_active <= kbd_activate;
	end
	
	always @(*) begin : memory_mux
		proc_m2p_data = 12'b0;
		if (pmem_active) begin
			proc_m2p_data = proc_pmem_data;
		end
		else if (vmem_active) begin
			proc_m2p_data = proc_vmem_data;
		end
		else if (kbd_active) begin
			proc_m2p_data = {4'b0, ps2_scancode};
		end
	end
	
	assign irq[0] = ps2_new_scancode;
	
	Processor12 CPU(
		.clk(clk),
		.rst(rst),
		.irq(irq),
		.mem_ready(1'b1),
		.data_in(proc_m2p_data),
		.data_out(proc_p2m_data),
		.address(proc_mem_addr),
		.mem_write(proc_mem_write)
	);
	defparam CPU.IP0_init = 24'o00010000;
	defparam CPU.IP1_init = 24'o00004000;
	
	RAM32k pmem(
		.clock(clk),
		.address(proc_mem_addr[14:0]),
		.data(proc_p2m_data),
		.wren(proc_mem_write & pmem_active),
		.q(proc_pmem_data)
	);

	VideoRAM vmem(
		.clock(clk),
		.address_a(proc_mem_addr[13:0]),
		.data_a(proc_p2m_data),
		.wren_a(proc_mem_write & vmem_active),
		.q_a(proc_vmem_data),
		.address_b(vgen_addr),
		.data_b(12'b0),
		.wren_b(1'b0),
		.q_b(vgen_data)
	);
	
	VideoGenerator vgen(
		.clk(clk),
		.rst(1'b1),
		.vmem_addr(vgen_addr),
		.vmem_data(vgen_data),
		.video_rgb(video_rgb),
		.video_hsync(video_hsync),
		.video_vsync(video_vsync)
	);
	
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
	assign blinkenlights = proc_mem_addr[7:0];
endmodule

`timescale 1ns/1ps
module Computer12_test();
	reg clk50 = 1'b0;
	wire [7:0] blinkenlights;
	initial repeat (10000) begin
		#20 clk50 = ~clk50;
	end
	Computer12 DUT(
		.clk50(clk50),
		.rst_in(1'b1),
		.blinkenlights(blinkenlights)
	);
endmodule
