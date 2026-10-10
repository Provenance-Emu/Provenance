#!/usr/bin/env python3
"""Write a minimal 4 KiB Atari 2600 ROM for the dev harness (Stella).

The ROM is `JMP $F000` at $F000, NOP padding, and reset/IRQ vectors pointing at $F000: it
loops forever and draws a black screen, which is enough to prove import -> launch -> run.
Usage: make_harness_rom.py <output.a26>
"""
import sys
from pathlib import Path

ROM_SIZE = 4096
ENTRY = 0xF000
NOP = 0xEA
JMP_ABS = 0x4C


def rom_bytes() -> bytes:
    data = bytearray([NOP] * ROM_SIZE)
    data[0:3] = bytes([JMP_ABS, ENTRY & 0xFF, ENTRY >> 8])
    for vector in (0xFFC, 0xFFE):  # RESET, IRQ/BRK
        data[vector] = ENTRY & 0xFF
        data[vector + 1] = ENTRY >> 8
    return bytes(data)


def main(argv):
    if len(argv) != 2:
        print(__doc__.strip().splitlines()[-1], file=sys.stderr)
        return 2
    out = Path(argv[1])
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_bytes(rom_bytes())
    print(out)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
