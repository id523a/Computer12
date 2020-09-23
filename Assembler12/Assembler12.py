from itertools import chain
from array import array

number_base_table = {
    'B': 2, 'b': 2,
    'O': 8, 'o': 8,
    'D': 10, 'd': 10,
    'H': 16, 'h': 16
}

digit_value = {
    '0': 0, '1': 1, '2': 2, '3': 3, '4': 4,
    '5': 5, '6': 6, '7': 7, '8': 8, '9': 9,
    'A': 10, 'B': 11, 'C': 12, 'D': 13, 'E': 14, 'F': 15,
    'a': 10, 'b': 11, 'c': 12, 'd': 13, 'e': 14, 'f': 15
}
def asm_parse_literal(num_str):
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
                dval = digit_value.get(ch, -1)
                if (dval < 0 or dval >= base):
                    return None
                result *= base
                result += dval
                result_valid = True
            ch = next(iter_str)
    except StopIteration:
        return sign * result if result_valid else None

def assemble(asm_lines, mem):
    labels = {}
    for line_number_z, asm_line in enumerate(asm_lines):
        line_number = line_number_z + 1
        # Remove line comment if present
        comment_pos = asm_line.find('//')
        if comment_pos != -1:
            asm_line = asm_line[0:comment_pos]
        # A line may contain multiple statements
        # separated by semicolons
        for statement in asm_line.split(';'):
            # Anything before a colon is a label name
            colon_labels = statement.split(':')
            statement = colon_labels[-1].strip()
            colon_labels.pop()
            # Process label names:
            for label in colon_labels:
                label = label.strip()
                if label == "":
                    continue
                print(f"{line_number:3d} [LABEL] {label}")
            if statement == "":
                continue
            print(f"{line_number:3d} [ASM] {statement}")

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
   with open('test.a12', 'r') as f:
       assemble(f, mem)

