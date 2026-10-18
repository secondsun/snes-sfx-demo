test_setup = 0x0003
test_stop  = 0x0042
YAW_INPUT  = 0x053A
ISO_CAM    = 0x053C
CUBE_V3    = 0x0546
CUBE_V2    = 0x0576

local CENTER_X = 128
local CENTER_Y = 80
local COS_30   = 0x376D

-- 8 unique cube vertices in Q8.8 (R = 32.0 = 0x2000, -R = -32.0 = 0xE000)
local cube_vertices = {
    { -0x2000, -0x2000, -0x2000 }, -- v0: (-32, -32, -32)
    {  0x2000, -0x2000, -0x2000 }, -- v1: ( 32, -32, -32)
    {  0x2000,  0x2000, -0x2000 }, -- v2: ( 32,  32, -32)
    { -0x2000,  0x2000, -0x2000 }, -- v3: (-32,  32, -32)
    { -0x2000, -0x2000,  0x2000 }, -- v4: (-32, -32,  32)
    {  0x2000, -0x2000,  0x2000 }, -- v5: ( 32, -32,  32)
    {  0x2000,  0x2000,  0x2000 }, -- v6: ( 32,  32,  32)
    { -0x2000,  0x2000,  0x2000 }, -- v7: (-32,  32,  32)
}

-- 6 yaw test cases: 0 deg (120), 45 deg (15), 90 deg (30), 135 deg (45), 180 deg (60), 270 deg (90)
local cases = {
    { yaw = 120, sin = 0x0000, cos = 0x4000, label = "0 deg"   },
    { yaw = 15,  sin = 0x2D41, cos = 0x2D41, label = "45 deg"  },
    { yaw = 30,  sin = 0x4000, cos = 0x0000, label = "90 deg"  },
    { yaw = 45,  sin = 0x2D41, cos = 0xD2BF, label = "135 deg" },
    { yaw = 60,  sin = 0x0000, cos = 0xC000, label = "180 deg" },
    { yaw = 90,  sin = 0xC000, cos = 0x0000, label = "270 deg" },
}

local function to_signed16(val)
    val = val & 0xFFFF
    if val >= 0x8000 then
        return val - 0x10000
    end
    return val
end

local function fmult(a, b)
    local sa = to_signed16(a)
    local sb = to_signed16(b)
    return to_signed16(math.floor((sa * sb) / 65536) & 0xFFFF)
end

local function q10_6_to_int(val)
    local q8_8 = to_signed16(((val * 4) + 0x0080) & 0xFFFF)
    return math.floor(q8_8 / 256)
end

local function expected_project(v, sin_yaw, cos_yaw)
    local vx, vy, vz = v[1], v[2], v[3]
    local x_acc = to_signed16((fmult(vx, cos_yaw) - fmult(vz, sin_yaw)) & 0xFFFF)
    local y_rot = to_signed16((fmult(vx, sin_yaw) + fmult(vz, cos_yaw)) & 0xFFFF)
    local y_acc = to_signed16((math.floor(y_rot / 2) - fmult(vy, COS_30)) & 0xFFFF)

    local sx = CENTER_X + q10_6_to_int(x_acc)
    local sy = CENTER_Y + q10_6_to_int(y_acc)
    return sx, sy
end

local index = 1
local fail_count = 0

function onTestSetup(address, value)
    print("Starting iso_camera test suite (6 yaw angles x 8 vertices)...")
    -- Initialize center_x (+6) and center_y (+8)
    emu.writeWord(ISO_CAM + 6, CENTER_X, emu.memType.gsuWorkRam)
    emu.writeWord(ISO_CAM + 8, CENTER_Y, emu.memType.gsuWorkRam)

    -- Write 8 cube vertices to CUBE_V3
    for i, v in ipairs(cube_vertices) do
        local base = CUBE_V3 + (i - 1) * 6
        emu.writeWord(base + 0, v[1] & 0xFFFF, emu.memType.gsuWorkRam)
        emu.writeWord(base + 2, v[2] & 0xFFFF, emu.memType.gsuWorkRam)
        emu.writeWord(base + 4, v[3] & 0xFFFF, emu.memType.gsuWorkRam)
    end

    -- Write first yaw input
    emu.writeWord(YAW_INPUT, cases[1].yaw, emu.memType.gsuWorkRam)
end

function onTestStop(address, value)
    local c = cases[index]
    local got_yaw = emu.readWord(ISO_CAM + 0, emu.memType.gsuWorkRam, false)
    local got_sin = emu.readWord(ISO_CAM + 2, emu.memType.gsuWorkRam, false)
    local got_cos = emu.readWord(ISO_CAM + 4, emu.memType.gsuWorkRam, false)

    local case_ok = true
    if got_yaw ~= c.yaw or got_sin ~= c.sin or got_cos ~= c.cos then
        print(string.format("  [Case %d: %s] FAILED trig cache: got yaw=%d sin=0x%04X cos=0x%04X, exp yaw=%d sin=0x%04X cos=0x%04X",
            index, c.label, got_yaw, got_sin, got_cos, c.yaw, c.sin, c.cos))
        case_ok = false
    end

    for i, v in ipairs(cube_vertices) do
        local base = CUBE_V2 + (i - 1) * 4
        local gx = to_signed16(emu.readWord(base + 0, emu.memType.gsuWorkRam, false))
        local gy = to_signed16(emu.readWord(base + 2, emu.memType.gsuWorkRam, false))
        local ex, ey = expected_project(v, c.sin, c.cos)
        if gx ~= ex or gy ~= ey then
            print(string.format("  [Case %d: %s, v%d] FAILED: got (%d, %d), expected (%d, %d)",
                index, c.label, i - 1, gx, gy, ex, ey))
            case_ok = false
        end
    end

    if case_ok then
        local v0x = to_signed16(emu.readWord(CUBE_V2 + 0, emu.memType.gsuWorkRam, false))
        local v0y = to_signed16(emu.readWord(CUBE_V2 + 2, emu.memType.gsuWorkRam, false))
        print(string.format("  [%d/%d] PASSED (%s, yaw=%d): sin=0x%04X cos=0x%04X, v0=(%d, %d)",
            index, #cases, c.label, c.yaw, got_sin, got_cos, v0x, v0y))
    else
        fail_count = fail_count + 1
    end

    if index >= #cases then
        if fail_count == 0 then
            print("TEST PASSED: All iso_camera projection tests passed.")
            emu.stop(0)
        else
            print(string.format("TEST FAILED: %d/%d cases failed.", fail_count, #cases))
            emu.stop(1)
        end
        return
    end

    index = index + 1
    emu.writeWord(YAW_INPUT, cases[index].yaw, emu.memType.gsuWorkRam)
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
