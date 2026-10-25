-- test.lua - Mesen test script for CACHE-Resident Affine Textured Scanline Trapezoid Rasterizer
test_setup = 0x0007
test_stop  = 0x04E3
TEST_CASE_IDX = 0x1172
TEST_RESULT   = 0x1174

local index = 1
local fail_count = 0
local TOTAL_CASES = 6

local case_names = {
    [1] = "Texture Wrapping across Power-of-Two (16x16, 32x32, 64x64, 128x128)",
    [2] = "Watertight Half-Open Vertical Stacking ([y0, y1) and [y1, y2))",
    [3] = "Watertight Half-Open Horizontal Adjacency ([x0, x1) and [x1, x2))",
    [4] = "Clipping Against Screen Boundaries ([0, 160) vertical, [0, 128) horizontal)",
    [5] = "Frame Half Horizontal Reassembly (Pass 0 [0..127] and Pass 1 [128..255])",
    [6] = "Color 0 vs Color 1 Transparency (cmode bit 0 = 0 transparency test)"
}

function runCase(idx)
    emu.writeWord(TEST_CASE_IDX, idx, emu.memType.gsuWorkRam)
end

function onTestSetup(address, value)
    print("==================================================================")
    print(" Starting cached_trap Unit Test Suite")
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
        -- Case 1: Wrapping: sample 0 (x=0) == sample 2 (x=16) == sample 4 (x=32)
        --                   sample 1 (x=15) == sample 3 (x=31)
        local match_wrap0 = (s0 == s2) and (s0 == s4)
        local match_wrap1 = (s1 == s3)
        local non_zero    = (s0 ~= 0) and (s1 ~= 0)
        passed = match_wrap0 and match_wrap1 and non_zero
        detail = string.format("s0(x=0)=%04X, s1(x=15)=%04X, s2(x=16)=%04X, s3(x=31)=%04X, s4(x=32)=%04X",
            s0, s1, s2, s3, s4)

    elseif index == 2 then
        -- Case 2: Vertical Stacking: y=19 (s0)=0, y=29 (s1)!=0, y=30 (s2)!=0, y=40 (s3)=0
        passed = (s0 == 0) and (s1 ~= 0) and (s2 ~= 0) and (s3 == 0)
        detail = string.format("y19=%04X (exp 0), y29=%04X (exp !=0), y30=%04X (exp !=0), y40=%04X (exp 0)",
            s0, s1, s2, s3)

    elseif index == 3 then
        -- Case 3: Horizontal Adjacency: x=9 (s0)=0, x=24 (s1)!=0, x=25 (s2)!=0, x=40 (s3)=0
        passed = (s0 == 0) and (s1 ~= 0) and (s2 ~= 0) and (s3 == 0)
        detail = string.format("x9=%04X (exp 0), x24=%04X (exp !=0), x25=%04X (exp !=0), x40=%04X (exp 0)",
            s0, s1, s2, s3)

    elseif index == 4 then
        -- Case 4: Clipping: y=0 (s0)!=0, y=5 (s1)!=0, y=6 (s2)=0, x=0 (s3)!=0
        passed = (s0 ~= 0) and (s1 ~= 0) and (s2 == 0) and (s3 ~= 0)
        detail = string.format("y0=%04X (exp !=0), y5=%04X (exp !=0), y6=%04X (exp 0), left_clip_x0=%04X (exp !=0)",
            s0, s1, s2, s3)

    elseif index == 5 then
        -- Case 5: Frame Half: Pass 0 x=127 (s0)!=0, Pass 1 x'=0 (s1)!=0
        passed = (s0 ~= 0) and (s1 ~= 0)
        detail = string.format("pass0_x127=%04X (exp !=0), pass1_x0=%04X (exp !=0)",
            s0, s1)

    elseif index == 6 then
        -- Case 6: Transparency: s0 = initial bg, s1 = texel $00 (should equal s0), s2 = texel $01 (should be 1)
        passed = (s1 == s0) and (s2 == 1) and (s0 ~= 0)
        detail = string.format("initial_bg=%04X, after_color00=%04X (exp %04X), after_color01=%04X (exp 1)",
            s0, s1, s0, s2)
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
            print(string.format("TEST PASSED: All %d cached_trap tests passed.", TOTAL_CASES))
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
