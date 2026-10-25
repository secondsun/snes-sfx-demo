-- test.lua - Mesen test script for Map Grid Painter's Traversal & Archetype Stamping
test_setup = 0x1786
test_stop  = 0x1CE5
TEST_CASE_IDX = 0x282E
TEST_RESULT   = 0x2830

local index = 0x0001
local fail_count = 0
local TOTAL_CASES = 4

local case_names = {
    [1] = "Pass-0 Yaw-Dirty ARCH_TRAPS Compilation & Caching",
    [2] = "Yaw-Quadrant Back-to-Front Traversal Order Across All 4 Quadrants",
    [3] = "Bounding Box Culling Against Frame Halves (Pass 0 vs Pass 1)",
    [4] = "Stepped PRIM_FLAT Map Grid Rendering & Watertight Seams"
}

function runCase(idx)
    emu.writeWord(TEST_CASE_IDX, idx, emu.memType.gsuWorkRam)
end

function onTestSetup(address, value)
    print("==================================================================")
    print(" Starting test_map_grid Unit Test Suite")
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
        -- Case 1: Pass-0 Yaw-Dirty Caching
        -- s0: first_call_dirty (exp 1)
        -- s1: flat_count (exp > 0)
        -- s2: second_call_clean (exp 0)
        -- s3: third_call_dirty (exp 1)
        -- s4: cached_yaw (exp 30)
        passed = (s0 == 1) and (s1 > 0) and (s2 == 0) and (s3 == 1) and (s4 == 30)
        detail = string.format("first_dirty=%d (exp 1), flat_cnt=%d, second_clean=%d (exp 0), third_dirty=%d (exp 1), cached_yaw=%d (exp 30)",
            s0, s1, s2, s3, s4)

    elseif index == 2 then
        -- Case 2: Traversal Order across all 4 Quadrants
        -- s0: Q0 match (exp 1)
        -- s1: Q1 match (exp 1)
        -- s2: Q2 match (exp 1)
        -- s3: Q3 match (exp 1)
        local t0 = emu.readWord(TEST_RESULT + 8, emu.memType.gsuWorkRam, false)
        local t8 = emu.readWord(TEST_RESULT + 10, emu.memType.gsuWorkRam, false)
        passed = (s0 == 1) and (s1 == 1) and (s2 == 1) and (s3 == 1)
        detail = string.format("Q0=%d, Q1=%d, Q2=%d, Q3=%d | last_buf[0]=%04X, [8]=%04X",
            s0, s1, s2, s3, t0, t8)

    elseif index == 3 then
        -- Case 3: Bounding Box Culling Against Frame Halves
        -- s0: pass0_count (exp 4)
        -- s1: pass1_count (exp 2)
        -- s2: pass1_first_cell (exp 0x0300)
        local s3 = emu.readWord(TEST_RESULT + 6, emu.memType.gsuWorkRam, false)
        local s4 = emu.readWord(TEST_RESULT + 8, emu.memType.gsuWorkRam, false)
        local s5 = emu.readWord(TEST_RESULT + 10, emu.memType.gsuWorkRam, false)
        passed = (s0 == 4) and (s1 == 2) and (s2 == 0x0300)
        detail = string.format("pass0_cnt=%d (exp 4), pass1_cnt=%d (exp 2), pass1_first=%04X (exp 0300) | bbox_xmin=%d, bbox_xmax=%d, frame_half=%d",
            s0, s1, s2, s3, s4, s5)

    elseif index == 4 then
        -- Case 4: Stepped PRIM_FLAT Map Grid Rendering & Watertight Seams
        -- s0: floor_00 pixel at (73, 48) (exp != 0)
        -- s1: floor_11 pixel at (102, 34) (exp != 0)
        -- s2: skirt_01 pixel at (66, 45) (exp != 0)
        passed = (s0 ~= 0) and (s1 ~= 0) and (s2 ~= 0)
        detail = string.format("floor_00=%04X, floor_11=%04X, skirt_01=%04X",
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
            print(string.format("TEST PASSED: All %d test_map_grid tests passed.", TOTAL_CASES))
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
