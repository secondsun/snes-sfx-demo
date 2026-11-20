-- test.lua - Mesen CE headless test script for `sprite_mask` (Issues #34 & #35)
io.stdout:setvbuf("no")

test_setup    = 0x3C28
test_start    = 0x3C2A
test_stop     = 0x413C
TEST_CASE_IDX = 0x8A28
TEST_RESULT   = 0x8A2A

local index = 1
local fail_count = 0
local TOTAL_CASES = 4

local case_names = {
    [1] = "Exact 1-Bit MSB-First Sprite Mask Punching & Surrounding Pixels Untouched",
    [2] = "Horizontal Flip (GSU_ENTITY_FLAG_HFLIP) Mask Mirroring",
    [3] = "Pass 0 / Pass 1 Frame-Half Clipping (192px) & Top Vertical Clipping",
    [4] = "Full gsu_iso_render: O(1) LUT, @step_4_unit_hook (sx,sy) Writeback, Cutout & Cell Highlight (#35)"
}

function runCase(idx)
    emu.writeWord(TEST_CASE_IDX, idx, emu.memType.gsuWorkRam)
end

function onTestSetup(address, value)
    print("==================================================================")
    print(" Starting sprite_mask Unit Test Suite (Issues #34 & #35)")
    print("==================================================================")
    runCase(index)
end

function onTestStop(address, value)
    local r = {}
    for i = 0, 9 do
        r[i] = emu.readWord(TEST_RESULT + i * 2, emu.memType.gsuWorkRam, false)
    end

    local passed = false
    local detail = ""

    if index == 1 then
        passed = (r[0] == 7) and (r[1] == 0) and (r[2] == 7) and (r[3] == 0) and (r[4] == 7)
             and (r[5] == 0) and (r[6] == 7) and (r[7] == 7) and (r[8] == 0) and (r[9] == 7)
        detail = string.format("px=[%d,%d,%d,%d,%d,%d,%d,%d,%d,%d] (exp 7,0,7,0,7,0,7,7,0,7)",
            r[0], r[1], r[2], r[3], r[4], r[5], r[6], r[7], r[8], r[9])
    elseif index == 2 then
        passed = (r[0] == 5) and (r[1] == 5) and (r[2] == 0) and (r[3] == 0)
             and (r[4] == 0) and (r[5] == 5)
        detail = string.format("hflip=[%d,%d,%d,%d,%d,%d] (exp 5,5,0,0,0,5)",
            r[0], r[1], r[2], r[3], r[4], r[5])
    elseif index == 3 then
        passed = (r[0] == 9) and (r[1] == 0) and (r[2] == 0) and (r[3] == 6)
             and (r[4] == 0) and (r[5] == 9) and (r[6] == 0) and (r[7] == 9)
             and (r[8] == 9) and (r[9] == 0)
        detail = string.format("p0=[%d,%d,%d,sent=%d] p1=[%d,%d,%d,%d] top=[%d,%d] (exp 9,0,0,6,0,9,0,9,9,0)",
            r[0], r[1], r[2], r[3], r[4], r[5], r[6], r[7], r[8], r[9])
    elseif index == 4 then
        -- r[0]=lut[0]($FF), r[1]=lut[5](0), r[2]=sx, r[3]=sy, r[4]=visible(1),
        -- r[5]=cutout_px(0), r[6]=hl_even(12), r[7]=hl_odd(3)
        local sx = r[2]
        if sx >= 32768 then sx = sx - 65536 end
        local sy = r[3]
        if sy >= 32768 then sy = sy - 65536 end
        passed = (r[0] == 0xFF) and (r[1] == 0) and (r[4] == 1)
             and (sx > 0 and sx < 192) and (sy > 0 and sy < 160)
             and (r[5] == 0) and (r[6] == 12) and (r[7] == 3)
        detail = string.format("lut0=%02X(FF) lut5=%d(0) out=(%d,%d,vis=%d) cutout=%d(0) hl=[%d(12),%d(3)]",
            r[0], r[1], sx, sy, r[4], r[5], r[6], r[7])
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
            print(string.format("TEST PASSED: All %d sprite_mask tests passed.", TOTAL_CASES))
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
