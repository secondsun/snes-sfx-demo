# Mesen CE Lua Test Runner Reference

This guide documents the Mesen CE Lua scripting interface for automated SuperFX / SNES test suites.

---

## 1. Command-Line Invocation

Mesen supports a headless test runner mode via the `--testRunner` CLI flag.

```bash
Mesen --testRunner [--timeout=N] test.lua Test.sfc
```

### Critical Syntax Rules
- **Use `--testRunner` (or `--testrunner`)**: Do **NOT** use `--test-runner` with a hyphen between "test" and "runner". Mesen's CLI parser strictly strips leading hyphens/slashes and checks for `testrunner`. If a hyphen is kept (`test-runner`), Mesen will not activate test runner mode and will instead launch in interactive GUI mode.
- **Script Extension**: The script argument passed to `--testRunner` **must end in `.lua`**. Mesen checks the file extension to distinguish between scripts and ROMs.
- **Timeout**: Use `--timeout=N` (in seconds, e.g. `--timeout=10`) to safeguard against infinite loops. Default timeout is 100 seconds.

---

## 2. Terminal Output: `print()` vs `emu.log()`

- **`print(...)`**: Prints directly to terminal `stdout` in testrunner mode. Use `print()` so test logs and failure messages are immediately visible in the shell or CI logs.
- **`emu.log(...)`**: Appends to the internal Mesen GUI debugger log buffer (`ScriptingContext`). In headless mode, this does not print to stdout unless `--enableStdout` is also specified.
- **Recommended Practice**: Call both or create a helper:
  ```lua
  function log(msg)
      print(msg)
      emu.log(msg)
  end
  ```

---

## 3. Registering Memory & Execution Callbacks

Use `emu.addMemoryCallback` to intercept execution breakpoints or memory accesses:

```lua
emu.addMemoryCallback(
    callbackFn,
    callbackType,
    startAddress,
    endAddress,
    cpuType,
    memoryType
)
```

### Parameters
1. **`callbackFn`**: Lua function taking `(address, value)`.
2. **`callbackType`**:
   - `emu.callbackType.exec` (execution breakpoint)
   - `emu.callbackType.read` (memory read)
   - `emu.callbackType.write` (memory write)
3. **`startAddress`**: Lower 16-bit address (strip bank `$70` from symbol address in `Test.cpu.sym`).
4. **`endAddress`**: Ending address (pass same as `startAddress` for a single address).
5. **`cpuType`**:
   - **`4`**: SuperFX / GSU coprocessor.
   - `0` (`emu.cpuType.snes`): Main SNES 65816 CPU.
6. **`memoryType`**:
   - `emu.memType.gsuWorkRam`: SuperFX Work RAM (covers GSU code and data segments).

---

## 4. Reading and Writing Memory

All memory offsets are 16-bit relative to GSU Work RAM (`$0000` to `$7FFF` / `$FFFF`):

```lua
-- 8-bit Byte
local b = emu.read(addr, emu.memType.gsuWorkRam, false)
emu.write(addr, 0x55, emu.memType.gsuWorkRam)

-- 16-bit Word (Little-Endian)
local w = emu.read16(addr, emu.memType.gsuWorkRam, false) -- or emu.readWord(...)
emu.write16(addr, 0x1234, emu.memType.gsuWorkRam)          -- or emu.writeWord(...)

-- 32-bit DWord
local dw = emu.read32(addr, emu.memType.gsuWorkRam, false)
emu.write32(addr, 0x12345678, emu.memType.gsuWorkRam)
```

The third argument `signed` specifies whether the return value should be sign-extended (`true`) or unsigned (`false`).

---

## 5. Test Lifecycle & Completion

- **Finish / Exit**:
  ```lua
  emu.stop(exitCode)
  ```
  Exits the Mesen process immediately with the specified integer exit code:
  - `0`: PASS
  - `1` (or non-zero): FAIL

- **Break & Resume**:
  ```lua
  emu.breakExecution() -- Pauses emulation
  emu.resume()         -- Resumes emulation
  ```
  If a callback pauses execution (for example, to inject test vectors at `test_setup`), always call `emu.resume()` when ready to continue. If `emu.resume()` is omitted and `emu.stop()` is not called, Mesen will wait until the timeout.
