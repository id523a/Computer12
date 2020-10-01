from enum import Enum
import re
from re_lexer import Lexer, LexError, LexerToken
from asm_state import *
from itertools import chain as iter_chain

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
    return match.group()

def is_newline(match):
    return match.group() == '\n'

assembly_lexer = Lexer([
    (r"\n|;", TokenType.END, is_newline),
    (r"#(?P<number_base>[bodh]?)(?P<number_sign>[+-]?)(?P<number_digits>[0-9a-z_]+)", TokenType.NUMBER, parse_number),
    (r"\b(?:[ABCI]P[LH]|[ABCDEFGZ])\b", TokenType.REG, extract_name),
    (r"\b[ABCI]P\b", TokenType.DOUBLE_REG, extract_name),
    (r"\w+", TokenType.IDENTIFIER, extract_name),
    (r":", TokenType.COLON),
    (r",", TokenType.COMMA),
    (r"\[", TokenType.LEFT_BRACKET),
    (r"\]", TokenType.RIGHT_BRACKET),
    (r"\+\+", TokenType.AUTO_INCREMENT),
    (r"\-\-", TokenType.AUTO_DECREMENT),
    (r"\+", TokenType.PLUS),
    (r"\s+", None) # Ignore whitespace by default
], re.IGNORECASE)

with open('../test.a12', 'r') as f:
    tokens = assembly_lexer.tokenize(f)
    tokens = iter_chain(tokens, (LexerToken(TokenType.END, False),))
    for token_type, value in tokens:
        print(token_type.name.rjust(15), "" if value is None else str(value))
