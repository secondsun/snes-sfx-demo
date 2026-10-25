-- test.lua - Mesen test script for Rotatable Sloped & Stepped Shape Archetypes
test_setup = 0x20BD
test_stop  = 0x23B1
TEST_CASE_IDX = 0x2F0A
TEST_RESULT   = 0x2F0C

local index = 0x0004
local fail_count = 0
local TOTAL_CASES = 4

local case_names = {
    [1] = "PRIM_WEDGE_STRAIGHT (+1h and +2h) Across All 4 Rotations",
    [2] = "PRIM_WEDGE_OUTER & PRIM_WEDGE_INNER Across All 4 Rotations",
    [3] = "PRIM_STAIRS (arch=7) Across All 4 Rotations",
    [4] = "End-to-End Stepped Ridge, Valley & Stairway Map Grid Rendering"
}

function runCase(idx)
    emu.writeWord(TEST_CASE_IDX, idx, emu.memType.gsuWorkRam)
end

function onTestSetup(address, value)
    print("==================================================================")
    print(" Starting test_slopes_stairs Unit Test Suite")
    print("==================================================================")
    runCase(index)
end

function onTestStop(address, value)
    local s0 = emu.readWord(TEST_RESULT + 0, emu.memType.gsuWorkRam, false)
    local s1 = emu.readWord(TEST_RESULT + 2, emu.memType.gsuWorkRam, false)
    local s2 = emu.readWord(TEST_RESULT + 4, emu.memType.gsuWorkRam, false)
    local s3 = emu.readWord(TEST_RESULT + 6, emu.memType.gsuWorkRam, false)
    local s4 = emu.readWord(TEST_RESULT + 8, emu.memType.gsuWorkRam, false)

    local passed = false
    local detail = ""

    if index == 1 then
        -- Case 1: PRIM_WEDGE_STRAIGHT
        -- s0: rot0 count (exp > 0)
        -- s1: rot90 count (exp > 0)
        -- s2: rot180 count (exp > 0)
        -- s3: rot270 count (exp > 0)
        -- s4: 2h rot0 count (exp > 0)
        passed = (s0 > 0) and (s1 > 0) and (s2 > 0) and (s3 > 0) and (s4 > 0)
        detail = string.format("straight_1h: rot0=%d, rot90=%d, rot180=%d, rot270=%d | straight_2h: rot0=%d",
            s0, s1, s2, s3, s4)

    elseif index == 2 then
        -- Case 2: PRIM_WEDGE_OUTER & INNER
        -- s0: outer rot0 (exp > 0)
        -- s1: outer rot90 (exp > 0)
        -- s2: outer rot180 (exp > 0)
        -- s3: outer rot270 (exp > 0)
        -- s4: inner rot0 (exp > 0)
        passed = (s0 > 0) and (s1 > 0) and (s2 > 0) and (s3 > 0) and (s4 > 0)
        detail = string.format("outer: rot0=%d, rot90=%d, rot180=%d, rot270=%d | inner: rot0=%d",
            s0, s1, s2, s3, s4)

    elseif index == 3 then
        -- Case 3: PRIM_STAIRS
        -- s0: stairs rot0 (exp > 0)
        -- s1: stairs rot90 (exp > 0)
        -- s2: stairs rot180 (exp > 0)
        -- s3: stairs rot270 (exp > 0)
        passed = (s0 > 0) and (s1 > 0) and (s2 > 0) and (s3 > 0)
        detail = string.format("stairs: rot0=%d, rot90=%d, rot180=%d, rot270=%d",
            s0, s1, s2, s3)

    elseif index == 4 then
        -- Case 4: End-to-End Stepped Ridge, Valley & Stairway Rendering
        -- s0: floor_00 (exp != 0)
        -- s1: wedge_10 (exp != 0)
        -- s2: stairs_01 (exp != 0)
        passed = (s0 ~= 0) and (s1 ~= 0) and (s2 ~= 0)
        detail = string.format("floor_00=%04X, wedge_10=%04X, stairs_01=%04X",
            s0, s1, s2)
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
            print(string.format("TEST PASSED: All %d test_slopes_stairs tests passed.", TOTAL_CASES))
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

emu.addMemoryCallback(onTestSetup,
                      emu.callbackType.exec,
                      test_setup,
                      test_setup,
                      4,
                      emu.memType.gsuWorkRam)

emu.addMemoryCallback(onTestStop,
                      emu.callbackType.exec,
                      test_stop,
                      test_stop,
                      4,
                      emu.memType.gsuWorkRam)
