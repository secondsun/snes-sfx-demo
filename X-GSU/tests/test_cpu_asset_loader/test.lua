-- test.lua - Mesen test script for 65816 Bank-$71 Host Loader & ROM AssetSource
io.stdout:setvbuf("no")
test_setup    = 0x3561
test_stop     = 0x3733
TEST_CASE_IDX = 0x7D5A
TEST_RESULT   = 0x7D5C

local index = 1
local fail_count = 0
local TOTAL_CASES = 4

local case_names = {
    [1] = "32 KB Max-Capacity Atlas Copy ($85->$71), DB==$80, Lock==0 & CGRAM[1]",
    [2] = "Resident atlas_id=0 Deduplication Cache Hit ($DEAD Sentinel Preserved)",
    [3] = "Resident atlas_id=1 Cache Miss ($86->$71) & CGRAM Palette Swap",
    [4] = "SFX_LOAD_MAP Map-Only Hot-Swap (Mode=2) + Live GSU Import & Render"
}

function runCase(idx)
    emu.writeWord(TEST_CASE_IDX, idx, emu.memType.gsuWorkRam)
end

function onTestSetup(address, value)
    print("==================================================================")
    print(" Starting test_cpu_asset_loader Unit Test Suite")
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
        passed = (r0 == 0x1122) and (r1 == 0x3344) and (r2 == 0x7788)
             and (r3 == 0x14A5) and (r4 == 0x8000) and (r5 == 1)
        detail = string.format("w[0]=%04X, w[4000]=%04X, w[7FFE]=%04X, cgram[1]=%04X, db_lock=%04X, loads=%d",
            r0, r1, r2, r3, r4, r5)
    elseif index == 2 then
        passed = (r0 == 1) and (r1 == 0xDEAD) and (r2 == 111)
             and (r3 == 1) and (r4 == 0)
        detail = string.format("loads=%d, sentinel=%04X, origin_x=%d, mode=%d, init_flag=%d",
            r0, r1, r2, r3, r4)
    elseif index == 3 then
        passed = (r0 == 2) and (r1 == 1) and (r2 == 0x0505)
             and (r3 == 0x7C1F) and (r4 == 1) and (r5 == 0)
        detail = string.format("loads=%d, res_id=%d, w[0]=%04X, cgram[1]=%04X, mode=%d, init_flag=%d",
            r0, r1, r2, r3, r4, r5)
    elseif index == 4 then
        passed = (r0 == 2) and (r1 == 2) and (r2 == 0)
             and (r3 == 0) and (r4 == 0x0406) and (r5 > 0)
        detail = string.format("loads=%d, mode=%d, init_flag=%d, err=%d, dims=%04X, px=%d",
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
            print(string.format("TEST PASSED: All %d test_cpu_asset_loader tests passed.", TOTAL_CASES))
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
