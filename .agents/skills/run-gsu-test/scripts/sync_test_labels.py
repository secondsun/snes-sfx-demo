#!/usr/bin/env python3
"""
Synchronize symbol addresses from Test.cpu.sym into test.lua.

Validates:
1. All referenced symbols in test.lua have matching 16-bit addresses (lower 2 bytes) from Test.cpu.sym.
2. Updates test.lua in-place if addresses differ or are placeholders (e.g. 0).
3. Verifies word alignment (even address) on data buffer symbols.
4. Verifies test.lua ends emulation with emu.stop(testStatus).
"""

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


def sync_labels(sym_path: Path, lua_path: Path) -> bool:
    if not sym_path.exists():
        print(f"Error: Symbol file not found: {sym_path}", file=sys.stderr)
        return False

    if not lua_path.exists():
        print(f"Error: Lua test script not found: {lua_path}", file=sys.stderr)
        return False

    symbols = parse_sym_file(sym_path)
    if not symbols:
        print(f"Error: No symbols found in {sym_path}", file=sys.stderr)
        return False

    lua_content = lua_path.read_text(encoding="utf-8")

    # Gate 4: Emulation Termination Check
    if not re.search(r"emu\.stop\s*\(", lua_content):
        print(
            f"Error: {lua_path.name} does not call emu.stop(testStatus). "
            "Tests must explicitly terminate emulation with emu.stop(0) or emu.stop(1).",
            file=sys.stderr,
        )
        return False

    # Check for mandatory execution callback symbol
    if "test_stop" not in symbols:
        print(
            f"Error: 'test_stop' symbol not found in {sym_path.name}. "
            "GSU test harness must define test_stop label.",
            file=sys.stderr,
        )
        return False

    lines = lua_content.splitlines()
    updated_lines = []
    updates_made = []
    missing_symbols = []

    # Pattern matches lines like:
    #   test_setup = 0x0003
    #   test_stop  = 0
    #   local INPUT = 0x0AA4
    var_pattern = re.compile(
        r"^(\s*(?:local\s+)?([A-Za-z0-9_]+)\s*=\s*)(0x[0-9A-Fa-f]+|\d+)(.*)$"
    )

    for line in lines:
        m = var_pattern.match(line)
        if m:
            prefix, var_name, current_val_str, suffix = m.groups()
            if var_name in symbols:
                target_offset = symbols[var_name]["offset"]
                target_hex = f"0x{target_offset:04X}"

                # Parse current numeric value
                try:
                    current_val = (
                        int(current_val_str, 16)
                        if current_val_str.startswith(("0x", "0X"))
                        else int(current_val_str)
                    )
                except ValueError:
                    current_val = None

                if current_val != target_offset:
                    updated_lines.append(f"{prefix}{target_hex}{suffix}")
                    updates_made.append(
                        (var_name, current_val_str, target_hex, symbols[var_name]["bank"])
                    )
                else:
                    updated_lines.append(line)

                # Word alignment check for data variables
                if var_name.isupper() and (target_offset % 2 != 0):
                    print(
                        f"Error: Data buffer '{var_name}' at 0x{target_offset:04X} is not word-aligned (odd address)!",
                        file=sys.stderr,
                    )
                    return False
            else:
                # If variable looks like a test label (e.g. test_setup, test_start) but is missing in symbols
                if var_name.startswith("test_") and var_name in ("test_setup", "test_start", "test_stop"):
                    missing_symbols.append(var_name)
                updated_lines.append(line)
        else:
            updated_lines.append(line)

    if missing_symbols:
        print(
            f"Error: Required test labels missing in {sym_path.name}: {', '.join(missing_symbols)}",
            file=sys.stderr,
        )
        return False

    if updates_made:
        lua_path.write_text("\n".join(updated_lines) + "\n", encoding="utf-8")
        print(f"Synchronized {len(updates_made)} symbol addresses in {lua_path.name}:")
        for var, old_val, new_hex, bank in updates_made:
            print(f"  {var:15} : {old_val} -> {new_hex} (Bank ${bank:02X})")
    else:
        print(f"All symbol addresses in {lua_path.name} are already up-to-date.")

    return True


def main():
    parser = argparse.ArgumentParser(
        description="Synchronize and validate symbol addresses from Test.cpu.sym in test.lua"
    )
    parser.add_argument("sym_file", help="Path to Test.cpu.sym")
    parser.add_argument("lua_file", help="Path to test.lua")
    args = parser.parse_args()

    sym_path = Path(args.sym_file)
    lua_path = Path(args.lua_file)

    if not sync_labels(sym_path, lua_path):
        sys.exit(1)


if __name__ == "__main__":
    main()

