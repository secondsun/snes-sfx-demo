-- test.lua - Mesen test script for gsu_mesh Hybrid 3D Engine
io.stdout:setvbuf("no")
test_setup    = 0x41F1
test_stop     = 0x4431
TEST_CASE_IDX = 0xA160
TEST_RESULT   = 0xA162

local index = 1
local fail_count = 0
local TOTAL_CASES = 4

local case_names = {
    [1] = "gsu_mesh_import_bank71 Validation, Camera Setup & Stride Shift",
    [2] = "Seam-Crossing Flat Quad Across X=127..128 (Pass 0 + Pass 1)",
    [3] = "256-Bucket OT Depth Occlusion & CW Backface Culling",
    [4] = "Hybrid Flat Backplate + Bank-$71 Hero Cutout & RAMBR==0"
}

function runCase(idx)
    emu.writeWord(TEST_CASE_IDX, idx, emu.memType.gsuWorkRam)
end

function onTestSetup(address, value)
    print("==================================================================")
    print(" Starting test_gsu_mesh Unit Test Suite")
    print("==================================================================")
    runCase(index)
end

function onTestStop(address, value)
    local r0 = emu.readWord(TEST_RESULT + 0, emu.memType.gsuWorkRam, false)
    local r1 = emu.readWord(TEST_RESULT + 2, emu.memType.gsuWorkRam, false)
    local r2 = emu.readWord(TEST_RESULT + 4, emu.memType.gsuWorkRam, false)
    local r3 = emu.readWord(TEST_RESULT + 6, emu.memType.gsuWorkRam, false)
    local r4 = emu.readWord(TEST_RESULT + 8, emu.memType.gsuWorkRam, false)
    local r5 = emu.readWord(TEST_RESULT + 10, emu.memType.gsuWorkRam, false)

    local passed = false
    local detail = ""

    if index == 1 then
        passed = (r0 == 0) and (r1 == 0x4D53) and (r2 == 19)
             and (r3 == 5) and (r4 == 80) and (r5 == 8)
        detail = string.format("err=%d, magic=%04X, verts=%d, faces=%d, cy=%d, shift=%d",
            r0, r1, r2, r3, r4, r5)
    elseif index == 2 then
        passed = (r0 == 2) and (r1 == 2) and (r2 == 2) and (r3 == 2)
        detail = string.format("p0(120,86)=%d, p0(127,81)=%d, p1(128,81)=%d, p1(136,86)=%d",
            r0, r1, r2, r3)
    elseif index == 3 then
        passed = (r0 == 3) and (r1 == 0) and (r2 == 0)
        detail = string.format("occl(128,86)=%d, p0_c4=%d, p1_c4=%d",
            r0, r1, r2)
    elseif index == 4 then
        passed = (r0 == 7) and (r1 == 6) and (r2 == 5) and (r3 == 6) and (r4 == 0xBEEF)
        detail = string.format("cutout=%d, bl=%d, tr=%d, br=%d, rambr0=%04X",
            r0, r1, r2, r3, r4)
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
            print(string.format("TEST PASSED: All %d test_gsu_mesh tests passed.", TOTAL_CASES))
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
