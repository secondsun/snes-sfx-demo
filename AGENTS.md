# Project AGENTS Guide: SuperFX (SNES-SFX-DEMO) Workspace

This document provides context, architecture rules, hardware constraints, and tooling instructions for AI agents working in this repository.

---

## 1. Workspace & Subprojects Architecture

This repository is a multi-project workspace targeting the Super Nintendo Entertainment System (SNES) and the **SuperFX (GSU / FX3)** coprocessor:

1. **`libSFX`** (`/libSFX`):
   - Comprehensive SNES bare-metal SDK and development framework.
   - Provides runtime bootstrapper, header creation, memory mapping configurations, interrupt handling (NMI/VBLANK), and SMP (APU sound processor) runtime.
   - Bundles the CC65 toolchain binaries: `ca65` (assembler), `ld65` (linker), and `superfamicheck` (ROM validation and checksum repair).

2. **`X-GSU`** (`/X-GSU`):
   - Core SuperFX coprocessor mathematical routines and algorithmic libraries.
   - Includes:
     - 16-bit 3D vector arithmetic (`add`, `subtract`, `negate`, `dot`, `cross`, `length`, `normalize`, `copy`).
     - Fixed-point 3D vertex and matrix transformations (`vector3_transform`, `camera_lookAt`).
     - 32-bit square root (`gsu_sqrt32`) and 16-bit fixed-point reciprocal (`reciprocal`).
     - Rob Northen Compression (RNC / Huffman) decompression routines (`rnc/`).
     - Comprehensive unit test suite with 13 automated tests verified via Mesen CE headless test runner.

3. **`SpriteScale`** (`/SpriteScale`):
   - SuperFX rasterization demo and sprite scaling engine.
   - Implements polygon rendering and edge-table rasterization techniques on SuperFX.

4. **`edge-table`** (`/edge-table` and `/docs/edgeTable.txt`):
   - Specification and architecture for dynamic edge-table scanline rendering.
   - Organizes scanlines into 160 row buckets, managing span insertion, front-to-back occlusion clipping, and affine texture stepping.
   - *Status*: Currently implemented within `SpriteScale`; will be refactored into a reusable, documented standalone library in the future.

5. **`build_tools/ExtractGsuWorkRamLabels`** (`/build_tools/ExtractGsuWorkRamLabels`):
   - Java/Maven utility stub designed to parse `*.sgs` files and recursively traverse `.include` directives to extract and export GSU Work RAM labels.
   - *Current Workflow*: Agents use the Python script `.agents/skills/create-gsu-test/scripts/extract_syms.py` to extract symbols and addresses directly from `ld65` symbol map files (`*.cpu.sym`).

---

## 2. Target Hardware: SuperFX 3 (FX3)

