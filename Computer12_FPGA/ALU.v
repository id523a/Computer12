module ALU(
	input [11:0] A,
	input [11:0] B,
	input [4:0] operation,
	input [3:0] condition,
	input [3:0] flg_in,
	output reg [11:0] Q,
	output [3:0] flg_out
);
	// Flag outputs
	reg Z_out; // flag[0] = zero flag
	reg S_out; // flag[1] = sign flag
	reg K_out; // flag[2] = carry flag
	reg V_out; // flag[3] = overflow flag
	reg P_out; // flag[4] = predicate flag
	assign flg_out = {P_out, V_out, K_out, S_out, Z_out};
	
	// Compute arithmetic/logic operation, and carry flag (Q, K)
	wire K_in = flg_in[2];
	always @(*) begin : compute_operation_carry
		K_out = K_in;
		case (operation)
			5'h01: /*AND*/ Q = A & B;
			5'h02: /*OR */ Q = A | B;
			5'h03: /*XOR*/ Q = A ^ B;
			5'h04: /*ADD*/ {K_out, Q} = {1'b0, A} + B;
			5'h05: /*ADK*/ {K_out, Q} = {1'b0, A} + B + K_in;
			5'h06: /*SUB*/ {K_out, Q} = {1'b0, A} - B;
			5'h07: /*SBK*/ {K_out, Q} = {1'b0, A} - B - K_in;
			5'h08: /*ROL*/ Q = {B[10:0], B[11]};
			5'h09: /*ROR*/ Q = {B[0], B[11:1]};
			5'h0a: /*RKL*/ {K_out, Q} = {B, K_in};
			5'h0b: /*RKR*/ {Q, K_out} = {K_in, B};
			5'h0c: /*SHL*/ {K_out, Q} = {B, 1'b0};
			5'h0d: /*SHR*/ {Q, K_out} = {1'b0, B};
			5'h0e: /*SWP*/ Q = {B[5:0], B[11:6]};
			5'h0f: /*ASR*/ {Q, K_out} = {B[11], B};
			default: /*MOV*/ Q = B;
		endcase
	end
	
	// Compute zero and sign flags (Z, S)
	wire result_zero = (Q == 0);
	always @(*) begin : compute_zero_sign
		if (operation == 5'h00 || operation[4] == 1'b1) begin
			Z_out = flg_in[0];
			S_out = flg_in[1];
		end
		else begin
			Z_out = result_zero;
			S_out = Q[11];
		end
	end
	
	// Compute overflow flag (V)
	always @(*) begin : compute_overflow
		if (operation[3:2] == 2'b00 || operation[4] == 1'b1) begin
			V_out = flg_in[3];
		end
		else begin
			V_out = (A[11] & B[11] & ~Q[11]) | (~A[11] & ~B[11] & Q[11]);
		end
	end
	
	// Compute condition based on flags
	reg cond_value;
	always @(*) begin : compute_cond_value
		case (condition)
			4'h0: cond_value = flg_in[0]; // Z flag / equal
			4'h1: cond_value = flg_in[1]; // S flag
			4'h2: cond_value = flg_in[2]; // K flag / unsigned a<b
			4'h3: cond_value = flg_in[3]; // V flag
			// Reserved: 4'h4 - 4'h7
			4'h8: cond_value = ~flg_in[0] & ~flg_in[2]; // Z clear and K clear / unsigned a>b
			4'h9: cond_value = flg_in[1] ^ flg_in[3]; // S xor V / signed a<b
			4'ha: cond_value = ~flg_in[0] & ~(flg_in[1] ^ flg_in[3]); // signed a>b
			// Reserved: 4'hb - 4'he
			default: cond_value = 1'b1;
		endcase
	end
	
	// Compute predicate flag (P)
	// operation[4] indicates that the operation modifies the condition
	// operation[3] indicates whether the condition is (0) based on flags or (1) result_zero
	// operation[2] indicates whether to invert the value
	// operation[1:0] indicates how this is combined with the existing value of the P flag
	wire cond_op3 = operation[3] ? result_zero : cond_value;
	wire cond_op2 = operation[2] ^ cond_op3;
	wire P_in = flg_in[4];
	always @(*) begin : compute_p_flag
		if (operation[4] == 1'b0) begin
			P_out = P_in;
		end
		else begin
			case (operation[1:0])
				2'b00: P_out = cond_op2;
				2'b01: P_out = P_in ^ cond_op2;
				2'b10: P_out = P_in & cond_op2;
				2'b11: P_out = P_in | cond_op2;
			endcase
		end
	end
endmodule
