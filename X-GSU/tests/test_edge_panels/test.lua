-- test.lua - Mesen test script for Compass Edge Panels & Intra-Cell Pipeline (Ticket 7)
io.stdout:setvbuf("no")
test_setup = 0x3030
test_stop  = 0x339C
TEST_CASE_IDX = 0x3F16
TEST_RESULT   = 0x3F18

local index = 1
local fail_count = 0
local TOTAL_CASES = 4

local case_names = {
    "Edge Panel (N/E/S/W 1h/2h) Template Compilation & arch_buf Allocation",
    "Yaw-Quadrant Compass Partitioning (Back vs Front across 4 Quadrants)",
    "5-Step Intra-Cell Painter's Pipeline & Cutout Transparency",
    "Tall 2H Facade Panel (PANEL_TALL_2H) Elevation & Rendering"
}

local function runCase(case_idx)
    emu.writeWord(TEST_CASE_IDX, case_idx, emu.memType.gsuWorkRam)
    for i = 0, 15 do
        emu.writeWord(TEST_RESULT + (i * 2), 0, emu.memType.gsuWorkRam)
    end
end

local function onTestSetup()
    runCase(index)
end

local function onTestStop()
    local s0 = emu.readWord(TEST_RESULT + 0, emu.memType.gsuWorkRam)
    local s1 = emu.readWord(TEST_RESULT + 2, emu.memType.gsuWorkRam)
    local s2 = emu.readWord(TEST_RESULT + 4, emu.memType.gsuWorkRam)
    local s3 = emu.readWord(TEST_RESULT + 6, emu.memType.gsuWorkRam)

    local passed = false
    local detail = ""

    if index == 1 then
        -- Case 1: Template Compilation
        -- s0: non_zero_templates (exp 8)
        -- s1: total_traps (exp 32)
        -- s2: template 0 trap_count (exp 4)
        -- s3: template 1 trap_count (exp 4)
        passed = (s0 == 8) and (s1 == 32) and (s2 == 4) and (s3 == 4)
        detail = string.format("templates=%d (exp 8), total_traps=%d (exp 32), N_1h=%d (exp 4), N_2h=%d (exp 4)",
            s0, s1, s2, s3)

    elseif index == 2 then
        -- Case 2: Yaw-Quadrant Partitioning
        -- s0: Q0 back mask (exp 0x0009: PANEL_N $01 | PANEL_W $08)
        -- s1: Q1 back mask (exp 0x000C: PANEL_S $04 | PANEL_W $08)
        -- s2: Q2 back mask (exp 0x0006: PANEL_S $04 | PANEL_E $02)
        -- s3: Q3 back mask (exp 0x0003: PANEL_N $01 | PANEL_E $02)
        passed = (s0 == 0x0009) and (s1 == 0x000C) and (s2 == 0x0006) and (s3 == 0x0003)
        detail = string.format("Q0_back=%04X (exp 0009), Q1_back=%04X (exp 000C), Q2_back=%04X (exp 0006), Q3_back=%04X (exp 0003)",
            s0, s1, s2, s3)

    elseif index == 3 then
        -- Case 3: 5-Step Intra-Cell Pipeline & Cutout Transparency
        -- s0: floor_pixel (exp != 0)
        -- s1: parapet_wall_pixel (exp != 0)
        -- s2: embrasure_cutout_pixel (exp != 0)
        -- s3: merlon_pixel (exp != 0)
        passed = (s0 ~= 0) and (s1 ~= 0) and (s2 ~= 0) and (s3 ~= 0)
        detail = string.format("floor=%04X, parapet_wall=%04X, embrasure=%04X, merlon=%04X",
            s0, s1, s2, s3)

    elseif index == 4 then
        -- Case 4: Tall 2H Facade
        -- s0: facade_high (exp != 0)
        -- s1: facade_low (exp != 0)
        passed = (s0 ~= 0) and (s1 ~= 0)
        detail = string.format("facade_high=%04X, facade_low=%04X", s0, s1)
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
            print(string.format("TEST PASSED: All %d test_edge_panels tests passed.", TOTAL_CASES))
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



