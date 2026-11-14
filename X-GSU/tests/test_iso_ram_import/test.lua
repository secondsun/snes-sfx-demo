-- test.lua - Mesen test script for `gsu_iso_import_bank71` & Dynamic Stride
io.stdout:setvbuf("no")
test_setup    = 0x35A3
test_stop     = 0x38DF
TEST_CASE_IDX = 0x7EDE
TEST_RESULT   = 0x7EE0

local index = 1
local fail_count = 0
local TOTAL_CASES = 4

local case_names = {
    [1] = "Valid .tab + 8x8 .map Bank-$71 Import, Pre-Bake & Metadata",
    [2] = "Error Validation (Bad Magic, Bad Count, Bad Dim) & RAMBR==0 Safety",
    [3] = "Dynamic Runtime stride_shift (5 vs 7) + Live 128px-Wide Atlas Render",
    [4] = "SFX_LOAD_MODE_MAP (Yaw Preserved) vs SFX_LOAD_MODE_LEVEL (Full Reset)"
}

function runCase(idx)
    emu.writeWord(TEST_CASE_IDX, idx, emu.memType.gsuWorkRam)
end

function onTestSetup(address, value)
    print("==================================================================")
    print(" Starting test_iso_ram_import Unit Test Suite")
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
    local r6 = emu.readWord(TEST_RESULT + 12, emu.memType.gsuWorkRam, false)
    local r7 = emu.readWord(TEST_RESULT + 14, emu.memType.gsuWorkRam, false)

    local passed = false
    local detail = ""

    if index == 1 then
        passed = (r0 == 0) and (r1 == 0xBEEF) and (r2 == 0x0800) and (r3 == 0x1400)
             and (r4 == 0xBACE) and (r5 == 0x2222) and (r6 == 0xFFFF) and (r7 == 1)
        detail = string.format("status=%d, sentinel=%04X, v32=%04X, tab1_off=%04X, magic=%04X, drops=%04X, cached_yaw=%04X, init=%d",
            r0, r1, r2, r3, r4, r5, r6, r7)
    elseif index == 2 then
        passed = (r0 == 1) and (r1 == 0xBEEF) and (r2 == 2) and (r3 == 3) and (r4 == 0xBEEF)
        detail = string.format("err_magic=%d (exp 1), sent1=%04X, err_cnt=%d (exp 2), err_dim=%d (exp 3), sent2=%04X",
            r0, r1, r2, r3, r4)
    elseif index == 3 then
        passed = (r0 == 0x0200) and (r1 == 0x0400) and (r2 == 7) and (r3 == 0x1000) and (r4 == 6)
        detail = string.format("s5_v16=%04X, s5_v32=%04X, s7_shift=%d, s7_v32=%04X, center_px=%d (exp 6)",
            r0, r1, r2, r3, r4)
    elseif index == 4 then
        passed = (r0 == 30) and (r1 == 128) and (r2 == 80) and (r3 == 0) and (r4 == 1)
        detail = string.format("map_yaw=%d (exp 30), cx=%d, cy=%d, cam_x=%d, lvl_yaw=%d (exp 1)",
            r0, r1, r2, r3, r4)
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
            print(string.format("TEST PASSED: All %d test_iso_ram_import tests passed.", TOTAL_CASES))
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
