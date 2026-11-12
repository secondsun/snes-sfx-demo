#!/usr/bin/env python3
"""Deterministically builds Test.msu (>96 KB) for headless Mesen MSU-1 testing.

Places Studio-packed ROUNDTRIP_ATLAS (.bin/.tab/.pal) and roundtrip_map.map
above the 64 KB boundary ($00012000+) so 32-bit MSU_SEEK ($2000..$2003) is
exercised end-to-end, plus a second atlas/tab/pal/map bundle at $00016000+.
"""
from pathlib import Path
import struct

HERE = Path(__file__).resolve().parent
STUDIO_DATA = HERE.parent / "test_iso_studio_roundtrip" / "Data"

TOTAL_SIZE = 0x00018000  # 98,304 bytes


def main() -> None:
    # Fill low 64 KB ($00000000..$00011FFF) with $EE sentinel so any truncated
    # 16-bit seek would read $EEEE instead of valid assets.
    buf = bytearray(b"\xEE" * TOTAL_SIZE)
    buf[0:6] = b"S-MSU1"

    atlas0 = (STUDIO_DATA / "ROUNDTRIP_ATLAS.bin").read_bytes()
    tab0 = (STUDIO_DATA / "ROUNDTRIP_ATLAS.tab").read_bytes()
    pal0 = (STUDIO_DATA / "ROUNDTRIP_ATLAS.pal").read_bytes()
    map0 = (STUDIO_DATA / "roundtrip_map.map").read_bytes()

    assert len(atlas0) == 8192, f"unexpected atlas0 size {len(atlas0)}"
    assert len(tab0) == 56, f"unexpected tab0 size {len(tab0)}"
    assert len(pal0) == 32, f"unexpected pal0 size {len(pal0)}"
    assert len(map0) == 520, f"unexpected map0 size {len(map0)}"

    buf[0x00012000 : 0x00012000 + len(atlas0)] = atlas0
    buf[0x00014000 : 0x00014000 + len(tab0)] = tab0
    buf[0x00014100 : 0x00014100 + len(pal0)] = pal0
    buf[0x00014200 : 0x00014200 + len(map0)] = map0

    # Second bundle at $00016000+ (atlas_id = 1)
    atlas1 = bytes([0x0B]) * 2048
    tab1 = struct.pack("<HHHHHHHH", 0x5453, 1, 64, 6, 0x0000, 31, 0x07C0, 0x07FF)
    pal1 = bytearray(32)
    struct.pack_into("<H", pal1, 4, 0x5AD6)  # color 2 = $5AD6
    map1 = bytearray(8 + 16 * 8)
    struct.pack_into("<BBhhh", map1, 0, 4, 4, 96, 56, -0x4532)  # $BACE unsigned

    buf[0x00016000 : 0x00016000 + len(atlas1)] = atlas1
    buf[0x00016800 : 0x00016800 + len(tab1)] = tab1
    buf[0x00016900 : 0x00016900 + len(pal1)] = pal1
    buf[0x00016A00 : 0x00016A00 + len(map1)] = map1

    out_path = HERE / "Test.msu"
    out_path.write_bytes(buf)
    print(f"Packed {out_path.name} ({len(buf)} bytes)")


if __name__ == "__main__":
    main()