The project targets the **SuperFX 3 (FX3)**, the 21.47 MHz RISC coprocessor revision documented by Randy Linden (see [FX3 Specifications](.agents/skills/create-gsu-test/references/fx3_specifications.md) and [upstream repo](https://github.com/LimitedRunGames-Tech/snes-fx3)).

### Critical FX3 Architectural Nuances:
1. **No Hardware `MERGE` Instruction**:
   - In original SuperFX 1/2 hardware, `ALT2` + `MERGE` merged high bytes of two registers.
   - **On FX3, `MERGE` is not implemented**.
   - Workaround: Use bit manipulation sequences with `hib`, `lob`, `swap`, and `or`. See the `condensed_lmult` macro in [`X-GSU/gsu_maths/gsu_vector.i`](X-GSU/gsu_maths/gsu_vector.i).
2. **Simultaneous Bus Access**:
   - The FX3 enables simultaneous memory bus access. The GSU and SNES 65816 CPU can access memory concurrently without stalling or bus locking, provided memory banks and chip selects are configured properly.
3. **Register Calling Conventions**:
   - `R0`: Default source and destination register (`Sreg`/`Dreg`). Primary input parameter pointer. Any non-prefix instruction resets `Sreg` and `Dreg` back to `R0`.
   - `R1` - `R3`: General parameters, secondary pointers, and scratch registers. `R3` is the standard return register (or points to output structs).
   - `R4`: Low 16 bits of 32-bit product during hardware `LMULT`. **Never use `R4` as destination register `D` in `condensed_lmult`**.
   - `R6`: Hardware multiplicand register for `LMULT` / `MULT`.
   - `R7` - `R9`: Calculation scratch registers.
   - `R10`: Dedicated software stack pointer (`init_stack`, `gsu_stack_push`, `gsu_stack_pop`).
   - `R11`: Link register storing return address for subroutine calls (`call`, `return`).
   - `R12`: Loop counter register (`loop`).
   - `R13`: Loop target address register (`loop`).
   - `R14`: ROM pointer with hardware prefetch buffering (`ROMB`, `GETB`, `GETC`).
   - `R15`: Program Counter (`PC`).

---

## 3. SuperFX Assembly Programming Rules

1. **Prefix vs Non-Prefix Instructions**:
   - `with Rn`, `to Rn`, `from Rn` are prefix instructions that modify `Sreg` or `Dreg` for the *immediately following* instruction only.
   - Arithmetic and branch operations (`add #2`, `sub #4`, `not`, etc.) execute and immediately reset `Sreg` and `Dreg` to `R0`.
   - Always specify `with Rn` when adjusting pointers (e.g. `with r0; add #2`). A bare `add #2` operates on the previous destination register or `R0`.
2. **Loop Preservation**:
   - Hardware `loop` decrements `R12` and branches to `R13` if non-zero.
   - Any subroutine called within a loop may clobber `R12` or `R13`.
   - Always push `R12` and `R13` to the stack (`gsu_stack_push r12; gsu_stack_push r13`) before function calls, and restore them (`gsu_stack_pop r13; gsu_stack_pop r12`) before `loop`.
   - **Never push temporary variables inside `for ... endfor` macros**, because `endfor` invokes `restoreloop` and expects `R13`/`R12` at the top of the stack.
3. **Word Alignment**:
   - All 16-bit word loads (`ldw`) and stores (`stw`) must occur at even memory addresses.
   - Ensure the linker configuration `Map.cfg` includes `align = $2` on `GSURAM`:
     ```cfg
     GSURAM: load = SRAM, type = bss, define = yes, align = $2;
     ```
4. **Pipelined Write Settling**:
   - SuperFX RAM writes are pipelined and execute asynchronously across multiple clock cycles.
   - Before ending a test or reading memory in Lua callbacks, insert 8 consecutive `nop`s to allow all pending stores to commit to RAM.

---

## 4. Automated Testing Framework

Unit testing uses the headless Mesen CE emulator with Lua verification scripts:
- **Skill**: [`create-gsu-test`](.agents/skills/create-gsu-test/SKILL.md)
- **Scaffolding**: `python3 .agents/skills/create-gsu-test/scripts/setup_test.py <test_name>`
- **Building**: `make -C tests/<test_name> clean all`
- **Symbol Extraction**: `python3 .agents/skills/create-gsu-test/scripts/extract_syms.py tests/<test_name>/Test.cpu.sym`
- **Execution**: `./.agents/skills/create-gsu-test/scripts/run_test.sh tests/<test_name> 10`

### Mesen CLI Flags:
Always pass `--testRunner` (or `--testrunner`). Never pass `--test-runner` (with hyphen), which inadvertently launches GUI mode.

---

## 5. Technical Documentation References

Detailed references are maintained in `.agents/skills/create-gsu-test/references/`:
- [FX3 Specifications](.agents/skills/create-gsu-test/references/fx3_specifications.md): Memory maps, clock speeds, simultaneous bus access, and MERGE workaround.
- [SuperFX Instruction Set](.agents/skills/create-gsu-test/references/superfx_instruction_set.md): Complete opcode matrix, flag behaviors, prefix registers, and machine cycles.
- [SuperFX Guide](.agents/skills/create-gsu-test/references/superfx_guide.md): Hardware register map, bus contention, and pipeline settling requirements.
- [Mesen CE Lua API Guide](.agents/skills/create-gsu-test/references/mesen_lua_api.md): Execution callbacks (`emu.callbackType.exec`), GSU work RAM reads (`emu.readWord`), and exit codes (`emu.stop(0)`).
