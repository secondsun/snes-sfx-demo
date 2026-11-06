-- test.lua - Mesen test script for texture repeat & masking verification
test_setup    = 0x0007
test_stop     = 0x0358
TEST_CASE_IDX = 0x0FB6
TEST_RESULT   = 0x0FB8

local index = 1
local fail_count = 0
local TOTAL_CASES = 4

local case_names = {
    [1] = "Foliage (16x32) full 16-pixel width span (x=0..15)",
    [2] = "Stone (32x32) full width span (x=0..15)",
    [3] = "Foliage u_offset=8 span (x=0..7)",
    [4] = "Stone v_offset=4 span (x=0..7)"
}

local EXPECTED = {
    -- Case 1: Row 7 of Foliage (16 texels)
    [1] = { 8, 8, 8, 13, 13, 13, 13, 13, 13, 8, 13, 13, 13, 8, 15, 0 },
    -- Case 2: Row 4 of Stone (first 16 texels)
    [2] = { 1, 4, 3, 3, 4, 3, 3, 1, 3, 3, 1, 3, 3, 3, 3, 1 },
    -- Case 3: Foliage Row 7 with u_offset=8 (texels 8..15)
    [3] = { 13, 8, 13, 13, 13, 8, 15, 0 },
    -- Case 4: Stone Row 4 with v_offset=4 (texels 0..7)
    [4] = { 1, 4, 3, 3, 4, 3, 3, 1 }
}

function runCase(idx)
    emu.writeWord(TEST_CASE_IDX, idx, emu.memType.gsuWorkRam)
end

function onTestSetup(address, value)
    print("==================================================================")
    print(" Starting test_texture_repeat Unit Test Suite")
    print("==================================================================")
    runCase(index)
end

function onTestStop(address, value)
    local exp = EXPECTED[index]
    local count = #exp
    local actual = {}
    for i = 1, count do
        actual[i] = emu.readWord(TEST_RESULT + (i - 1) * 2, emu.memType.gsuWorkRam, false)
    end

    local passed = true
    local act_str = ""
    local exp_str = ""
    for i = 1, count do
        if actual[i] ~= exp[i] then
            passed = false
        end
        act_str = act_str .. string.format("%d ", actual[i])
        exp_str = exp_str .. string.format("%d ", exp[i])
    end

    -- Check if it shows 8-pixel repeating
    local repeats_8 = false
    if index == 1 or index == 2 then
        repeats_8 = true
        for i = 1, 8 do
            if actual[i + 8] ~= actual[i] then
                repeats_8 = false
                break
            end
        end
    end

    if passed then
        print(string.format("  [%d/%d] PASSED: %s", index, TOTAL_CASES, case_names[index]))
        print(string.format("         Actual:   %s", act_str))
    else
        print(string.format("  [%d/%d] FAILED: %s", index, TOTAL_CASES, case_names[index]))
        print(string.format("         Actual:   %s", act_str))
        print(string.format("         Expected: %s", exp_str))
        if repeats_8 then
            print(string.format("         --> BUG CONFIRMED: pixels 8..15 exactly repeat pixels 0..7!"))
        end
        fail_count = fail_count + 1
    end

    if index >= TOTAL_CASES then
        print("==================================================================")
        if fail_count == 0 then
            print(string.format("TEST PASSED: All %d texture repeat tests passed.", TOTAL_CASES))
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
