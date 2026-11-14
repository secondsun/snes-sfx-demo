-- test.lua - Mesen test script for End-to-End 65816 MSU-1 AssetSource -> Bank $71 -> GSU
io.stdout:setvbuf("no")
test_setup    = 0x35C8
test_stop     = 0x378D
TEST_CASE_IDX = 0x7DAC
TEST_RESULT   = 0x7DAE

local index = 1
local fail_count = 0
local TOTAL_CASES = 4

local case_names = {
    [1] = "sfx_msu1_detect ('S-MSU1') & 32-Bit Seek (>64 KB) Streaming to Bank $71 + CGRAM",
    [2] = "MSU-1 Resident atlas_id=0 Cache Hit & SFX_LOAD_MAP Stream Hot-Swap",
    [3] = "MSU-1 Multi-Atlas Switch ($00016000) & Restore ($00012000)",
    [4] = "Bit-Exact Render Parity Between MSU-1 & ROM AssetSource (yaw=15)"
}

function runCase(idx)
    emu.writeWord(TEST_CASE_IDX, idx, emu.memType.gsuWorkRam)
end

function onTestSetup(address, value)
    print("==================================================================")
    print(" Starting test_cpu_msu1_loader Unit Test Suite")
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
        passed = (r0 == 1) and (r1 == 0x8000) and (r2 == 0x5453)
             and (r3 == 0x2247) and (r4 == 0x2247) and (r5 == 1)
        detail = string.format("msu_detect=%d, db_lock=%04X, tab_magic=%04X, pal71[2]=%04X, cgram[2]=%04X, loads=%d",
            r0, r1, r2, r3, r4, r5)
    elseif index == 2 then
        passed = (r0 == 1) and (r1 == 0xDEAD) and (r2 == 0x0404)
             and (r3 == 96) and (r4 == 2)
        detail = string.format("loads=%d, sentinel=%04X, dims=%04X, origin_x=%d, mode=%d",
            r0, r1, r2, r3, r4)
    elseif index == 3 then
        passed = (r0 == 2) and (r1 == 0x0B0B) and (r2 == 0x5AD6)
             and (r3 == 3) and (r4 == 0x2247)
        detail = string.format("loads2=%d, w1[0]=%04X, cgram1[2]=%04X, loads3=%d, cgram0[2]=%04X",
            r0, r1, r2, r3, r4)
    elseif index == 4 then
        passed = (r0 == 0) and (r1 == 3383) and (r2 == 3763)
             and (r3 == 281) and (r4 == 389) and (r5 == 142)
        detail = string.format("err=%d, grass=%d, stone=%d, water=%d, roof=%d, parapet=%d",
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
            print(string.format("TEST PASSED: All %d test_cpu_msu1_loader tests passed.", TOTAL_CASES))
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
