def parse_literal(num_str):
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
        base = parse_literal.number_bases.get(ch)
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
                digit_value = parse_literal.digit_values.get(ch, -1)
                if (digit_value < 0 or digit_value >= base):
                    return None
                result *= base
                result += digit_value
                result_valid = True
            ch = next(iter_str)
    except StopIteration:
        return sign * result if result_valid else None

parse_literal.number_bases = {
    'B': 2, 'b': 2,
    'O': 8, 'o': 8,
    'D': 10, 'd': 10,
    'H': 16, 'h': 16
}

parse_literal.digit_values = {
    '0': 0, '1': 1, '2': 2, '3': 3, '4': 4,
    '5': 5, '6': 6, '7': 7, '8': 8, '9': 9,
    'A': 10, 'B': 11, 'C': 12, 'D': 13, 'E': 14, 'F': 15,
    'a': 10, 'b': 11, 'c': 12, 'd': 13, 'e': 14, 'f': 15
}
