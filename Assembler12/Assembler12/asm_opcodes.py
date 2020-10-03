from asm_state import *

def assemble_mov(state, opcode, args):
    dests = []
    srcs = []
    immediate_value = 0
    before_comma = True
    use_immediate_value = False
    immediate_value_defer = False
    for token_type, value in args:
        if before_comma:
            if token_type is TokenType.REG:
                dests.append(value)
            elif token_type is TokenType.DOUBLE_REG:
                dests.extend(value)
            elif token_type is TokenType.COMMA:
                before_comma = False
            else:
                assembler_state.error(AssemblerError(f'Unexpected {token_type.name} in first argument of {opcode} instruction.'))
                return
        elif not use_immediate_value:
            if token_type in (TokenType.NUMBER, TokenType.IDENTIFIER):
                if len(srcs) == 0:
                    immediate_value = value
                    use_immediate_value = True
                    immediate_value_defer = (token_type is TokenType.IDENTIFIER)
                else:
                    assembler_state.error(AssemblerError(f'Unexpected {token_type.name}. Registers and immediate values cannot be mixed in the second argument of a {opcode}.'))
                    return
            elif token_type is TokenType.REG:
                srcs.append(value)
            elif token_type is TokenType.DOUBLE_REG:
                srcs.extend(value)
            elif token_type is TokenType.COMMA:
                assembler_state.error(AssemblerError(f'Unexpected {token_type.name}. {opcode} takes exactly two arguments.'))
                return
            else:
                assembler_state.error(AssemblerError(f'Unexpected {token_type.name} in second argument of {opcode} instruction.'))
                return
        else:
            assembler_state.error(AssemblerError(f'Unexpected {token_type.name} after immediate-value'))
            return
    dests.reverse()
    srcs.reverse()
    print(opcode, dests, srcs)
asm_opcode_lookup = {
    'MOV': assemble_mov,
}
