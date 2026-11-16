#!/usr/bin/env python3
"""Rebuilds the CHD fixtures in this folder. Needs `chdman` (MAME tools) on PATH.

Each fixture is the same 64-sector disc: an ISO 9660 volume whose SYSTEM.CNF
names SLUS_123.45, four sectors of noise (so a compressed CHD also holds hunks
stored as they are), twenty sectors of made-up text (so the decoders see
literals, matches and repeats), and empty sectors (stored as copies of each
other). disc.iso is that disc as plain 2048-byte sectors, for the tests to
compare against. Run from anywhere:  python3 make_fixtures.py
"""
import os
import random
import struct
import subprocess
import sys
import tempfile

SECTOR = 2048
SECTORS = 64
HERE = os.path.dirname(os.path.abspath(__file__))


def both(value, fmt):
    return struct.pack("<" + fmt, value) + struct.pack(">" + fmt, value)


def directory_record(name, lba, size, is_dir):
    ident = name
    length = 33 + len(ident) + (1 - len(ident) % 2)
    record = bytes([length, 0]) + both(lba, "I") + both(size, "I") + bytes(7)
    record += bytes([2 if is_dir else 0, 0, 0]) + both(1, "H") + bytes([len(ident)]) + ident
    return record.ljust(length, b"\0")


def cooked_image():
    sectors = [bytes(SECTOR) for _ in range(SECTORS)]
    boot = b"BOOT = cdrom:\\SLUS_123.45;1\r\nTCB = 4\r\nEVENT = 10\r\nSTACK = 801fff00\r\n"
    root = directory_record(b"\0", 18, SECTOR, True) + directory_record(b"\1", 18, SECTOR, True)
    root += directory_record(b"SYSTEM.CNF;1", 19, len(boot), False)
    pvd = bytearray(SECTOR)
    pvd[0:7] = b"\1CD001\1"
    pvd[8:40] = b"PLAYSTATION".ljust(32)
    pvd[40:72] = b"FIXTURE".ljust(32)
    pvd[80:88] = both(SECTORS, "I")
    pvd[120:124] = both(1, "H")
    pvd[124:128] = both(1, "H")
    pvd[128:132] = both(SECTOR, "H")
    pvd[156:190] = directory_record(b"\0", 18, SECTOR, True)
    sectors[16] = bytes(pvd)
    sectors[17] = (b"\xffCD001\1").ljust(SECTOR, b"\0")
    sectors[18] = root.ljust(SECTOR, b"\0")
    sectors[19] = boot.ljust(SECTOR, b"\0")
    noise = random.Random(3400)
    for index in range(24, 28):
        sectors[index] = bytes(noise.getrandbits(8) for _ in range(SECTOR))
    words = [bytes(noise.choice(b"abcdefghijklmnopqrstuvwxyz") for _ in range(noise.randint(2, 9))) for _ in range(300)]
    for index in range(28, 48):
        text = bytearray()
        while len(text) < SECTOR:
            text += noise.choice(words) + noise.choice([b" ", b" ", b", ", b".\n"])
        sectors[index] = bytes(text[:SECTOR])
    return sectors


def bcd(value):
    return (value // 10) << 4 | value % 10


def raw_mode2_image(sectors):
    """MODE2/2352 form 1, as a PlayStation disc is dumped. EDC and ECC are left zero."""
    out = bytearray()
    for lba, data in enumerate(sectors):
        frame = lba + 150
        header = bytes([bcd(frame // 4500), bcd(frame // 75 % 60), bcd(frame % 75), 2])
        sync = b"\0" + b"\xff" * 10 + b"\0"
        subheader = bytes([0, 0, 8, 0]) * 2
        out += sync + header + subheader + data + bytes(280)
    return bytes(out)


def chdman(*args):
    subprocess.run(["chdman", *args], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def main():
    sectors = cooked_image()
    with tempfile.TemporaryDirectory() as tmp:
        iso = os.path.join(HERE, "disc.iso")
        with open(iso, "wb") as handle:
            handle.write(b"".join(sectors))
        raw = os.path.join(tmp, "disc.bin")
        with open(raw, "wb") as handle:
            handle.write(raw_mode2_image(sectors))
        cue = os.path.join(tmp, "disc.cue")
        with open(cue, "w") as handle:
            handle.write('FILE "disc.bin" BINARY\n  TRACK 01 MODE2/2352\n    INDEX 01 00:00:00\n')

        builds = [
            ("cd-mode1-none.chd", "createcd", iso, "none"),
            ("cd-mode1-cdzl.chd", "createcd", iso, "cdzl"),
            ("cd-mode1-cdlz.chd", "createcd", iso, "cdlz"),
            ("cd-mode1-cdzs.chd", "createcd", iso, "cdzs"),
            ("cd-mode2raw-none.chd", "createcd", cue, "none"),
            ("cd-mode2raw-cdlz.chd", "createcd", cue, "cdlz"),
            ("dvd-none.chd", "createdvd", iso, "none"),
            ("dvd-lzma.chd", "createdvd", iso, "lzma"),
            ("dvd-zlib.chd", "createdvd", iso, "zlib"),
            ("dvd-zstd.chd", "createdvd", iso, "zstd"),
        ]
        for name, command, source, codec in builds:
            target = os.path.join(HERE, name)
            if os.path.exists(target):
                os.remove(target)
            chdman(command, "-i", source, "-o", target, "-c", codec)
            print(f"{name}: {os.path.getsize(target)} bytes")


if __name__ == "__main__":
    sys.exit(main())
