-- test.lua - Mesen test script for Multi-Surface & Architectural Shape Archetypes (Ticket 6)
test_setup = 0x25E8
test_stop  = 0x2A5C
TEST_CASE_IDX = 0x35F4
TEST_RESULT   = 0x35F6

local index = 1
local fail_count = 0
local TOTAL_CASES = 4

local case_names = {
    [1] = "PRIM_LIQUID (Shallow +1h & Deep +2h) Dual-Quad Trap Compilation & Surface Types",
    [2] = "PRIM_PILLAR (+2h Column & Cap) Across All 4 Yaw Quadrants",
    [3] = "PRIM_FOLIAGE_CROSS (4-Fin Billboard Sorting) Across All 4 Yaw Quadrants",
    [4] = "End-to-End Architectural Scene (Liquid, Pillar, Foliage, Skirts) Rendering"
}

function runCase(idx)
    emu.writeWord(TEST_CASE_IDX, idx, emu.memType.gsuWorkRam)
end

function onTestSetup(address, value)
    print("==================================================================")
    print(" Starting test_architectural_archetypes Unit Test Suite")
    print("==================================================================")
    runCase(index)
end

function onTestStop(address, value)
    local s0 = emu.readWord(TEST_RESULT + 0, emu.memType.gsuWorkRam, false)
    local s1 = emu.readWord(TEST_RESULT + 2, emu.memType.gsuWorkRam, false)
    local s2 = emu.readWord(TEST_RESULT + 4, emu.memType.gsuWorkRam, false)
    local s3 = emu.readWord(TEST_RESULT + 6, emu.memType.gsuWorkRam, false)

    local passed = false
    local detail = ""

    if index == 1 then
        -- Case 1: PRIM_LIQUID (Shallow +1h and Deep +2h)
        -- s0: shallow trap count (exp > 0)
        -- s1: deep trap count (exp > 0)
        -- s2: riverbed tex_id (exp = 1)
        -- s3: water tex_id (exp = 0)
        passed = (s0 > 0) and (s1 > 0) and (s2 == 1) and (s3 == 0)
        detail = string.format("shallow_traps=%d, deep_traps=%d, riverbed_tex=%d, water_tex=%d",
            s0, s1, s2, s3)

    elseif index == 2 then
        -- Case 2: PRIM_PILLAR across 4 yaw quadrants
        -- s0: q0 count (exp > 0)
        -- s1: q1 count (exp > 0)
        -- s2: q2 count (exp > 0)
        -- s3: q3 count (exp > 0)
        passed = (s0 > 0) and (s1 > 0) and (s2 > 0) and (s3 > 0)
        detail = string.format("pillar_traps: Q0=%d, Q1=%d, Q2=%d, Q3=%d",
            s0, s1, s2, s3)

    elseif index == 3 then
        -- Case 3: PRIM_FOLIAGE_CROSS across 4 yaw quadrants
        -- s0: q0 count (exp > 0)
        -- s1: q1 count (exp > 0)
        -- s2: q2 count (exp > 0)
        -- s3: q3 count (exp > 0)
        passed = (s0 > 0) and (s1 > 0) and (s2 > 0) and (s3 > 0)
        detail = string.format("foliage_traps: Q0=%d, Q1=%d, Q2=%d, Q3=%d",
            s0, s1, s2, s3)

    elseif index == 4 then
        -- Case 4: End-to-End Architectural Scene Rendering
        -- s0: water_pixel (exp != 0)
        -- s1: pillar_pixel (exp != 0)
        -- s2: foliage_pixel (exp != 0)
        -- s3: elevated_pixel (exp != 0)
        passed = (s0 ~= 0) and (s1 ~= 0) and (s2 ~= 0) and (s3 ~= 0)
        detail = string.format("water=%04X, pillar=%04X, foliage=%04X, elevated=%04X",
            s0, s1, s2, s3)
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
            print(string.format("TEST PASSED: All %d test_architectural_archetypes tests passed.", TOTAL_CASES))
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
