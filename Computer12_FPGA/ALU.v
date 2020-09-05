module ALU(
	input [11:0] A,
	input [11:0] B,
	input [4:0] operation,
	input [3:0] condition,
	input [4:0] flg_in,
	output reg [11:0] Q,
	output [4:0] flg_out
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
			5'o01: /*AND*/ Q = A & B;
			5'o02: /*OR */ Q = A | B;
			5'o03: /*XOR*/ Q = A ^ B;
			5'o04: /*ADD*/ {K_out, Q} = {1'b0, A} + B;
			5'o05: /*ADK*/ {K_out, Q} = {1'b0, A} + B + K_in;
			5'o06: /*SUB*/ {K_out, Q} = {1'b0, A} - B;
			5'o07: /*SBK*/ {K_out, Q} = {1'b0, A} - B - K_in;
			5'o10: /*ROL*/ Q = {B[10:0], B[11]};
			5'o11: /*ROR*/ Q = {B[0], B[11:1]};
			5'o12: /*RKL*/ {K_out, Q} = {B, K_in};
			5'o13: /*RKR*/ {Q, K_out} = {K_in, B};
			5'o14: /*SHL*/ {K_out, Q} = {B, 1'b0};
			5'o15: /*SHR*/ {Q, K_out} = {1'b0, B};
			5'o16: /*SWP*/ Q = {B[5:0], B[11:6]};
			5'o17: /*ASR*/ {Q, K_out} = {B[11], B};
			default: /*MOV*/ Q = B;
		endcase
	end
	
	// Compute zero and sign flags (Z, S)
	wire result_zero = (Q == 0);
	always @(*) begin : compute_zero_sign
		if (operation == 5'o00 || operation[4] == 1'b1) begin
			Z_out = flg_in[0];
			S_out = flg_in[1];
		end
		else begin
			// For ADK and SBK, zero flag can only be cleared, not set
			if (operation == 5'o05 | operation == 5'o07) begin
				Z_out = flg_in[0] & result_zero;
			end
			else begin
				Z_out = result_zero;
			end
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
			4'o00: cond_value = flg_in[0]; // Z flag / equal
			4'o01: cond_value = flg_in[1]; // S flag
			4'o02: cond_value = flg_in[2]; // K flag / unsigned a<b
			4'o03: cond_value = flg_in[3]; // V flag
			// Reserved: 4'o04 - 4'o07
			4'o10: cond_value = ~flg_in[0] & ~flg_in[2]; // Z clear and K clear / unsigned a>b
			4'o11: cond_value = flg_in[1] ^ flg_in[3]; // S xor V / signed a<b
			4'o12: cond_value = ~flg_in[0] & ~(flg_in[1] ^ flg_in[3]); // signed a>b
			// Reserved: 4'o13 - 4'o17
			default: cond_value = 1'b1;
		endcase
	end
	
	// Compute predicate flag (P)
	// operation[4] indicates that the operation modifies the condition
	// operation[0] indicates whether the condition is (0) result_zero or (1) based on flags
	// operation[1] indicates whether to invert the value
	// operation[3:2] indicates how the condition is combined with the existing value of the P flag

	
	wire cond_op0 = operation[0] ? cond_value : result_zero;
	wire cond_op1 = operation[1] ^ cond_op0;
	wire P_in = flg_in[4];
	always @(*) begin : compute_p_flag
		if (operation[4] == 1'b0) begin
			P_out = P_in;
		end
		else begin
			case (operation[3:2])
				2'b00: P_out = cond_op1;
				2'b01: P_out = P_in ^ cond_op1;
				2'b10: P_out = P_in & cond_op1;
				2'b11: P_out = P_in | cond_op1;
			endcase
		end
	end
endmodule
