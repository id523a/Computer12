import re
from re_lexer import Lexer, LexError, LexerToken
from asm_state import *
from asm_opcodes import asm_opcode_lookup
from itertools import chain as iter_chain
from array import array

number_bases = {
    '': 10,
    'B': 2, 'b': 2,
    'O': 8, 'o': 8,
    'D': 10, 'd': 10,
    'H': 16, 'h': 16
}

digit_values = {
    '0': 0, '1': 1, '2': 2, '3': 3, '4': 4,
    '5': 5, '6': 6, '7': 7, '8': 8, '9': 9,
    'A': 10, 'B': 11, 'C': 12, 'D': 13, 'E': 14, 'F': 15,
    'a': 10, 'b': 11, 'c': 12, 'd': 13, 'e': 14, 'f': 15
}

register_indices = {
    'A': 0, 'B': 1, 'C': 2, 'D': 3,
    'E': 4, 'F': 5, 'G': 6, 'Z': 7,
    'APL': 8,  'APH': 9,  'AP': (9, 8),
    'BPL': 10, 'BPH': 11, 'BP': (11,10),
    'CPL': 12, 'CPH': 13, 'CP': (13,12),
    'IPL': 14, 'IPH': 15, 'IP': (15,14)
}

def parse_number(match):
    base = number_bases[match.group('number_base')]
    sign = 1
    if match.group('number_sign') == '-':
        sign = -1
    result = 0
    for digit_char in match.group('number_digits'):
        if digit_char == '_':
            continue
        digit = digit_values.get(digit_char)
        if digit is not None and digit < base:
            result *= base
            result += digit
        else:
            raise LexError(f'Invalid digit in base {base}: {digit_char!r}')
    return sign * result

def extract_name(match):
    return match.group().upper()

def extract_reg(match):
    return register_indices[match.group().upper()]

def is_newline(match):
    return match.group() == '\n'

assembly_lexer = Lexer([
    (r"\n|;", TokenType.END, is_newline),
    (r"#(?P<number_base>[bodh]?)(?P<number_sign>[+-]?)(?P<number_digits>[0-9a-z_]+)", TokenType.NUMBER, parse_number),
    (r"\b(?:[ABCI]P[LH]|[ABCDEFGZ])\b", TokenType.REG, extract_reg),
    (r"\b[ABCI]P\b", TokenType.DOUBLE_REG, extract_reg),
    (r"[\w!@$?.]+", TokenType.IDENTIFIER, extract_name),
    (r":", TokenType.COLON),
    (r",", TokenType.COMMA),
    (r"\[", TokenType.LEFT_BRACKET),
    (r"\]", TokenType.RIGHT_BRACKET),
    (r"\+\+", TokenType.AUTO_INCREMENT),
    (r"\-\-", TokenType.AUTO_DECREMENT),
    (r"\+", TokenType.PLUS),
    (r"\s+", None) # Ignore whitespace by default
], re.IGNORECASE)


class UnknownOpcode(AssemblerError):
    def __init__(self, opcode):
        self.opcode = opcode
        super().__init__()

    def get_message(self):
        return f"Unknown opcode {self.opcode}."

def assemble_statement(assembler_state, opcode, args):
    assembler_func = asm_opcode_lookup.get(opcode)
    if assembler_func is not None:
        assembler_func(assembler_state, opcode, args)
    else:
        assembler_state.error(UnknownOpcode(opcode))

def assemble_label(assembler_state, token):
    if token.token_type is TokenType.IDENTIFIER:
        if token.value not in assembler_state.labels:
            assembler_state.labels[token.value] = assembler_state.address
        else:
            assembler_state.error(AssemblerError(f"Label {token.value} is already defined."))
    elif token.token_type is TokenType.NUMBER:
        if token.value >= 0 and token.value < len(assembler_state.mem):
            assembler_state.address = token.value
        else:
            assembler_state.error(AssemblerError(f"Label address is out of range."))

def mif_lines(mem):
    # Write file header
    yield '-- Assembler12 - generated file'
    yield 'WIDTH=12;'
    yield f'DEPTH={len(mem)};'
    yield 'ADDRESS_RADIX=HEX;'
    yield 'DATA_RADIX=HEX;'
    yield ''
    yield 'CONTENT BEGIN'
    # Run-length encode file contents
    prev_word = -1
    run_start = 0
    address = 0
    addr_width = (len(mem).bit_length() + 3) // 4
    # The 'mem' array is extended with a value that cannot be in the input,
    # so that the last run is finished properly
    for word in iter_chain(mem, (None,)):
        # Negative values in the input should be written as zeros
        if word is not None and word < 0:
            word = 0
        # If a new run has started,
        if word != prev_word:
            run_length = address - run_start
            # write out the previous run
            if run_length >= 1:
                run_end = address - 1
                if run_length == 1:
                    addr_part = f'\t{run_start:0{addr_width}X}'
                else:
                    addr_part = f'\t[{run_start:0{addr_width}X}..{run_end:0{addr_width}X}]'
                yield f'{addr_part} : {prev_word:03X};'
            # Start the new run
            run_start = address
            prev_word = word
        address += 1
    yield 'END;'

mem = array('h', (-1 for i in range(32768)))
assembler_state = Assembler(mem)
errored = False
with open("../test2.a12", 'r') as f:
    tokens = assembly_lexer.tokenize(f)
    tokens = iter_chain(tokens, (LexerToken(TokenType.END, False),))
    assembler_state.file_name = "test2.a12"
    assembler_state.line_number = 1
    op_token = None
    args = []
    try:
        for tok in tokens:
            if tok.token_type is TokenType.END:
                if op_token is not None:
                    if op_token.token_type is TokenType.IDENTIFIER:
                        assemble_statement(assembler_state, op_token.value, args)
                    else:
                        assembler_state.error(AssemblerError('A statement must begin with an identifier (the opcode).'))
                op_token = None
                args.clear()
                if tok.value is True:
                    assembler_state.line_number += 1
            elif tok.token_type is TokenType.COLON:
                if op_token is not None and len(args) == 0:
                    assemble_label(assembler_state, op_token)
                else:
                    assembler_state.error(AssemblerError('A label must consist of exactly one identifier or number.'))
                op_token = None
                args.clear()
            elif op_token is None:
                if tok.token_type in (TokenType.IDENTIFIER, TokenType.NUMBER):
                    op_token = tok
                else:
                    assembler_state.error(AssemblerError(f'Unexpected {tok.token_type.name} at beginning of statement/label.'))
            else:
                args.append(tok)
        if len(assembler_state.errors) == 0:
            assembler_state.resolve_deferred()
    except AssemblerAbort:
        pass
    if len(assembler_state.errors) > 0:
        errored = True
    for err in assembler_state.errors:
        print(err)

if errored:
    print("* Assembly failed. No output written.")
else:
    with open("../outfile.mif", 'w') as f:
        for line in mif_lines(mem):
            f.write(line + '\n')
