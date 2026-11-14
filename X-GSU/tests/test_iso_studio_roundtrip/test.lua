-- test.lua - Mesen test script for End-to-End `sfx-studio` -> 65816 -> Bank $71 -> GSU Roundtrip
io.stdout:setvbuf("no")
test_setup    = 0x368B
test_stop     = 0x3760
TEST_CASE_IDX = 0x7D66
TEST_RESULT   = 0x7D68

local index = 1
local fail_count = 0
local TOTAL_CASES = 4

local case_names = {
    [1] = "65816 SFX_LOAD_LEVEL Bank-$71 Staging + PPU CGRAM Upload",
    [2] = "GSU gsu_iso_import_bank71 Validation of Studio-Packed .tab & .map",
    [3] = "Full Two-Pass Hardware Rasterization (yaw=15) of All 6 Studio Materials",
    [4] = "Rotated Quadrant (yaw=75) Two-Pass Rasterization & RAMBR==0 Postcondition"
}

function runCase(idx)
    emu.writeWord(TEST_CASE_IDX, idx, emu.memType.gsuWorkRam)
end

function onTestSetup(address, value)
    print("==================================================================")
    print(" Starting test_iso_studio_roundtrip Unit Test Suite")
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

    local passed = false
    local detail = ""

    if index == 1 then
        passed = (r0 == 0x2247) and (r1 == 1) and (r2 == 0)
             and (r3 == 0x5453) and (r4 == 0x2247) and (r5 == 1)
        detail = string.format("cgram[2]=%04X, loads=%d, res_id=%d, tab_magic=%04X, pal71[2]=%04X, mode=%d",
            r0, r1, r2, r3, r4, r5)
    elseif index == 2 then
        passed = (r0 == 0) and (r1 == 6) and (r2 == 6)
             and (r3 == 0xBACE) and (r4 == 0x2020) and (r5 == 0x0D05)
        detail = string.format("err=%d, count=%d, shift=%d, tag=%04X, drops(2,2)=%04X, arch=%04X",
            r0, r1, r2, r3, r4, r5)
    elseif index == 3 then
        passed = (r0 > 0) and (r1 > 0) and (r2 > 0)
             and (r3 > 0) and (r4 > 0) and (r5 > 0)
        detail = string.format("grass=%d, stone=%d, water=%d, roof=%d, parapet=%d, foliage=%d",
            r0, r1, r2, r3, r4, r5)
    elseif index == 4 then
        passed = (r0 > 0) and (r1 > 0) and (r2 > 0)
             and (r3 > 0) and (r4 > 0) and (r5 > 0) and (r6 == 0xBEEF)
        detail = string.format("Q1 grass=%d, stone=%d, water=%d, roof=%d, parapet=%d, foliage=%d, rambr0=%04X",
            r0, r1, r2, r3, r4, r5, r6)
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
            print(string.format("TEST PASSED: All %d test_iso_studio_roundtrip tests passed.", TOTAL_CASES))
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
