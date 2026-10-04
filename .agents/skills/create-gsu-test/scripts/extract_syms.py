#!/usr/bin/env python3
"""Extract symbol offsets and check word alignment from Test.cpu.sym."""

import argparse
import re
import sys
from pathlib import Path


def parse_sym_file(sym_path: Path):
    symbols = {}
    pattern = re.compile(r"^al\s+([0-9A-Fa-f]{6})\s+\.([A-Za-z0-9_@]+)")

    with open(sym_path, "r", encoding="utf-8") as f:
        for line in f:
            match = pattern.match(line.strip())
            if match:
                full_hex, name = match.groups()
                full_val = int(full_hex, 16)
                offset = full_val & 0xFFFF
                bank = (full_val >> 16) & 0xFF
                symbols[name] = {"full": full_val, "offset": offset, "bank": bank}
    return symbols


def main():
    parser = argparse.ArgumentParser(description="Extract symbol offsets from Test.cpu.sym")
    parser.add_argument("sym_file", help="Path to Test.cpu.sym")
    parser.add_argument(
        "--update-lua",
        help="Optional path to test.lua to automatically update symbol addresses",
    )
    args = parser.parse_args()

    sym_path = Path(args.sym_file)
    if not sym_path.exists():
        print(f"Error: Symbol file not found: {sym_path}", file=sys.stderr)
        sys.exit(1)

    symbols = parse_sym_file(sym_path)

    key_syms = ["test_setup", "test_start", "test_stop", "INPUT", "OUTPUT"]
    found_values = {}

    print(f"Symbols from {sym_path.name}:")
    print("-" * 50)
    for sym in key_syms:
        if sym in symbols:
            info = symbols[sym]
            offset = info["offset"]
            bank = info["bank"]
            aligned = (offset % 2 == 0)
            align_str = "word-aligned" if aligned else "WARNING: UNALIGNED (ODD ADDRESS)"
            print(f"  {sym:12} : 0x{offset:04X}  (Bank ${bank:02X}, {align_str})")
            found_values[sym] = offset
        else:
            print(f"  {sym:12} : NOT FOUND")

    # Check for any other symbols requested or exported
    print("-" * 50)

    if args.update_lua:
        lua_path = Path(args.update_lua)
        if not lua_path.exists():
            print(f"Error: Lua file not found: {lua_path}", file=sys.stderr)
            sys.exit(1)

        lines = lua_path.read_text(encoding="utf-8").splitlines()
        updated_lines = []
        for line in lines:
            updated = False
            for sym, offset in found_values.items():
                # Matches e.g. test_setup = 0x... or test_setup = 0
                pattern = rf"^(\s*{re.escape(sym)}\s*=\s*)(0x[0-9A-Fa-f]+|\d+)(.*)$"
                m = re.match(pattern, line)
                if m:
                    updated_lines.append(f"{m.group(1)}0x{offset:04X}{m.group(3)}")
                    updated = True
                    break
            if not updated:
                updated_lines.append(line)

        lua_path.write_text("\n".join(updated_lines) + "\n", encoding="utf-8")
        print(f"Updated {lua_path} with extracted symbol offsets.")


if __name__ == "__main__":
    main()
