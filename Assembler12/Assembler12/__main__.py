from enum import Enum
import re
from re_lexer import Lexer, LexError, LexerToken
from asm_state import *
from itertools import chain as iter_chain
from array import array

class TokenType(Enum):
    END = 1
    NUMBER = 2
    REG = 3
    DOUBLE_REG = 4
    IDENTIFIER = 5
    COLON = 6
    COMMA = 7
    LEFT_BRACKET = 8
    RIGHT_BRACKET = 9
    AUTO_INCREMENT = 10
    AUTO_DECREMENT = 11
    PLUS = 12

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

def is_newline(match):
    return match.group() == '\n'

assembly_lexer = Lexer([
    (r"\n|;", TokenType.END, is_newline),
    (r"#(?P<number_base>[bodh]?)(?P<number_sign>[+-]?)(?P<number_digits>[0-9a-z_]+)", TokenType.NUMBER, parse_number),
    (r"\b(?:[ABCI]P[LH]|[ABCDEFGZ])\b", TokenType.REG, extract_name),
    (r"\b[ABCI]P\b", TokenType.DOUBLE_REG, extract_name),
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

def assemble_statement(assembler_state, opcode, args):
    print(f"{assembler_state.line_number}: Statement: {opcode} ({len(args)})")

def assemble_label(assembler_state, token):
    if token.token_type is TokenType.IDENTIFIER:
        if token.value not in assembler_state.labels:
            print(f"Label: {token.value} = {assembler_state.address:08o}")
            assembler_state.labels[token.value] = assembler_state.address
        else:
            assembler_state.error(AssemblerError(f"Label {token.value} is already defined."))
    elif token.token_type is TokenType.NUMBER:
        if token.value >= 0 and token.value < len(assembler_state.mem):
            print(f"Label: {token.value:08o}")
            assembler_state.address = token.value
        else:
            assembler_state.error(AssemblerError(f"Label address is out of range."))

mem = array('h', (-1 for i in range(32768)))
assembler_state = Assembler(mem)
with open("../test.a12", 'r') as f:
    tokens = assembly_lexer.tokenize(f)
    tokens = iter_chain(tokens, (LexerToken(TokenType.END, False),))
    assembler_state.file_name = "test.a12"
    assembler_state.line_number = 1
    op_token = None
    args = []
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
    for err in assembler_state.errors:
        print(err)
