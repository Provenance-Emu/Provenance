#!/usr/bin/env python3
"""Write a minimal test ROM for the dev harness: Atari 2600 (.a26, Stella) or GBA (.gba, mGBA).

The ROM is `JMP $F000` at $F000, NOP padding, and reset/IRQ vectors pointing at $F000: it
loops forever and draws a black screen, which is enough to prove import -> launch -> run.
The GBA ROM has the standard 192-byte header (branch to 0xC0, fixed 0x96, header checksum) and
`b .` at 0xC0, padded to 256 KiB; the logo bytes are left zero (mGBA does not check them).
Usage: make_harness_rom.py <output.a26|output.gba>   (the extension picks the system)
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


GBA_SIZE = 256 * 1024
GBA_ENTRY = 0xC0
GBA_BRANCH_TO_ENTRY = 0xEA000000 | ((GBA_ENTRY - 8) // 4)  # b 0xC0 (ARM PC is 8 ahead)
GBA_BRANCH_SELF = 0xEAFFFFFE  # b .
GBA_TITLE_OFFSET = 0xA0
GBA_CHECKSUM_OFFSET = 0xBD


def gba_rom_bytes() -> bytes:
    data = bytearray(GBA_SIZE)
    data[0:4] = GBA_BRANCH_TO_ENTRY.to_bytes(4, "little")
    data[GBA_TITLE_OFFSET:GBA_TITLE_OFFSET + 12] = b"PVHARNESS".ljust(12, b"\0")
    data[0xAC:0xB0] = b"PVHA"  # game code
    data[0xB0:0xB2] = b"01"  # maker code
    data[0xB2] = 0x96  # fixed value
    data[GBA_CHECKSUM_OFFSET] = (-(sum(data[0xA0:0xBD]) + 0x19)) & 0xFF
    data[GBA_ENTRY:GBA_ENTRY + 4] = GBA_BRANCH_SELF.to_bytes(4, "little")
    return bytes(data)


def main(argv):
    if len(argv) != 2:
        print(__doc__.strip().splitlines()[-1], file=sys.stderr)
        return 2
    out = Path(argv[1])
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_bytes(gba_rom_bytes() if out.suffix.lower() == ".gba" else rom_bytes())
    print(out)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
