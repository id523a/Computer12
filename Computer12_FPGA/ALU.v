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
	reg Z_out;
	reg S_out;
	reg K_out;
	reg V_out;
	reg P_out;
	assign flg_out = {P_out, V_out, K_out, S_out, Z_out};
	// Handle result and carry flag
	wire K_in = flg_in[2];
	always @(*) begin
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
	// Handle zero and sign flags
	wire result_zero = (Q == 0);
	always @(*) begin
		if (operation == 5'h00 || operation[4] == 1'b1) begin
			Z_out = flg_in[0];
			S_out = flg_in[1];
		end
		else begin
			Z_out = result_zero;
			S_out = Q[11];
		end
	end
	// Handle overflow flag
	always @(*) begin
		if (operation[3:2] == 2'b00 || operation[4] == 1'b1) begin
			V_out = flg_in[3];
		end
		else begin
			V_out = (A[11] & B[11] & ~Q[11]) | (~A[11] & ~B[11] & Q[11]);
		end
	end
	// Handle predicate
	always @(*) begin
		if (operation[4] == 1'b0) begin
			P_out = flg_in[4];
		end
		else begin
			P_out = 1'b0;
		end
	end
endmodule
