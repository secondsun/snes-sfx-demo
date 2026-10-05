#!/usr/bin/env python3
"""Scaffold a new GSU test from tests/test_template."""

import argparse
import os
import shutil
import sys
from pathlib import Path


def sanitize_title(name: str) -> str:
    cleaned = "".join(c if c.isalnum() or c in " _-" else "_" for c in name).upper()
    cleaned = cleaned.replace("-", "_")
    return cleaned[:21].ljust(21)


def main():
    parser = argparse.ArgumentParser(description="Scaffold a new GSU test from template")
    parser.add_argument("name", help="Name of the test directory to create in tests/")
    parser.add_argument(
        "--xgsu-root",
        default=None,
        help="Path to X-GSU root directory (defaults to searching upwards)",
    )
    args = parser.parse_args()

    # Determine X-GSU root
    if args.xgsu_root:
        xgsu_dir = Path(args.xgsu_root).resolve()
    else:
        # Search from cwd or current script path
        cur = Path.cwd().resolve()
        while cur != cur.parent:
            if (cur / "tests" / "test_template").is_dir():
                xgsu_dir = cur
                break
            if (cur / "X-GSU" / "tests" / "test_template").is_dir():
                xgsu_dir = cur / "X-GSU"
                break
            cur = cur.parent
        else:
            print("Error: Could not locate X-GSU root with tests/test_template", file=sys.stderr)
            sys.exit(1)

    template_dir = xgsu_dir / "tests" / "test_template"
    target_dir = xgsu_dir / "tests" / args.name

    if target_dir.exists():
        print(f"Error: Target directory already exists: {target_dir}", file=sys.stderr)
        print("Scaffold aborted to prevent clobbering existing test code. Use run-gsu-test to run this test.", file=sys.stderr)
        sys.exit(1)

    target_dir.mkdir(parents=True)
    template_files = ["Makefile", "Map.cfg", "libSFX.cfg", "Test.s", "Test.sgs", "test.lua"]

    for fname in template_files:
        src = template_dir / fname
        dst = target_dir / fname
        if src.exists():
            shutil.copy2(src, dst)
        else:
            print(f"Warning: Template file missing: {src}", file=sys.stderr)

    # Customize libSFX.cfg
    libsfx_cfg = target_dir / "libSFX.cfg"
    if libsfx_cfg.exists():
        content = libsfx_cfg.read_text(encoding="utf-8")
        title_str = sanitize_title(args.name)
        new_content = []
        for line in content.splitlines():
            if line.strip().startswith('define "ROM_TITLE"'):
                new_content.append(f'define "ROM_TITLE",    "{title_str}"')
            else:
                new_content.append(line)
        libsfx_cfg.write_text("\n".join(new_content) + "\n", encoding="utf-8")

    print(f"Successfully created test in {target_dir}")
    print(f"ROM Title set to: '{sanitize_title(args.name)}'")


if __name__ == "__main__":
    main()
