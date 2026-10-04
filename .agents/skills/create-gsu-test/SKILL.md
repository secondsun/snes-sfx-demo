---
name: create-gsu-test
description: >-
  Creates, configures, and executes automated SuperFX (GSU) unit tests using the
  tests/test_template framework. Use whenever asked to create, write, or run a test
  for SuperFX assembly code, GSU macros (e.g. rom_to_ram, stack macros), or math/decompression
  routines.
---

# Creating GSU Unit Tests

This skill guides the creation of automated unit tests for SuperFX (GSU) assembly functions and macros using `tests/test_template` as the foundation, ca65/ld65/libSFX for compilation, and Mesen CE's headless Lua test runner for verification.

---

## Workflow Overview

1. **Scaffold Directory**: Copy `tests/test_template` to `tests/<test_name>/`.
2. **Configure Title**: Update `ROM_TITLE` in `libSFX.cfg` (exactly 21 characters).
3. **SNES Harness (`Test.s`)**: Define test input data in `.segment "GSUDATA"` (ROM Bank `$04`) if needed.
4. **GSU Harness (`Test.sgs`)**: Allocate buffers in `.segment "GSURAM"`, invoke the code under test in `GSUCODE`, let memory settle with NOPs, and halt at `test_stop:`.
5. **Build**: Run `make clean all` in `tests/<test_name>/`.
6. **Extract Symbols**: Parse `Test.cpu.sym` to check word alignment and get 16-bit RAM offsets.
7. **Write Lua Assertions (`test.lua`)**: Hook `test_stop` execution callback on GSU (`cpuType = 4`), inspect RAM, validate against expectations, and call `emu.stop(0)` or `emu.stop(1)`.
8. **Execute**: Run `Mesen --testRunner test.lua Test.sfc`.

---

## Step-by-Step Instructions

### Step 1: Scaffold Test Directory
Use the helper script [setup_test.py](./scripts/setup_test.py) to clone `test_template` and set up `libSFX.cfg`:

```bash
python3 .agents/skills/create-gsu-test/scripts/setup_test.py <test_name>
```

Alternatively, copy manually:
```bash
mkdir -p tests/<test_name>
cp tests/test_template/{Makefile,Map.cfg,libSFX.cfg,Test.s,Test.sgs,test.lua} tests/<test_name>/
```
If copying manually, edit `libSFX.cfg` to set `define "ROM_TITLE", "<NAME_PADDED_TO_21_CHARS>"`.

---

### Step 2: Configure SNES Assembly (`Test.s`)
If the test requires ROM data (e.g., testing `rom_to_ram` or decompression), place it in `.segment "GSUDATA"` and export the symbol:

```assembly
.segment "GSUDATA"
test_rom_data:
.export test_rom_data
    .byte $DE, $AD, $BE, $EF, $CA, $FE, $BA, $BE
```
*Note*: `GSUDATA` maps to ROM Bank `$04` starting at offset `$8000`.

---

### Step 3: Configure GSU Assembly (`Test.sgs`)
Modify `Test.sgs`:
1. **Include Dependencies**: Include necessary macro files at the top (e.g. `../../common/util.i`, `../../common/stack.i`).
2. **Allocate RAM Buffers**:
   ```assembly
   .segment "GSURAM"
   OUTPUT:
   .res 8
   ```
   Ensure buffers are **word-aligned** (even address). If `Test.cpu.sym` shows an odd address, prepend `.res 1`.
3. **Invoke Routine**:
   In `test_start:`, call the macro or function under test.
4. **Memory Settling NOPs**:
   SuperFX RAM stores are pipelined/asynchronous. Insert 8 `nop`s before `test_stop:` so buffered writes commit to RAM before Lua intercepts execution.
5. **Halt**:
   ```assembly
   test_stop:
       nop
       nop
       stop
       nop
   ```

---

### Step 4: Build Test
Compile the test ROM:

```bash
make -C tests/<test_name> clean all
```
Ensure build succeeds with exit code 0.

---

### Step 5: Extract Symbols & Check Word Alignment
Use [extract_syms.py](./scripts/extract_syms.py) to inspect `Test.cpu.sym` and update `test.lua`:

```bash
python3 .agents/skills/create-gsu-test/scripts/extract_syms.py tests/<test_name>/Test.cpu.sym --update-lua tests/<test_name>/test.lua
```

Verify that all data buffers (`INPUT`, `OUTPUT`) are reported as **word-aligned**.

---

### Step 6: Configure Lua Test Assertions (`test.lua`)
Edit `tests/<test_name>/test.lua`:
- Intercept `test_stop`:
  ```lua
  emu.addMemoryCallback(onTestStop, emu.callbackType.exec, test_stop, test_stop, 4, emu.memType.gsuWorkRam)
  ```
  *(Note: cpuType `4` is GSU, memoryType is `emu.memType.gsuWorkRam`).*
- Read memory using `emu.read(...)` (bytes) or `emu.readWord(...)` / `emu.read16(...)` (words).
- Log results using `print(...)` so they output to `stdout` in test runner mode.
- Call `emu.stop(0)` on PASS, `emu.stop(1)` on FAIL.

---

### Step 7: Run and Verify Test
Run using [run_test.sh](./scripts/run_test.sh) or directly with Mesen:

```bash
# Using helper script
./.agents/skills/create-gsu-test/scripts/run_test.sh tests/<test_name> 10

# Or directly with Mesen:
Mesen --testRunner --timeout=10 tests/<test_name>/test.lua tests/<test_name>/Test.sfc
```

> [!IMPORTANT]
> Always pass `--testRunner` (or `--testrunner`). Do **NOT** include a hyphen (`--test-runner`), which causes Mesen to launch GUI mode instead of headless runner mode.

---

## Additional References & Examples

- [SuperFX 3 (FX3) Specifications](./references/fx3_specifications.md): Randy Linden's FX3 technical specifications, memory maps, simultaneous bus access, and MERGE macro workaround.
- [SuperFX Instruction Set Reference](./references/superfx_instruction_set.md): Complete GSU instruction manual, opcodes, machine cycles, flag behavior, and pipeline delay slots.
- [Mesen CE Lua API Guide](./references/mesen_lua_api.md): Complete API docs for callbacks, memory read/write, and CLI flags.
- [SuperFX Test Guide](./references/superfx_guide.md): Hardware register conventions, pipeline settling, and memory mapping.
- [rom_to_ram Complete Example](./examples/rom_to_ram_example.md): End-to-end code for the `rom_to_ram` unit test.
