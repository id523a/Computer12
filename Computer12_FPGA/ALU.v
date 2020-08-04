module ALU(
	input [11:0] A,
	input [11:0] B,
	input [3:0] operation,
	input [3:0] flg_in,
	output reg [11:0] Q,
	output [3:0] flg_out
);
	// Flag outputs
	reg Z_out;
	reg S_out;
	reg K_out;
	reg V_out;
	assign flg_out = {V_out, K_out, S_out, Z_out};
	// Handle result and carry flag
	wire K_in = flg_in[2];
	always @(*) begin
		K_out = K_in;
		case (operation)
			4'h1: /*AND*/ Q = A & B;
			4'h2: /*OR */ Q = A | B;
			4'h3: /*XOR*/ Q = A ^ B;
			4'h4: /*ADD*/ {K_out, Q} = {1'b0, A} + B;
			4'h5: /*ADK*/ {K_out, Q} = {1'b0, A} + B + K_in;
			4'h6: /*SUB*/ {K_out, Q} = {1'b0, A} - B;
			4'h7: /*SBK*/ {K_out, Q} = {1'b0, A} - B - K_in;
			4'h8: /*ROL*/ Q = {B[10:0], B[11]};
			4'h9: /*ROR*/ Q = {B[0], B[11:1]};
			4'ha: /*RKL*/ {K_out, Q} = {B, K_in};
			4'hb: /*RKR*/ {Q, K_out} = {K_in, B};
			4'hc: /*SHL*/ {K_out, Q} = {B, 1'b0};
			4'hd: /*SHR*/ {Q, K_out} = {1'b0, B};
			4'he: /*ASL*/ {K_out, Q} = {B, 1'b0};
			4'hf: /*ASR*/ {Q, K_out} = {B[11], B};
			default: /*MOV*/ Q = B;
		endcase
	end
	// Handle zero and sign flags
	always @(*) begin
		if (operation == 4'h0) begin
			Z_out = flg_in[0];
			S_out = flg_in[1];
		end
		else begin
			Z_out = (Q == 0);
			S_out = Q[11];
		end
	end
	// Handle overflow flag
	always @(*) begin
		if (operation[3:2] == 2'b00) begin
			V_out = flg_in[3];
		end
		else begin
			V_out = (A[11] & B[11] & ~Q[11]) | (~A[11] & ~B[11] & Q[11]);
		end
	end
endmodule
