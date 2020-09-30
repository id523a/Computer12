import re

from collections import namedtuple

def default_lexer_action(match):
    return match.group()

LexerRule = namedtuple("LexerRule", "pattern token_type action", defaults=(default_lexer_action,))
LexerToken = namedtuple("LexerToken", "token_type value")

del default_lexer_action
del namedtuple

class LexError(Exception):
    pass

class Lexer:
    def __init__(self, lexer_rules):
        self.rule_lookup = {}
        regex_build = []
        for idx, lex_def in enumerate(lexer_rules):
            if not isinstance(lex_def, LexerRule):
                lex_def = LexerRule(*lex_def)
            rule_name = f"LEX_R{idx}"
            regex_build.append(f"(?P<{rule_name}>{lex_def.pattern})")
            self.rule_lookup[rule_name] = lex_def 
        self.lexer_regex = re.compile("|".join(regex_build))

    def tokenize(self, seq, *args, **kwargs):
        if isinstance(seq, str):
            return self.tokenize_str(seq, *args, **kwargs)
        else:
            return self.tokenize_file(seq, *args, **kwargs)

    def tokenize_str(self, seq):
        start_point = 0
        end_point = len(seq)
        while start_point < end_point:
            match_obj = self.lexer_regex.match(seq, start_point)
            if match_obj is None:
                raise LexError(buffer[start_point:])
            rule = self.rule_lookup[match_obj.lastgroup]
            if rule.token_type is not None:
                yield LexerToken(rule.token_type, rule.action(match_obj))
            start_point = match_obj.end()

    def tokenize_file(self, seq, chunk_size=1024):
        buffer = ''
        eof = False
        start_point = 0
        while (not eof) or start_point < len(buffer):
            # Remove characters at the beginning of the buffer
            if start_point >= chunk_size:
                buffer = buffer[start_point:]
                start_point = 0
            # Fill buffer with characters from file
            while (not eof) and len(buffer) - start_point < chunk_size:
                file_data = seq.read(chunk_size)
                if len(file_data) == 0:
                    eof = True
                else:
                    buffer += file_data
            # Match the next token
            match_obj = self.lexer_regex.match(buffer, start_point)
            if match_obj is None:
                raise LexError(buffer[start_point:])
            rule = self.rule_lookup[match_obj.lastgroup]
            if rule.token_type is not None:
                yield LexerToken(rule.token_type, rule.action(match_obj))
            start_point = match_obj.end()

def re_lexer_main():
    from io import StringIO
    file = StringIO(input("Enter string to tokenize: "))

    x = [
        LexerRule(r"[0-9]+", "NUMBER", lambda m : int(m.group())),
        LexerRule(r"[A-Za-z_][A-Za-z0-9_]*", "WORD"),
        LexerRule(r"\s+", None),
    ]
    for token in Lexer(x).tokenize(file):
        print(token)

if __name__ == "__main__":
    re_lexer_main()

del re_lexer_main

