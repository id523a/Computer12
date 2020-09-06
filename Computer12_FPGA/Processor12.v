module Processor12(
	input clk,
	input rst,
	input [23:0] irq,
	input [11:0] data_in,
	output [11:0] data_out,
	output reg [23:0] address,
	output reg mem_read,
	output reg mem_write
);
	wire processor_run = 1'b1;
	reg [2:0] state;
	reg [23:0] IP, AP, BP, CP;
	wire [23:0] IP_next;
	reg [11:0] A, B, C, D, E, F, G, IPH_temp, IPL_temp;
	
	// bit 5 of regfile_addr_read indicates whether the register is a destination (0) or a source (1)
	wire [5:0] regfile_addr_read;
	reg [11:0] regfile_read_value;
	wire [11:0] regfile_write_value;
	wire read_IP;
	
	reg [11:0] instr_store;
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

	reg [2:0] flags_only_ctr;
	reg [4:0] flags;
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
	
	always @(IP, A, B, C, D, AP, flags_only_ctr, flags) begin : monitor_registers
		reg [39:0] flags_display;
		flags_display[39:32] = flags[0] ? "Z" : " ";
		flags_display[31:24] = flags[1] ? "S" : " ";
		flags_display[23:16] = flags[2] ? "K" : " ";
		flags_display[15:8]  = flags[3] ? "V" : " ";
		flags_display[7:0]   = flags[4] ? "P" : " ";
		$strobe("%dps: IP=%o A=%o B=%o C=%o D=%o AP=%o FO=%o %s", $time, IP, A, B, C, D, AP, flags_only_ctr, flags_display);
	end
	
	always @(posedge clk or negedge rst) begin : state_counter
		if (!rst) begin
			state <= 3'b000;
		end
		else begin
			if (state[0] & processor_run)
				state <= 3'b010;
			else if (state[1])
				state <= 3'b100;
			else
				state <= 3'b001;
		end
	end
	
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
		mem_read = 1;
		mem_write = 0;
		if (state[0]) begin
			address = IP;
		end
		if (state[1]) begin
			address = instr_has_immediate ? IP : data_address;
			mem_read = instr_has_immediate | exec_mem_read;
		end
		if (state[2]) begin
			address = data_address;
			mem_read = 0;
			mem_write = exec_mem_write;
		end
	end
	
	assign instr = state[1] ? data_in : instr_store;
	assign IP_next = IP + 24'b1;
	always @(posedge clk or negedge rst) begin : instruction_fetch
		if (!rst) begin
			IP <= 0;
			instr_store <= 0;
		end
		else begin
			if (state[0] & processor_run) begin
				IP <= IP_next;
			end
			else if (state[1]) begin
				if (instr_has_immediate) begin
					IP <= IP_next;
				end
				instr_store <= data_in;
			end
			else if (state[2] & (instr_dest_reg == 5'b01111) & exec_write_dest) begin
				IP <= {regfile_write_value, IPL_temp};
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
			6'bz01111: regfile_read_value = IPH_temp;
			
			default: regfile_read_value = 12'o0000;
		endcase
	end
	
	always @(posedge clk or negedge rst) begin : assign_alu_temp
		if (!rst) begin
			alu_temp <= 12'b0;
		end
		else if (state[1]) begin
			alu_temp <= regfile_read_value;
		end
	end
	
	assign read_IP = (instr_dest_reg == 5'b01110 && exec_read_dest) || (instr_src_reg == 5'b01110 && exec_read_src);
	always @(posedge clk or negedge rst) begin : register_file_write
		if (!rst) begin
			{A, B, C, D, E, F, G} <= 0;
			{IPH_temp, IPL_temp} <= 0;
			{AP, BP, CP} <= 0;
			flags <= 5'b0;
		end
		else if (state[2]) begin
			if (read_IP) begin
				IPH_temp <= IP[23:12];
			end
			if (instr_execute) begin
				flags <= alu_flags_out;
			end
			if (exec_write_dest) begin
				casez (instr_dest_reg)
					5'b00000: A <= regfile_write_value;
					5'b00001: B <= regfile_write_value;
					5'b00010: C <= regfile_write_value;
					5'b00011: D <= regfile_write_value;
					5'b00100: E <= regfile_write_value;
					5'b00101: F <= regfile_write_value;
					5'b00110: G <= regfile_write_value;
					/* 5'b00111: do nothing */
					5'b01000: AP[11:0] <= regfile_write_value;
					5'b01001: AP[23:12] <= regfile_write_value;
					5'b01010: BP[11:0] <= regfile_write_value;
					5'b01011: BP[23:12] <= regfile_write_value;
					5'b01100: CP[11:0] <= regfile_write_value;
					5'b01101: CP[23:12] <= regfile_write_value;
					5'b01110: IPL_temp <= regfile_write_value;
					/* 5'b01111: Write to instruction pointer */
				endcase
			end
			if (exec_mem_modify_address) begin
				case (instr_mem_base)
					2'b01: AP <= data_address_next;
					2'b10: BP <= data_address_next;
					2'b11: CP <= data_address_next;
				endcase
			end
		end
	end
	
	always @(posedge clk or negedge rst) begin : handle_flags_only_count
		if (!rst) begin
			flags_only_ctr <= 3'o0;
		end
		else if (state[2]) begin
			if (instr_execute & instr_write_dest & instr_dest_reg == 5'b11111) begin
				flags_only_ctr <= instr[2:0];
			end
			else begin
				flags_only_ctr <= flags_only ? (flags_only_ctr - 3'o1) : 3'o0;
			end
		end
	end
	
	assign data_out = (state[2] & exec_mem_write) ? regfile_write_value : 12'b0;
endmodule

`timescale 1ns/1ps
module Processor12_test();
	reg clk;
	reg rst;
	wire [11:0] data_m2p;
	wire [11:0] data_p2m;
	wire mem_write;
	wire [23:0] address;
	
	TestMemory testMem(
		.clock(clk),
		.address(address[11:0]),
		.data(data_p2m),
		.wren(mem_write),
		.q(data_m2p)
	);

	Processor12 DUT(
		.clk(clk),
		.rst(rst),
		.irq(24'b0),
		.data_in(data_m2p),
		.data_out(data_p2m),
		.address(address),
		.mem_write(mem_write)
	);
	initial begin
		clk = 0;
		repeat (1000) begin
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
