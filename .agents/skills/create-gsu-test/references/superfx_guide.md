# SuperFX (GSU) Architecture & Test Authoring Guide

This guide summarizes key SuperFX (GSU) hardware concepts, register conventions, memory mapping, and pipeline behaviors necessary for writing unit tests.

---

## 1. Register Architecture & Conventions

The SuperFX coprocessor provides sixteen 16-bit general/special-purpose registers:

| Register | Hardware Function / Convention |
| :--- | :--- |
| **`r0`** | Default accumulator / source / destination for math and memory ops (`getb`, `add`, `sub`). |
| **`r1`** | Pixel plot X coordinate; commonly used as scratch or destination address register. |
| **`r2`** | Pixel plot Y coordinate; general purpose scratch. |
| **`r3` - `r9`** | General-purpose registers. |
| **`r10`** | **Stack Pointer** (by convention). Must be initialized via `init_stack`. Do not clobber outside stack operations. |
| **`r11`** | Link register (set by `link #n` instruction for subroutines). |
| **`r12`** | **Loop Counter**. Decremented by the `loop` instruction. |
| **`r13`** | **Loop Branch Target Address**. Target jumped to by `loop` when `r12 != 0`. |
| **`r14`** | **ROM Address Pointer**. Writing or incrementing `r14` initiates a hardware ROM buffer read. |
| **`r15`** | **Program Counter (PC)**. Writing `r15` branches execution. |

---

## 2. Memory Segmentation in Tests

The test harness uses a custom linker configuration (`Map.cfg`):

### `GSUDATA` (ROM Segment)
- **Start Address**: `$048000` (Bank `$04`, offset `$8000`).
- **Usage**: Store read-only test data, input byte streams, lookup tables, compressed assets.
- **Syntax in `Test.s`**:
  ```assembly
  .segment "GSUDATA"
  test_data:
  .export test_data
      .byte $12, $34, $56, $78
  ```

### `GSUCODE` (Executable Code Segment)
- **Load Address**: ROM0.
- **Run Address**: SRAM `$700000` (Bank `$70`).
- **Usage**: Contains all GSU assembly instructions. Copied to SRAM by the SNES main CPU before GSU start.

### `GSURAM` (Work RAM Segment)
- **Run Address**: SRAM (Bank `$70`).
- **Usage**: Input/output buffers, scratch variables, dynamic results.
- **Syntax in `Test.sgs`**:
  ```assembly
  .segment "GSURAM"
  INPUT:
  .res 2
  OUTPUT:
  .res 8
  ```

---

## 3. Word Alignment Requirements

In the SuperFX architecture, 16-bit word operations (`ldw`, `stw`) require **word alignment (even addresses)**:
- After linking with `make clean all`, check `Test.cpu.sym`.
- Look at the address for `INPUT`, `OUTPUT`, etc. (e.g. `70041A` is even, `70041B` is odd).
- If unaligned, insert `.res 1` before the symbol in `Test.sgs` and rebuild.

---

## 4. Asynchronous RAM Write Pipelining ("Memory Settling")

The GSU hardware uses write buffers with cycle delays for RAM stores (`stb`, `stw`):
- When a loop or function completes writing to RAM, the final byte/word may still be buffered in the pipeline during the next instruction cycle.
- If `test_stop` executes immediately after the store, Lua's execution callback on `test_stop` will fire **before** the final byte reaches RAM!
- **Rule**: Always insert 8 `nop` instructions between the test routine and `test_stop:` to allow the write pipeline to settle:
  ```assembly
  test_start:
      rom_to_ram test_data, #$04, OUTPUT, 8

      ; Allow RAM write pipeline to commit
      nop
      nop
      nop
      nop
      nop
      nop
      nop
      nop

  test_stop:
      nop
      nop
      stop
      nop
  ```

---

## 5. Key Macro APIs

### `rom_to_ram` (`common/util.i`)
Copies a contiguous block of data from SuperFX ROM into RAM.
- **Signature**: `rom_to_ram rom_addr, rom_bank, ram_addr, size`
- **Parameters**:
  - `rom_addr`: ROM label or immediate (e.g. `test_data` or `#test_data`)
  - `rom_bank`: ROM bank number (e.g. `#$04` for `GSUDATA`)
  - `ram_addr`: RAM destination label or register (e.g. `OUTPUT` or `r1`)
  - `size`: Number of bytes to copy (e.g. `8` or `#8`)
- **Clobbers**: `r0`, `r12`, `r13`, `r14`, and destination register.
