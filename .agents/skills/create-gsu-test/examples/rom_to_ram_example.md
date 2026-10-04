# Example Walkthrough: `rom_to_ram` Unit Test

This example demonstrates how to create a complete unit test for the `rom_to_ram` macro from `common/util.i`.

---

## 1. Directory Structure

Inside `tests/rom_to_ram/`:
- `Makefile`
- `Map.cfg`
- `libSFX.cfg`
- `Test.s`
- `Test.sgs`
- `test.lua`

---

## 2. File Implementations

### `libSFX.cfg`
Set the 21-character ROM title:
```ini
define "ROM_TITLE",    "ROM_TO_RAM_TEST      "
```

### `Test.s` (SNES Assembly)
Place test source data in `.segment "GSUDATA"`:
```assembly
.include "libSFX.i"

Main:
        memcpy GSU_SRAM, __GSUCODE_LOAD__, __GSUCODE_SIZE__
        memcpy  __MAIN_LOOP_RUN__, __MAIN_LOOP_LOAD__, __MAIN_LOOP_SIZE__
        memcpy  __VBLANK_RUN__, __VBLANK_LOAD__, __VBLANK_SIZE__
        jml __MAIN_LOOP_RUN__

.SEGMENT "MAIN_LOOP"
        lda     #$70
        sta     GSU_PBR
        lda     #$10
        sta     GSU_SCBR
        lda     #%00111101
        sta     GSU_SCMR
        lda     #%10000000
        sta     GSU_CFGR
        lda     #$01
        sta     GSU_CLSR

        break
        ldx     __GSUCODE_RUN__
        stx     GSU_R15

        CGRAM_setcolor_rgb 0, 31,7,31
        lda     #inidisp(ON, DISP_BRIGHTNESS_MAX)
        sta     SFX_inidisp
        VBL_on
loops:
:       wai
        bra :-

.segment "GSUDATA"
test_rom_data:
.export test_rom_data
    .byte $DE, $AD, $BE, $EF, $CA, $FE, $BA, $BE
```

### `Test.sgs` (GSU Assembly)
Allocate RAM buffer in `GSURAM`, call `rom_to_ram`, allow memory to settle, and stop:
```assembly
.include "../../common/stack.i"
.include "../../common/function.i"
.include "../../common/structs.i"
.include "../../common/var.i"
.include "../../common/util.i"
.include "libSFX.i"

.segment "GSURAM"
; Word-aligned output buffer
OUTPUT:
.res 8

.segment "GSUCODE"
GSU_Code:

init_stack

test_setup:
    nop
    nop

test_start:
    ; Copy 8 bytes from test_rom_data (Bank $04) to OUTPUT in GSURAM
    rom_to_ram test_rom_data, #$04, OUTPUT, 8

    ; Allow asynchronous RAM writes to settle
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

### `test.lua` (Mesen CE Test Runner)
Intercept `test_stop`, read bytes from `OUTPUT`, compare, and report:
```lua
test_setup = 0x0003
test_start = 0x0005
test_stop  = 0x0024
OUTPUT     = 0x041A

function onTestStop(address, value)
    emu.log(string.format("GSU reached test_stop at 0x%04X", address))

    local expected = { 0xDE, 0xAD, 0xBE, 0xEF, 0xCA, 0xFE, 0xBA, 0xBE }
    local pass = true

    for i = 1, #expected do
        local byte_val = emu.read(OUTPUT + i - 1, emu.memType.gsuWorkRam, false)
        local msg = string.format("OUTPUT[%d] = 0x%02X (expected: 0x%02X)", i - 1, byte_val, expected[i])
        print(msg)
        emu.log(msg)
        if byte_val ~= expected[i] then
            pass = false
        end
    end

    if pass then
        print("TEST PASSED: rom_to_ram copied all bytes correctly.")
        emu.stop(0)
    else
        print("TEST FAILED: byte mismatch detected.")
        emu.stop(1)
    end
end

emu.addMemoryCallback(onTestStop,
                      emu.callbackType.exec,
                      test_stop,
                      test_stop,
                      4,
                      emu.memType.gsuWorkRam)
```

---

## 3. Build & Execution Commands

```bash
# Build the test ROM
make -C tests/rom_to_ram clean all

# Extract symbols and update test.lua
python3 .agents/skills/create-gsu-test/scripts/extract_syms.py tests/rom_to_ram/Test.cpu.sym --update-lua tests/rom_to_ram/test.lua

# Run test in Mesen CE headless mode
./.agents/skills/create-gsu-test/scripts/run_test.sh tests/rom_to_ram 5
```
