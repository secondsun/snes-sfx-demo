-- test.lua - Mesen test script for Face-to-Scanline Trapezoid Setup & Interpolation Core
test_setup = 0x0007
test_stop  = 0x063D
TEST_CASE_IDX = 0x1B1C
TEST_RESULT   = 0x1B1E

local index = 1
local fail_count = 0
local TOTAL_CASES = 6

local case_names = {
    [1] = "Screen-Space Backface Culling & Winding Order",
    [2] = "Zero-Height Half Suppression (Flat-Bottom & Flat-Top Triangles)",
    [3] = "Mode 0 Horizontal Surfaces Across Yaw Angles (0, 30, 45, 90 deg)",
    [4] = "Modes 1 & 3 for Vertical Walls & Sloped Faces",
    [5] = "End-to-End Rasterization & Diagonal UV Continuity",
    [6] = "Vertex Pointer Seam (FACE_DEF_FLAG_PTRS)"
}

function runCase(idx)
    emu.writeWord(TEST_CASE_IDX, idx, emu.memType.gsuWorkRam)
end

function onTestSetup(address, value)
    print("==================================================================")
    print(" Starting test_compile_traps Unit Test Suite")
    print("==================================================================")
    runCase(index)
end

function onTestStop(address, value)
    local s0 = emu.readWord(TEST_RESULT + 0, emu.memType.gsuWorkRam, false)
    local s1 = emu.readWord(TEST_RESULT + 2, emu.memType.gsuWorkRam, false)
    local s2 = emu.readWord(TEST_RESULT + 4, emu.memType.gsuWorkRam, false)
    local s3 = emu.readWord(TEST_RESULT + 6, emu.memType.gsuWorkRam, false)
    local s4 = emu.readWord(TEST_RESULT + 8, emu.memType.gsuWorkRam, false)
    local s5 = emu.readWord(TEST_RESULT + 10, emu.memType.gsuWorkRam, false)
    local s6 = emu.readWord(TEST_RESULT + 12, emu.memType.gsuWorkRam, false)
    local s7 = emu.readWord(TEST_RESULT + 14, emu.memType.gsuWorkRam, false)

    local passed = false
    local detail = ""

    if index == 1 then
        -- Case 1: Culling
        -- Subtest 1: CCW tri (exp 0)
        -- Subtest 2: Collinear tri (exp 0)
        -- Subtest 3: CCW quad (exp 0)
        -- Subtest 4: CW tri (exp > 0)
        passed = (s0 == 0) and (s1 == 0) and (s2 == 0) and (s3 > 0)
        detail = string.format("ccw_tri=%d (exp 0), collin=%d (exp 0), ccw_quad=%d (exp 0), cw_tri=%d (exp >0)",
            s0, s1, s2, s3)

    elseif index == 2 then
        -- Case 2: Zero-height suppression
        -- Subtest 1: Flat-bottom [0, 16): s0=1 (exp 1), s1=0 (exp 0), s2=16 (exp 16)
        -- Subtest 2: Flat-top [16, 32): s3=1 (exp 1), s4=0 (exp 0), s5=16 (exp 16)
        passed = (s0 == 1) and (s1 == 0) and (s2 == 16) and (s3 == 1) and (s4 == 0) and (s5 == 16)
        detail = string.format("fb_cnt=%d, dy=%d, lc=%d | ft_cnt=%d, dy=%d, lc=%d",
            s0, s1, s2, s3, s4, s5)

    elseif index == 3 then
        -- Case 3: Mode 0 yaw angles
        -- 0 deg:  du_dx = 0x0100, dv_dx = 0x0000
        -- 30 deg: du_dx = 0x00DD, dv_dx = 0xFFE0
        -- 45 deg: du_dx = 0x00B5, dv_dx = 0xFFD3
        -- 90 deg: du_dx = 0x0000, dv_dx = 0xFFC0
        local match0  = (math.abs(s0 - 0x0100) <= 1) and (math.abs(s1 - 0x0000) <= 1)
        local match30 = (math.abs(s2 - 0x00DD) <= 2) and (math.abs(s3 - 0xFFE0) <= 2)
        local match45 = (math.abs(s4 - 0x00B5) <= 2) and (math.abs(s5 - 0xFFD3) <= 2)
        local match90 = (math.abs(s6 - 0x0000) <= 1) and (math.abs(s7 - 0xFFC0) <= 2)
        passed = match0 and match30 and match45 and match90
        detail = string.format("0°:(%04X,%04X), 30°:(%04X,%04X), 45°:(%04X,%04X), 90°:(%04X,%04X)",
            s0, s1, s2, s3, s4, s5, s6, s7)

    elseif index == 4 then
        -- Case 4: Modes 1, 2, 3
        -- Subtest 1: Mode 1 Quad (s0=cnt (exp 4), s1=du_dx (exp ~0x0100), s2=dv_dx (exp ~0))
        -- Subtest 2: Mode 3 Sloped Quad (s3=cnt (exp 2), s4=du_dx, s5=dv_dx)
        local mode1_ok = (s0 == 4) and (math.abs(s1 - 0x0100) <= 2)
        local mode3_ok = (s3 == 2)
        passed = mode1_ok and mode3_ok
        detail = string.format("mode1_cnt=%d, du=%04X, dv=%04X | mode3_cnt=%d, du=%04X, dv=%04X",
            s0, s1, s2, s3, s4, s5)

    elseif index == 5 then
        -- Case 5: End-to-end rasterization
        -- s0 = trap_count (exp 4)
        -- s1 = diamond center (exp ~= 0)
        -- s2 = diagonal seam (exp ~= 0)
        -- s3 = outside diamond (exp == 0)
        passed = (s0 == 4) and (s1 ~= 0) and (s2 ~= 0) and (s3 == 0)
        detail = string.format("cnt=%d (exp 4), center=%04X (exp !=0), seam=%04X (exp !=0), outside=%04X (exp 0)",
            s0, s1, s2, s3)

    elseif index == 6 then
        -- Case 6: Pointer seam
        -- s0 = trap_count (exp 2)
        -- s1 = dy_start (exp 10)
        -- s2 = line_count (exp 16)
        -- trap[0] has left edge along diagonal (dxL = 0x0200) and right edge vertical (dxR = 0)
        passed = (s0 == 2) and (s1 == 10) and (s2 == 16) and (s3 == 0x0200) and (s4 == 0)
        detail = string.format("cnt=%d (exp 2), dy=%d (exp 10), lc=%d (exp 16), dxL=%04X (exp 0200), dxR=%04X (exp 0)",
            s0, s1, s2, s3, s4)
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
            print(string.format("TEST PASSED: All %d test_compile_traps tests passed.", TOTAL_CASES))
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
