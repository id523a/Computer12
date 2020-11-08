from asm_state import *

opcode_carry_lookup = {
    'ADD': 'ADK',
    'SUB': 'SBK'
}

opcode_number_lookup = {
    'MOV': 0o0000,
    'AND': 0o0100,
    'OR':  0o0200,
    'XOR': 0o0300,
    'ADD': 0o0400,
    'ADK': 0o0500,
    'SUB': 0o0600,
    'SBK': 0o0700
}
class UndefinedLabel(AssemblerError):
    def __init__(self, label_name):
        self.label_name = label_name
        super().__init__()

    def get_message(self):
        return f'Undefined label {self.label_name}.'

    def merge(self, other):
        if isinstance(other, UndefinedLabel) \
           and self.file == other.file \
           and self.line == other.line \
           and self.label_name == other.label_name:
            return True
        else:
            return False

def defer_read_label(label, idx):
    def defer_func(state):
        if label in state.labels:
            return (state.labels[label] >> (12 * idx)) & 4095
        else:
            state.error(UndefinedLabel(label))
            return 0
    return defer_func

def write_instr_basic(state, opcode, dest, src):
    dest_hi = (dest >> 3) & 1
    dest_lo = dest & 7
    src_hi = (src >> 3) & 1
    src_lo = src & 7
    if src_hi == 1 and dest_hi == 1:
        state.error(AssemblerError(f'{opcode} cannot operate directly on two \'far\' registers.'))
        return False
    else:
        instr_word = opcode_number_lookup[opcode]
        instr_word |= (dest_hi << 10) | (src_hi << 9)
        instr_word |= (dest_lo << 3) | src_lo
        state.write_word(instr_word)
        return True

def assemble_instr_basic(state, opcode, args):
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
                state.error(AssemblerError(f'Unexpected {token_type.name} in first argument of {opcode} instruction.'))
                return
        elif not use_immediate_value:
            if token_type in (TokenType.NUMBER, TokenType.IDENTIFIER):
                if len(srcs) == 0:
                    immediate_value = value
                    use_immediate_value = True
                    immediate_value_defer = (token_type is TokenType.IDENTIFIER)
                else:
                    state.error(AssemblerError(f'Unexpected {token_type.name}. Registers and immediate values cannot be mixed in the second argument of {opcode}.'))
                    return
            elif token_type is TokenType.REG:
                srcs.append(value)
            elif token_type is TokenType.DOUBLE_REG:
                srcs.extend(value)
            elif token_type is TokenType.COMMA:
                state.error(AssemblerError(f'Unexpected {token_type.name}. {opcode} takes exactly two arguments.'))
                return
            else:
                state.error(AssemblerError(f'Unexpected {token_type.name} in the second argument of {opcode} instruction.'))
                return
        else:
            state.error(AssemblerError(f'Unexpected {token_type.name} after immediate value in {opcode} instruction.'))
            return
    dests.reverse()
    srcs.reverse()
    print(dests, srcs)
    if use_immediate_value:
        immediate_value_valid = True
        if immediate_value_defer:
            immediate_value_valid = (len(dests) >= 2)
            if not immediate_value_valid:
                state.error(AssemblerError(f'The destination for {opcode} must be at least 2 words in order to accommodate a label address.'))
                return
        else:
            immediate_max = 4096 ** len(dests)
            immediate_min = -immediate_max // 2
            immediate_value_valid = (immediate_value >= immediate_min and immediate_value < immediate_max)
            if not immediate_value_valid:
                state.error(AssemblerError(f'The immediate operand for {opcode} is too large for its destination.'))
                return
        if immediate_value_valid:
            for idx, dest_reg in enumerate(dests):
                opcode_carry = opcode
                if idx >= 1:
                    opcode_carry = opcode_carry_lookup.get(opcode, opcode)
                write_instr_basic(state, opcode_carry, dest_reg, 7)
                if immediate_value_defer:
                    state.write_deferred(defer_read_label(immediate_value, idx))
                else:
                    state.write_word((immediate_value >> (12 * idx)) & 4095)
    elif len(dests) != len(srcs):
        state.error(AssemblerError(f'The operands for {opcode} must have equal width.'))
        return
    else:
        for idx, dest_reg, src_reg in zip(range(len(dests)), dests, srcs):
            opcode_carry = opcode
            if idx >= 1:
                opcode_carry = opcode_carry_lookup.get(opcode, opcode)
            if not write_instr_basic(state, opcode_carry, dest_reg, src_reg):
                return
            if src_reg == 7:
                state.write_word(0)

asm_opcode_lookup = {
    'MOV': assemble_instr_basic,
    'AND': assemble_instr_basic,
    'OR':  assemble_instr_basic,
    'XOR': assemble_instr_basic,
    'ADD': assemble_instr_basic,
    'ADK': assemble_instr_basic,
    'SUB': assemble_instr_basic,
    'SBK': assemble_instr_basic,
}
