module SyncLatch #(
	parameter WIDTH = 1
) (
	input clk,
	input [WIDTH-1:0] d,
	input enable,
	output [WIDTH-1:0] q
);
	reg [WIDTH-1:0] data_store;
	assign q = enable ? d : data_store;
	always @(posedge clk) begin
		if (enable) data_store <= d;
	end
endmodule

module Processor12(
	input clk,
	input rst,
	input tri0 [23:0] irq,
	input tri1 mem_ready,
	input [11:0] data_in,
	output [11:0] data_out,
	output reg [23:0] address,
	output reg mem_read,
	output reg mem_write
);
	parameter [23:0] IP0_init = 24'o00000000;
	parameter [23:0] IP1_init = 24'o00000000;
	
	wire processor_mode;
	reg [2:0] state;
	reg [23:0] IP0, IP1, AP, BP0, BP1, CP0, CP1;
	wire [23:0] IP = processor_mode ? IP1 : IP0;
	wire [23:0] BP = processor_mode ? BP1 : BP0;
	wire [23:0] CP = processor_mode ? CP1 : CP0;
	wire [23:0] IP_next;
	reg [11:0] A0, A1, B0, B1, C, D, E, F, G;
	wire [11:0] A = processor_mode ? A1 : A0;
	wire [11:0] B = processor_mode ? B1 : B0;
	reg [11:0] IPH_temp0, IPH_temp1, IPL_temp0, IPL_temp1;
	
	// bit 5 of regfile_addr_read indicates whether the register is a destination (0) or a source (1)
	wire [5:0] regfile_addr_read;
	reg [11:0] regfile_read_value;
	wire [11:0] regfile_write_value;
	wire read_IP;
	
	wire [11:0] instr;
	wire instr_conditional;
	wire instr_has_immediate;
	wire instr_mem_read;
	wire instr_mem_write;
	wire [1:0] instr_mem_base;
	wire [3:0] instr_mem_offset;
	wire instr_mem_post_inc, instr_mem_pre_dec;
	wire [4:0] instr_dest_reg;
	wire instr_read_dest, instr_read_src, instr_write_dest;
	wire [4:0] instr_src_reg;
	wire [4:0] instr_alu_op;
	wire [3:0] instr_alu_cond;

	reg [2:0] flags_only_ctr0, flags_only_ctr1;
	wire [2:0] flags_only_ctr = processor_mode ? flags_only_ctr1 : flags_only_ctr0;
	reg [4:0] flags0, flags1;
	wire [4:0] flags = processor_mode ? flags1 : flags0;
	wire [4:0] alu_flags_out;
	reg [11:0] alu_temp;

	reg [23:0] data_address;
	reg [23:0] data_address_next;
	
	wire flags_only = |flags_only_ctr;
	wire instr_execute = flags[4] | ~instr_conditional;
	wire exec_read_dest = instr_read_dest & instr_execute;
	wire exec_read_src = instr_read_src & instr_execute;
	wire exec_write_dest = instr_write_dest & ~flags_only & instr_execute;
	wire exec_mem_read = instr_mem_read & ~flags_only;
	wire exec_mem_write = instr_mem_write & ~flags_only;
	wire exec_mem_modify_address = (instr_mem_post_inc | instr_mem_pre_dec) & ~flags_only;
	
	wire int_dismiss = 1'b0;
	wire int_create = 1'b0;
	wire [11:0] next_interrupt;
	
	InstructionDecoder instr_decoder_1(
		.instr(instr),
		.conditional(instr_conditional),
		.has_immediate(instr_has_immediate),
		.dest_reg(instr_dest_reg),
		.src_reg(instr_src_reg),
		.alu_op(instr_alu_op),
		.alu_cond(instr_alu_cond),
		.read_dest(instr_read_dest),
		.read_src(instr_read_src),
		.write_dest(instr_write_dest),
		.mem_read(instr_mem_read),
		.mem_write(instr_mem_write),
		.mem_base(instr_mem_base),
		.mem_offset(instr_mem_offset),
		.mem_post_increment(instr_mem_post_inc),
		.mem_pre_decrement(instr_mem_pre_dec)
	);
	
	ALU alu_1(
		.A(alu_temp),
		.B(regfile_read_value),
		.operation(instr_alu_op),
		.condition(instr_alu_cond),
		.flg_in(flags),
		.Q(regfile_write_value),
		.flg_out(alu_flags_out)
	);
	
	InterruptController #(
		.INTERRUPT_LINES(24)
	) interrupt_controller_1(
		.clk(clk),
		.rst(rst),
		.irq(irq),
		.dismiss(int_dismiss),
		.create(int_create),
		.data_in(regfile_write_value),
		.next_interrupt(next_interrupt)
	);
	
	always @(IP, processor_mode, A, B, C, D, AP, flags_only_ctr, flags) begin : monitor_registers
		reg [39:0] flags_display;
		flags_display[39:32] = flags[0] ? "Z" : " ";
		flags_display[31:24] = flags[1] ? "S" : " ";
		flags_display[23:16] = flags[2] ? "K" : " ";
		flags_display[15:8]  = flags[3] ? "V" : " ";
		flags_display[7:0]   = flags[4] ? "P" : " ";
		$strobe("%dps: M%b IP=%o A=%o B=%o C=%o D=%o AP=%o FO=%o %s", $time,
			processor_mode, IP, A, B, C, D, AP, flags_only_ctr, flags_display);
	end
	
	always @(posedge clk or negedge rst) begin : state_counter
		if (!rst) begin
			state <= 3'b000;
		end
		else if (mem_ready) begin
			if (state[0])
				state <= 3'b010;
			else if (state[1])
				state <= 3'b100;
			else
				state <= 3'b001;
		end
	end
	
	SyncLatch #(1) processor_mode_latch(
		.clk(clk),
		.d(next_interrupt < 12'o7777),
		.enable(mem_ready && state[0]),
		.q(processor_mode)
	);
	
	always @(*) begin : compute_data_address
		case (instr_mem_base)
			2'b00: data_address = 24'b0;
			2'b01: data_address = AP;
			2'b10: data_address = BP;
			2'b11: data_address = CP;
		endcase
		data_address = data_address + {20'b0, instr_mem_offset};
		if (instr_mem_pre_dec) begin
			data_address = data_address - 24'b1;
			data_address_next = data_address;
		end
		else begin
			data_address_next = data_address + 24'b1;
		end
	end
	
	always @(*) begin : memory_addressing
		address = 24'oxxxxxxxx;
		mem_read = 0;
		mem_write = 0;
		if (mem_ready) begin
			if (state[0]) begin
				address = IP;
				mem_read = 1;
			end
			if (state[1]) begin
				address = instr_has_immediate ? IP : data_address;
				mem_read = instr_has_immediate | exec_mem_read;
			end
			if (state[2]) begin
				address = data_address;
				mem_write = exec_mem_write;
			end
		end
	end

	SyncLatch #(12) instr_latch(
		.clk(clk),
		.d(data_in),
		.enable(mem_ready && state[1]),
		.q(instr)
	);
	assign IP_next = IP + 24'b1;
	always @(posedge clk or negedge rst) begin : instruction_fetch
		if (!rst) begin
			IP0 <= IP0_init;
			IP1 <= IP1_init;
		end
		else if (mem_ready) begin
			if (state[0]) begin
				if (processor_mode)
					IP1 <= IP_next;
				else
					IP0 <= IP_next;
			end
			else if (state[1]) begin
				if (instr_has_immediate) begin
					if (processor_mode)
						IP1 <= IP_next;
					else
						IP0 <= IP_next;
				end
			end
			else if (state[2] & (instr_dest_reg == 5'b01111) & exec_write_dest) begin
				if (processor_mode)
					IP1 <= {regfile_write_value, IPL_temp1};
				else
					IP0 <= {regfile_write_value, IPL_temp0};
			end
		end
	end
	
	assign regfile_addr_read[5] = state[2];
	assign regfile_addr_read[4:0] = state[2] ? instr_src_reg : instr_dest_reg;
	
	always @(*) begin : register_file_read
		if (instr_mem_read) begin
			regfile_read_value = data_in;
		end
		else casez (regfile_addr_read)
			6'bz00000: regfile_read_value = A;
			6'bz00001: regfile_read_value = B;
			6'bz00010: regfile_read_value = C;
			6'bz00011: regfile_read_value = D;
			6'bz00100: regfile_read_value = E;
			6'bz00101: regfile_read_value = F;
			6'bz00110: regfile_read_value = G;
			6'b000111: regfile_read_value = 12'o0000;
			6'b100111: regfile_read_value = (instr_has_immediate & state[2]) ? data_in : 12'o0000;
			
			6'bz01000: regfile_read_value = AP[11:0];
			6'bz01001: regfile_read_value = AP[23:12];
			6'bz01010: regfile_read_value = BP[11:0];
			6'bz01011: regfile_read_value = BP[23:12];
			6'bz01100: regfile_read_value = CP[11:0];
			6'bz01101: regfile_read_value = CP[23:12];
			6'b001110: regfile_read_value = IP_next[11:0];
			6'b101110: regfile_read_value = IP[11:0];
			6'bz01111: regfile_read_value = processor_mode ? IPH_temp1 : IPH_temp0;
			
			6'bz10000: regfile_read_value = processor_mode ? next_interrupt : 12'o7777;
			
			default: regfile_read_value = 12'o0000;
		endcase
	end
	
	always @(posedge clk or negedge rst) begin : assign_alu_temp
		if (!rst) begin
			alu_temp <= 12'b0;
		end
		else if (mem_ready && state[1]) begin
			alu_temp <= regfile_read_value;
		end
	end
	
	assign read_IP = (instr_dest_reg == 5'b01110 && exec_read_dest) || (instr_src_reg == 5'b01110 && exec_read_src);
	wire interrupt_write = mem_ready && state[2] && exec_write_dest && instr_dest_reg == 5'b10000;
	assign int_dismiss = interrupt_write && processor_mode;
	assign int_create  = interrupt_write && ~processor_mode;
	always @(posedge clk or negedge rst) begin : register_file_write
		if (!rst) begin
			{A0, A1, B0, B1, C, D, E, F, G} <= 0;
			{IPH_temp0, IPL_temp0} <= 0;
			{IPH_temp1, IPL_temp1} <= 0;
			{AP, BP0, BP1, CP0, CP1} <= 0;
			flags0 <= 5'b0;
			flags1 <= 5'b0;
		end
		else if (mem_ready && state[2]) begin
			if (read_IP) begin
				if (processor_mode)
					IPH_temp1 <= IP1[23:12];
				else
					IPH_temp0 <= IP0[23:12];
			end
			if (instr_execute) begin
				if (processor_mode)
					flags1 <= alu_flags_out;
				else
					flags0 <= alu_flags_out;
			end
			if (exec_write_dest) begin
				casez ({processor_mode, instr_dest_reg})
					6'b000000: A0 <= regfile_write_value;
					6'b100000: A1 <= regfile_write_value;
					6'b000001: B0 <= regfile_write_value;
					6'b100001: B1 <= regfile_write_value;
					6'bz00010: C <= regfile_write_value;
					6'bz00011: D <= regfile_write_value;
					6'bz00100: E <= regfile_write_value;
					6'bz00101: F <= regfile_write_value;
					6'bz00110: G <= regfile_write_value;
					/* 6'bz00111: do nothing */
					6'bz01000: AP[11:0] <= regfile_write_value;
					6'bz01001: AP[23:12] <= regfile_write_value;
					6'b001010: BP0[11:0] <= regfile_write_value;
					6'b101010: BP1[11:0] <= regfile_write_value;
					6'b001011: BP0[23:12] <= regfile_write_value;
					6'b101011: BP1[23:12] <= regfile_write_value;
					6'b001100: CP0[11:0] <= regfile_write_value;
					6'b101100: CP1[11:0] <= regfile_write_value;
					6'b001101: CP0[23:12] <= regfile_write_value;
					6'b101101: CP1[23:12] <= regfile_write_value;
					6'b001110: IPL_temp0 <= regfile_write_value;
					6'b101110: IPL_temp1 <= regfile_write_value;
					/* 6'bz01111: Write to instruction pointer */
				endcase
			end
			if (exec_mem_modify_address) begin
				casez ({processor_mode, instr_mem_base})
					3'bz01: AP <= data_address_next;
					3'b010: BP0 <= data_address_next;
					3'b110: BP1 <= data_address_next;
					3'b011: CP0 <= data_address_next;
					3'b111: CP1 <= data_address_next;
				endcase
			end
		end
	end
	
	always @(posedge clk or negedge rst) begin : handle_flags_only_count
		if (!rst) begin
			flags_only_ctr0 <= 3'o0;
			flags_only_ctr1 <= 3'o0;
		end
		else if (mem_ready & state[2]) begin
			if (instr_execute & instr_write_dest & instr_dest_reg == 5'b11111) begin
				if (processor_mode)
					flags_only_ctr1 <= instr[2:0];
				else
					flags_only_ctr0 <= instr[2:0];
			end
			else begin
				if (processor_mode)
					flags_only_ctr1 <= flags_only ? (flags_only_ctr1 - 3'o1) : 3'o0;
				else
					flags_only_ctr0 <= flags_only ? (flags_only_ctr0 - 3'o1) : 3'o0;
			end
		end
	end
	assign data_out = (state[2] & exec_mem_write) ? regfile_write_value : 12'b0;
endmodule

`timescale 1ns/1ps
module Processor12_test();
	reg clk;
	reg rst;
	reg [5:0] interrupt;
	wire [11:0] data_m2p;
	wire [11:0] data_p2m;
	wire mem_read;
	wire mem_write;
	wire [23:0] address;
	wire mem_valid;
	
	TestMemorySlow testMem(
		.clock(clk),
		.address(address[11:0]),
		.data(data_p2m),
		.wren(mem_write),
		.rden(mem_read),
		.ready(mem_valid),
		.q(data_m2p)
	);

	Processor12 DUT(
		.clk(clk),
		.rst(rst),
		.irq({18'b0, interrupt}),
		.mem_ready(mem_valid),
		.data_in(data_m2p),
		.data_out(data_p2m),
		.address(address),
		.mem_read(mem_read),
		.mem_write(mem_write)
	);
	
	defparam DUT.IP0_init = 24'o00000000;
	defparam DUT.IP1_init = 24'o00001000;
	
	initial begin
		clk = 0;
		repeat (3000) begin
			#25
			clk = 1;
			#25
			clk = 0;
		end
	end
	initial begin
		rst = 0;
		interrupt = 0;
		#125
		rst = 1;
		#15000
		interrupt = 6'b000100;
		#2
		interrupt = 6'b000000;
		#15000
		interrupt = 6'b001110;
		#2
		interrupt = 6'b000000;
	end
endmodule
