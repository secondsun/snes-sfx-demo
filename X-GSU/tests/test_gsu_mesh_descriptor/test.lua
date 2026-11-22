-- test.lua - Mesen test script for gsu_mesh Descriptor, Sprite Mask & Highlight Suite
io.stdout:setvbuf("no")
test_setup    = 0x4F99
test_stop     = 0x52D6
TEST_CASE_IDX = 0xB816
TEST_RESULT   = 0xB818

local index = 1
local fail_count = 0
local TOTAL_CASES = 4

local case_names = {
    [1] = "gsu_mesh_import_bank71 Companion sfx_mesh_grid & Default HL Colors",
    [2] = "192x160 Descriptor Seam-Crossing Sprite Mask Cutout & Right-Edge Clip",
    [3] = "256-Bucket OT 3D Polygon Occlusion Over Under-BG1 Sprite Mask Cutout",
    [4] = "50% Checkerboard Tactical Cell Highlights Layered Below Entity Cutout"
}

function runCase(idx)
    emu.writeWord(TEST_CASE_IDX, idx, emu.memType.gsuWorkRam)
end

function onTestSetup(address, value)
    print("==================================================================")
    print(" Starting test_gsu_mesh_descriptor Unit Test Suite")
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
    local r6 = emu.readWord(TEST_RESULT + 12, emu.memType.gsuWorkRam, false)
    local r7 = emu.readWord(TEST_RESULT + 14, emu.memType.gsuWorkRam, false)

    local passed = false
    local detail = ""

    if index == 1 then
        passed = (r0 == 0) and (r1 == 1) and (r2 == 12) and (r3 == 13) and (r4 == 14)
        detail = string.format("err=%d, has_grid=%d, hl=(%d,%d,%d)", r0, r1, r2, r3, r4)
    elseif index == 2 then
        passed = (r0 == 120) and (r1 == 80) and (r2 == 1)
             and (r3 == 0) and (r4 == 2) and (r5 == 0) and (r6 == 5) and (r7 == 0)
        detail = string.format("out=(%d,%d,vis=%d), p0_cut=%d, p0_flr=%d, p1_cut=%d, in192=%d, past192=%d",
            r0, r1, r2, r3, r4, r5, r6, r7)
    elseif index == 3 then
        passed = (r0 == 88) and (r1 == 64) and (r2 == 1) and (r3 == 3)
        detail = string.format("out=(%d,%d,vis=%d), occluded_px=%d", r0, r1, r2, r3)
    elseif index == 4 then
        passed = (r0 == 13) and (r1 == 2) and (r2 == 12) and (r3 == 0)
        detail = string.format("atk_on=%d, atk_off=%d, mov_on=%d, ent_over_mov=%d", r0, r1, r2, r3)
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
            print(string.format("TEST PASSED: All %d test_gsu_mesh_descriptor tests passed.", TOTAL_CASES))
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
