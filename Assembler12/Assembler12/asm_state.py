class AssemblerAbort(Exception):
    pass

class AssemblerError:
    def __init__(self, message=None):
        self.file = "<unknown>"
        self.line = 0
        self._message_str = message

    def get_message(self):
        return self._message_str

    def merge(self, other):
        return False

    def __str__(self):
        build_str = f"Error in {self.file}, line {self.line}"
        msg = self.get_message()
        if msg is not None:
            build_str += f": {msg}"
        return build_str

class AssemblerOverflow(AssemblerError):
    def __init__(self, mem_len):
        self.mem_len = mem_len
        super().__init__()

    def get_message(self):
        return f"Cannot write data at or beyond address #o{self.mem_len:08o}."

    def merge(self, other):
        return isinstance(other, AssemblerOverflow)

class AssemblerOverwrite(AssemblerError):
    def __init__(self, start_addr, end_addr=None):
        if end_addr is None:
            end_addr = start_addr
        self.start_addr = start_addr
        self.end_addr = end_addr
        super().__init__()

    def get_message(self):
        if self.end_addr == self.start_addr:
            return f"Address #o{self.start_addr:08o} already contains data."
        else:
            return f"Addresses #o{self.start_addr:08o} to #o{self.end_addr:08o} already contain data."

    def merge(self, other):
        if isinstance(other, AssemblerOverwrite) \
           and self.file == other.file \
           and self.end_addr + 1 == other.start_addr:
            self.end_addr = other.end_addr
            return True
        else:
            return False

class Assembler:
    def __init__(self, mem):
        self.mem = mem
        self.address = 0
        self.labels = {}
        self.errors = []
        self.max_errors = 10
        self.file_name = "<unknown>"
        self.line_number = 0

    def error(self, e):
        e.file = self.file_name
        e.line = self.line_number
        if len(self.errors) > 0 and self.errors[-1].merge(e):
            pass
        elif len(self.errors) < self.max_errors:
            self.errors.append(e)
        else:
            raise AssemblerAbort()

    def set_address(self, a):
        if a < 0:
            self.error(AssemblerError("Address must not be negative."))
        elif a >= len(self.mem):
            self.error(AssemblerOverflow(len(self.mem)))
        else:
            self.address = a

    def write_word(self, w):
        if self.address >= len(self.mem):
            self.error(AssemblerOverflow(len(self.mem)))
        elif self.mem[self.address] >= 0:
            self.error(AssemblerOverwrite(self.address))
        else:
            self.mem[self.address] = w
            self.address += 1
