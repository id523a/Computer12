module InstructionDecoder(
	input [11:0] instr,
	output conditional,
	output reg [4:0] dest_reg,
	output reg [4:0] src_reg,
	output reg [4:0] alu_op,
	output reg [3:0] alu_cond,
	output reg read_dest,
	output reg read_src,
	output reg write_dest,
	output reg has_immediate,
	output reg mem_read,
	output reg mem_write,
	output reg [1:0] mem_base,
	output reg [3:0] mem_offset,
	output reg mem_post_increment,
	output reg mem_pre_decrement
);

	// Classify opcode type
	wire is_arithmetic = instr[10:9] != 2'b11;
	wire is_shift = instr[10:7] == 4'b1100;
	wire is_flg = is_shift & (instr[6:3] == 4'b1101);
	wire is_load_store = instr[10:8] == 3'b111;
	wire is_load = is_load_store & ~instr[11];
	wire is_store = is_load_store & instr[11];
	wire is_special_reg = instr[5:0] < 6'o12;
	assign conditional = instr[11] & (is_arithmetic | is_shift);
	
	always @(*) begin : decode_alu
		alu_op = 5'o00;
		alu_cond = 0;
		has_immediate = 0;
		read_dest = 0;
		read_src = 1;
		write_dest = 1;
		if (is_arithmetic) begin
			dest_reg = {1'b0, instr[10], instr[5:3]};
			src_reg = {1'b0, instr[9], instr[2:0]};
			alu_op = {2'b00, instr[8:6]};
			has_immediate = (src_reg == 5'o07);
			read_dest = alu_op != 5'o00;
		end
		else if (is_flg) begin
			dest_reg = 5'o37;
			src_reg = 5'o37;
		end
		else if (is_shift) begin
			dest_reg = instr[3:0];
			src_reg = instr[3:0];
			alu_op = {2'b01, instr[6:4]};
		end
		else if (is_load) begin // lda/ldb/ldc/ldd
			dest_reg = {3'b000, instr[7:6]};
			src_reg = {1'b1, instr[3:0]};
			read_src = is_special_reg;
		end
		else if (is_store) begin // sta/stb/stc/std
			dest_reg = {1'b1, instr[3:0]};
			src_reg = {3'b000, instr[7:6]};
			write_dest = is_special_reg;
		end
		else begin // if/ifa/ifo/ifx
			dest_reg = {1'b0, instr[3:0]};
			src_reg = {1'b0, instr[3:0]};
			alu_op = {1'b1, instr[11], instr[6], instr[5:4]};
			alu_cond = instr[3:0];
			write_dest = 0;
		end
	end

	always @(*) begin : decode_mem
		mem_read = is_load & ~is_special_reg;
		mem_write = is_store & ~is_special_reg;
		mem_base = 0;
		mem_offset = 0;
		mem_post_increment = 0;
		mem_pre_decrement = 0;
		if (is_load_store & ~is_special_reg) begin
			casez (instr[5:0])
				6'o12: begin mem_base = 2'b01; mem_post_increment = 1; end
				6'o13: begin mem_base = 2'b01; mem_pre_decrement = 1; end
				6'o14: begin mem_base = 2'b10; mem_post_increment = 1; end
				6'o15: begin mem_base = 2'b10; mem_pre_decrement = 1; end
				6'o16: begin mem_base = 2'b11; mem_post_increment = 1; end
				6'o17: begin mem_base = 2'b11; mem_pre_decrement = 1; end
				default: begin mem_base = instr[5:4]; mem_offset = instr[3:0]; end
			endcase
		end
	end
endmodule

`timescale 1ns/1ps
module InstructionDecoder_test();
	reg [11:0] instr;
	wire conditional;
	wire [4:0] dest_reg;
	wire [4:0] src_reg;
	wire [4:0] alu_op;
	wire [3:0] alu_cond;
	wire read_dest;
	wire read_src;
	wire write_dest;
	wire has_immediate;
	wire mem_read;
	wire mem_write;
	wire [1:0] mem_base;
	wire [3:0] mem_offset;
	wire mem_post_increment;
	wire mem_pre_decrement;
	InstructionDecoder DUT(
		.instr(instr),
		.conditional(conditional),
		.dest_reg(dest_reg),
		.src_reg(src_reg),
		.alu_op(alu_op),
		.alu_cond(alu_cond),
		.read_dest(read_dest),
		.read_src(read_src),
		.write_dest(write_dest),
		.has_immediate(has_immediate),
		.mem_read(mem_read),
		.mem_write(mem_write),
		.mem_base(mem_base),
		.mem_offset(mem_offset),
		.mem_post_increment(mem_post_increment),
		.mem_pre_decrement(mem_pre_decrement)
	);
	initial begin
		instr = 0;
		repeat (4096) begin
			#10 instr = instr + 1;
		end
		#100
		instr = 0;
	end
endmodule
