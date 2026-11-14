-- test.lua - Mesen test script for Bank-$71 `draw_cached_trap_ram`
io.stdout:setvbuf("no")
test_setup    = 0x0428
test_stop     = 0x0B52
TEST_CASE_IDX = 0x1580
TEST_RESULT   = 0x1582

local index = 1
local fail_count = 0
local TOTAL_CASES = 5

local case_names = {
    [1] = "Bank-$71 Non-Zero atlas_offset ($4200), Color-0 Transparency, 16px Flush & RAMBR==0",
    [2] = "Power-of-Two u_mask / v_mask_shifted Tiling Wrap Across Offsets",
    [3] = "Pass 0 [0..127] vs Pass 1 [128..255] Horizontal Seam Clipping",
    [4] = "Top/Bottom Vertical Clipping & Off-Screen Early-Exit RAMBR==0",
    [5] = "Bit-Exact ROM vs Bank-$71 Pixel Parity on Top-Clipped (@skip_loop) & Left-Clipped (@clip_u_loop) Traps + RAMBR==0"
}

function runCase(idx)
    emu.writeWord(TEST_CASE_IDX, idx, emu.memType.gsuWorkRam)
end

function onTestSetup(address, value)
    print("==================================================================")
    print(" Starting test_draw_cached_trap_ram Unit Test Suite")
    print("==================================================================")
    runCase(index)
end

function onTestStop(address, value)
    local r0 = emu.readWord(TEST_RESULT + 0,  emu.memType.gsuWorkRam, false)
    local r1 = emu.readWord(TEST_RESULT + 2,  emu.memType.gsuWorkRam, false)
    local r2 = emu.readWord(TEST_RESULT + 4,  emu.memType.gsuWorkRam, false)
    local r3 = emu.readWord(TEST_RESULT + 6,  emu.memType.gsuWorkRam, false)
    local r4 = emu.readWord(TEST_RESULT + 8,  emu.memType.gsuWorkRam, false)
    local r5 = emu.readWord(TEST_RESULT + 10, emu.memType.gsuWorkRam, false)

    local passed = false
    local detail = ""

    if index == 1 then
        local b71_tex0 = emu.read(0x14200, emu.memType.gsuWorkRam, false)
        passed = (r0 == 0xBEEF) and (r1 == 2) and (r2 == 3) and (r3 == 9) and (r4 == 2) and (r5 == 5) and (b71_tex0 == 2)
        detail = string.format("sentinel=%04X (exp BEEF), px=[8:%d,9:%d,12_bg:%d,16_wrap:%d,19:%d] (exp 2,3,9,2,5), $71:4200=%d",
            r0, r1, r2, r3, r4, r5, b71_tex0)
    elseif index == 2 then
        passed = (r0 == 6) and (r1 == 5) and (r2 == 4) and (r3 == 3)
        detail = string.format("wrap_quads=[%d,%d,%d,%d] (exp 6,5,4,3)", r0, r1, r2, r3)
    elseif index == 3 then
        passed = (r0 == 0) and (r1 == 7) and (r2 == 7) and (r3 == 7) and (r4 == 7) and (r5 == 0)
        detail = string.format("pass0=[123:%d,124:%d,127:%d] (exp 0,7,7), pass1=[0:%d,3:%d,4:%d] (exp 7,7,0)",
            r0, r1, r2, r3, r4, r5)
    elseif index == 4 then
        passed = (r0 == 0xBEEF) and (r1 == 7) and (r2 == 7) and (r3 == 0)
        detail = string.format("sentinel=%04X (exp BEEF), px(40,0)=%d, px(40,2)=%d, px(40,3)=%d (exp 7,7,0)",
            r0, r1, r2, r3)
    elseif index == 5 then
        passed = (r0 == 0xBEEF) and (r1 == 0xBEEF) and (r2 == 0) and (r3 > 100) and (r4 == r5)
        detail = string.format("sentinel_a=%04X, sentinel_b=%04X (exp BEEF), mismatches=%d (exp 0), nonzero_px=%d, hash_rom=%04X, hash_ram=%04X",
            r0, r1, r2, r3, r4, r5)
    end

    if passed then
        print(string.format("  [%d/%d] PASSED: %s", index, TOTAL_CASES, case_names[index]))
        print(string.format("         Detail: %s", detail))
    else
        print(string.format("  [%d/%d] FAILED: %s", index, TOTAL_CASES, case_names[index]))
        print(string.format("         Detail: %s", detail))
        fail_count = fail_count + 1
    end

    if index >= TOTAL_CASES then
        print("==================================================================")
        if fail_count == 0 then
            print(string.format("TEST PASSED: All %d test_draw_cached_trap_ram tests passed.", TOTAL_CASES))
            emu.stop(0)
        else
            print(string.format("TEST FAILED: %d of %d tests failed.", fail_count, TOTAL_CASES))
            emu.stop(1)
        end
        return
    end

    index = index + 1
    runCase(index)
end

emu.addMemoryCallback(onTestSetup, emu.callbackType.exec, test_setup, test_setup, 4, emu.memType.gsuWorkRam)
emu.addMemoryCallback(onTestStop,  emu.callbackType.exec, test_stop,  test_stop,  4, emu.memType.gsuWorkRam)
