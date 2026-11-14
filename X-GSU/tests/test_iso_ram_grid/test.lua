-- test.lua - Mesen test script for `gsu_iso_map.i` 16x16 Grids, Skirts, Panels & Archetypes
io.stdout:setvbuf("no")
test_setup    = 0x3633
test_stop     = 0x3D97
TEST_CASE_IDX = 0x8396
TEST_RESULT   = 0x8398

local index = 1
local fail_count = 0
local TOTAL_CASES = 4

local case_names = {
    [1] = "Non-Square 6x4 Traversal Order Across All 4 Yaw Quadrants",
    [2] = "Maximum 16x16 (256 Cells, 2056B) Import, Viewport Culling & Corner (15,15) Render",
    [3] = "Bank-$71 Stepped Skirts + 2h Edge Panels Live Render",
    [4] = "Bank-$71 Architectural Archetypes (Wedge, Pillar, Foliage Cross) Render"
}

function runCase(idx)
    emu.writeWord(TEST_CASE_IDX, idx, emu.memType.gsuWorkRam)
end

function onTestSetup(address, value)
    print("==================================================================")
    print(" Starting test_iso_ram_grid Unit Test Suite")
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
        passed = (r0 == 24) and (r1 == 0x0000) and (r2 == 0x0503)
             and (r3 == 0x0003) and (r4 == 0x0503) and (r5 == 0x0500)
        detail = string.format("cnt=%d, Q0=[%04X..%04X], Q1[0]=%04X, Q2[0]=%04X, Q3[0]=%04X",
            r0, r1, r2, r3, r4, r5)
    elseif index == 2 then
        passed = (r0 == 205) and (r1 == 0x1010) and (r2 == 5) and (r3 == 3)
        detail = string.format("vis_cnt=%d (exp 205/256), dims=%04X (exp 1010), px(15,15)=%d (exp 5), px(14,15)=%d (exp 3)",
            r0, r1, r2, r3)
    elseif index == 3 then
        passed = (r0 > 0) and (r1 > 0) and (r2 > 0)
        detail = string.format("floor_px=%d, skirt_px=%d, panel_2h_px=%d (all > 0)", r0, r1, r2)
    elseif index == 4 then
        passed = (r0 == 0x0C03) and (r1 > 0) and (r2 > 0) and (r3 > 0)
        detail = string.format("arch_mask=%04X (exp 0C03), wedge_px=%d, pillar_px=%d, foliage_px=%d",
            r0, r1, r2, r3)
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
            print(string.format("TEST PASSED: All %d test_iso_ram_grid tests passed.", TOTAL_CASES))
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
