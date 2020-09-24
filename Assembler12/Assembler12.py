from itertools import chain
from array import array

number_base_table = {
    'B': 2, 'b': 2,
    'O': 8, 'o': 8,
    'D': 10, 'd': 10,
    'H': 16, 'h': 16
}

digit_value_table = {
    '0': 0, '1': 1, '2': 2, '3': 3, '4': 4,
    '5': 5, '6': 6, '7': 7, '8': 8, '9': 9,
    'A': 10, 'B': 11, 'C': 12, 'D': 13, 'E': 14, 'F': 15,
    'a': 10, 'b': 11, 'c': 12, 'd': 13, 'e': 14, 'f': 15
}
def parse_number_literal(num_str):
    # Number format : # <base> <sign> <digits>
    # Base is optional, defaults to decimal
    # Sign is optional, defaults to positive
    # Bb = binary, Oo = octal, Dd = decimal, Hh = hex
    # For example: "#h-2c" is -44
    iter_str = iter(num_str)
    sign = 1
    result = 0
    result_valid = False
    try:
        # Make sure first character is '#'
        ch = next(iter_str)
        if (ch != '#'):
            return None
        ch = next(iter_str)
        # Attempt to read base
        base = number_base_table.get(ch)
        if base is None:
            base = 10
        else:
            ch = next(iter_str)
        # Attempt to read sign
        if ch == '+':
            sign = 1
            ch = next(iter_str)
        elif ch == '-':
            sign = -1
            ch = next(iter_str)
        # Read digits
        while True:
            if ch != '_': # Ignore underscores in digit string
                digit_value = digit_value_table.get(ch, -1)
                if (digit_value < 0 or digit_value >= base):
                    return None
                result *= base
                result += digit_value
                result_valid = True
            ch = next(iter_str)
    except StopIteration:
        return sign * result if result_valid else None

class AssemblerError(Exception):
    def __init__(self, file_name, line_num, message):
        self.file_name = file_name
        self.line_num = line_num
        self.message = message

    def __str__(self):
        return f'in {self.file_name}, line {self.line_num}: {self.message}'

class Assembler:
    def __init__(self, mem):
        self.mem = mem
        self.address = 0
        self.labels = {}
        self.file_name = '<unknown>'
        self.line_number = 0

    def error(self, message):
        raise AssemblerError(self.file_name, self.line_number, message)

    def asm_statement(self, statement):
        print(f"{self.file_name}:{self.line_number} [ASM] {statement}")

    def asm_label(self, label):
        parse_addr = parse_number_literal(label)
        if parse_addr is not None:
            if parse_addr >= 0 and parse_addr < len(mem):
                print(f"{self.file_name}:{self.line_number} [ORIG] {parse_addr:08o}")
                self.address = parse_addr
            else:
                self.error(f"Address {label} is out of range.")
        else:
            print(f"{self.file_name}:{self.line_number} [LABEL] {label}")

    def asm_line(self, line):
        # Remove line comment if present
        comment_pos = line.find('//')
        if comment_pos != -1:
            line = line[0:comment_pos]
        # A line may contain multiple statements separated by ';'
        for statement in line.split(';'):
            # Anything before a colon is a label name on the statement
            colon_labels = statement.split(':')
            statement = colon_labels[-1].strip()
            colon_labels.pop()
            # Process label names:
            for label in colon_labels:
                label = label.strip()
                if label == "":
                    continue
                self.asm_label(label)
            # Process statement
            if statement == "":
                continue
            self.asm_statement(statement)

    def asm_file(self, file_name):
        try:
            # Remember previous values for file name and line number
            old_file = self.file_name
            old_line = self.line_number
            f = open(file_name, 'r')
            # Record file name for debugging
            self.file_name = file_name
            for line_num_z, line in enumerate(f):
                # Record line number for debugging
                self.line_number = line_num_z + 1
                self.asm_line(line)
        finally:
            # Restore file name and line number
            self.file_name = old_file
            self.line_number = old_line
            f.close()

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
    prev_word = -1;
    run_start = 0;
    address = 0;
    addr_width = (len(mem).bit_length() + 3) // 4;
    # The 'mem' array is extended with a value that cannot be in the input,
    # so that the last run is finished properly
    for word in chain(mem, (None,)):
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

if __name__ == "__main__":
    mem = array('h', (-1 for i in range(32768)))
    assembler = Assembler(mem)
    assembler.asm_file('test.a12')

