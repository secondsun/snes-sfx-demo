test_setup   = 0x0003
test_stop    = 0x00E7
YAW_INPUT    = 0x1042
MAP_ORIGIN   = 0x1044
BASIS_OUT    = 0x1048
LATTICE_OUT  = 0x1054
ANCHOR_0_0_0 = 0x10C4
ANCHOR_1_0_0 = 0x10C8
ANCHOR_0_1_0 = 0x10CC
ANCHOR_0_0_1 = 0x10D0
ANCHOR_TEST  = 0x10D4

local ORIGIN_X = 128
local ORIGIN_Y = 80

local function to_signed16(val)
    val = val & 0xFFFF
    if val >= 0x8000 then
        return val - 0x10000
    end
    return val
end

-- Arithmetic right shift (floor division) for signed 16-bit integer
local function asr(val, shift)
    return math.floor(val / (2 ^ shift))
end

local current_yaw = 1
local total_yaws = 120
local fail_count = 0

function onTestSetup(address, value)
    print(string.format("Starting test_lattice suite (sweeping all %d orbital yaw angles)...", total_yaws))
    -- Write map origin (128, 80)
    emu.writeWord(MAP_ORIGIN + 0, ORIGIN_X, emu.memType.gsuWorkRam)
    emu.writeWord(MAP_ORIGIN + 2, ORIGIN_Y, emu.memType.gsuWorkRam)

    -- Write initial yaw = 1
    current_yaw = 1
    emu.writeWord(YAW_INPUT, current_yaw, emu.memType.gsuWorkRam)
end

function onTestStop(address, value)
    -- 1. Read Basis Vectors (Sx, Sz, Sy)
    local sx_x = to_signed16(emu.readWord(BASIS_OUT + 0, emu.memType.gsuWorkRam, false))
    local sx_y = to_signed16(emu.readWord(BASIS_OUT + 2, emu.memType.gsuWorkRam, false))
    local sz_x = to_signed16(emu.readWord(BASIS_OUT + 4, emu.memType.gsuWorkRam, false))
    local sz_y = to_signed16(emu.readWord(BASIS_OUT + 6, emu.memType.gsuWorkRam, false))
    local sy_x = to_signed16(emu.readWord(BASIS_OUT + 8, emu.memType.gsuWorkRam, false))
    local sy_y = to_signed16(emu.readWord(BASIS_OUT + 10, emu.memType.gsuWorkRam, false))

    -- 2. Read 28 Lattice Points
    local P = {}
    for k = 0, 27 do
        local addr = LATTICE_OUT + k * 4
        local px = to_signed16(emu.readWord(addr + 0, emu.memType.gsuWorkRam, false))
        local py = to_signed16(emu.readWord(addr + 2, emu.memType.gsuWorkRam, false))
        P[k] = { x = px, y = py }
    end

    -- 3. Read Anchors
    local a000 = {
        x = to_signed16(emu.readWord(ANCHOR_0_0_0 + 0, emu.memType.gsuWorkRam, false)),
        y = to_signed16(emu.readWord(ANCHOR_0_0_0 + 2, emu.memType.gsuWorkRam, false))
    }
    local a100 = {
        x = to_signed16(emu.readWord(ANCHOR_1_0_0 + 0, emu.memType.gsuWorkRam, false)),
        y = to_signed16(emu.readWord(ANCHOR_1_0_0 + 2, emu.memType.gsuWorkRam, false))
    }
    local a010 = {
        x = to_signed16(emu.readWord(ANCHOR_0_1_0 + 0, emu.memType.gsuWorkRam, false)),
        y = to_signed16(emu.readWord(ANCHOR_0_1_0 + 2, emu.memType.gsuWorkRam, false))
    }
    local a001 = {
        x = to_signed16(emu.readWord(ANCHOR_0_0_1 + 0, emu.memType.gsuWorkRam, false)),
        y = to_signed16(emu.readWord(ANCHOR_0_0_1 + 2, emu.memType.gsuWorkRam, false))
    }
    local atest = {
        x = to_signed16(emu.readWord(ANCHOR_TEST + 0, emu.memType.gsuWorkRam, false)),
        y = to_signed16(emu.readWord(ANCHOR_TEST + 2, emu.memType.gsuWorkRam, false))
    }

    local yaw_ok = true

    -- Check Basis Sy invariant: (0, -14)
    if sy_x ~= 0 or sy_y ~= -14 then
        print(string.format("  [Yaw %d] FAILED Sy vector: got (%d, %d), expected (0, -14)", current_yaw, sy_x, sy_y))
        yaw_ok = false
    end

    -- Check Horizontal Watertight Identity East/West:
    -- Anchor(i+1, j, h) + Corner_west == Anchor(i, j, h) + Corner_east
    -- West corners: C0 (0), C3 (3). East corners: C1 (1), C2 (2).
    local ew0_x = a100.x + P[0].x
    local ew0_y = a100.y + P[0].y
    local ew1_x = a000.x + P[1].x
    local ew1_y = a000.y + P[1].y
    if ew0_x ~= ew1_x or ew0_y ~= ew1_y then
        print(string.format("  [Yaw %d] FAILED East/West Watertight (C0/C1): A(1,0)+C0=(%d,%d) != A(0,0)+C1=(%d,%d)",
            current_yaw, ew0_x, ew0_y, ew1_x, ew1_y))
        yaw_ok = false
    end

    local ew3_x = a100.x + P[3].x
    local ew3_y = a100.y + P[3].y
    local ew2_x = a000.x + P[2].x
    local ew2_y = a000.y + P[2].y
    if ew3_x ~= ew2_x or ew3_y ~= ew2_y then
        print(string.format("  [Yaw %d] FAILED East/West Watertight (C3/C2): A(1,0)+C3=(%d,%d) != A(0,0)+C2=(%d,%d)",
            current_yaw, ew3_x, ew3_y, ew2_x, ew2_y))
        yaw_ok = false
    end

    -- Check Horizontal Watertight Identity North/South:
    -- Anchor(i, j+1, h) + Corner_north == Anchor(i, j, h) + Corner_south
    -- North corners: C0 (0), C1 (1). South corners: C3 (3), C2 (2).
    local ns0_x = a010.x + P[0].x
    local ns0_y = a010.y + P[0].y
    local ns3_x = a000.x + P[3].x
    local ns3_y = a000.y + P[3].y
    if ns0_x ~= ns3_x or ns0_y ~= ns3_y then
        print(string.format("  [Yaw %d] FAILED North/South Watertight (C0/C3): A(0,1)+C0=(%d,%d) != A(0,0)+C3=(%d,%d)",
            current_yaw, ns0_x, ns0_y, ns3_x, ns3_y))
        yaw_ok = false
    end

    local ns1_x = a010.x + P[1].x
    local ns1_y = a010.y + P[1].y
    local ns2_x = a000.x + P[2].x
    local ns2_y = a000.y + P[2].y
    if ns1_x ~= ns2_x or ns1_y ~= ns2_y then
        print(string.format("  [Yaw %d] FAILED North/South Watertight (C1/C2): A(0,1)+C1=(%d,%d) != A(0,0)+C2=(%d,%d)",
            current_yaw, ns1_x, ns1_y, ns2_x, ns2_y))
        yaw_ok = false
    end

    -- Check Vertical Watertight Identity:
    -- Skirt bottom at y=-1h on cell (h=1) matches top corner at y=0 on lower cell (h=0)
    for k = 0, 3 do
        local v_skirt_x = a001.x + P[4 + k].x
        local v_skirt_y = a001.y + P[4 + k].y
        local v_top_x   = a000.x + P[k].x
        local v_top_y   = a000.y + P[k].y
        if v_skirt_x ~= v_top_x or v_skirt_y ~= v_top_y then
            print(string.format("  [Yaw %d] FAILED Vertical Watertight C%d: A(0,0,1)+Skirt%d=(%d,%d) != A(0,0,0)+C%d=(%d,%d)",
                current_yaw, k, k, v_skirt_x, v_skirt_y, k, v_top_x, v_top_y))
            yaw_ok = false
        end
    end

    -- Check Elevated Corners (+1h and +2h):
    for k = 0, 3 do
        if P[8 + k].x ~= P[k].x or P[8 + k].y ~= P[k].y - 14 then
            print(string.format("  [Yaw %d] FAILED Elevated +1h C%d: got (%d, %d), expected (%d, %d)",
                current_yaw, k, P[8 + k].x, P[8 + k].y, P[k].x, P[k].y - 14))
            yaw_ok = false
        end
        if P[12 + k].x ~= P[k].x or P[12 + k].y ~= P[k].y - 28 then
            print(string.format("  [Yaw %d] FAILED Elevated +2h C%d: got (%d, %d), expected (%d, %d)",
                current_yaw, k, P[12 + k].x, P[12 + k].y, P[k].x, P[k].y - 28))
            yaw_ok = false
        end
    end

    -- Check Canonical Edge Midpoints at y=0 (Indices 16..19):
    -- MN = Sx/2
    local exp_mn_x = asr(sx_x, 1)
    local exp_mn_y = asr(sx_y, 1)
    if P[16].x ~= exp_mn_x or P[16].y ~= exp_mn_y then
        print(string.format("  [Yaw %d] FAILED MN: got (%d,%d), expected (%d,%d)", current_yaw, P[16].x, P[16].y, exp_mn_x, exp_mn_y))
        yaw_ok = false
    end

    -- ME = Sx + Sz/2
    local exp_me_x = sx_x + asr(sz_x, 1)
    local exp_me_y = sx_y + asr(sz_y, 1)
    if P[17].x ~= exp_me_x or P[17].y ~= exp_me_y then
        print(string.format("  [Yaw %d] FAILED ME: got (%d,%d), expected (%d,%d)", current_yaw, P[17].x, P[17].y, exp_me_x, exp_me_y))
        yaw_ok = false
    end

    -- MS = Sx/2 + Sz
    local exp_ms_x = asr(sx_x, 1) + sz_x
    local exp_ms_y = asr(sx_y, 1) + sz_y
    if P[18].x ~= exp_ms_x or P[18].y ~= exp_ms_y then
        print(string.format("  [Yaw %d] FAILED MS: got (%d,%d), expected (%d,%d)", current_yaw, P[18].x, P[18].y, exp_ms_x, exp_ms_y))
        yaw_ok = false
    end

    -- MW = Sz/2
    local exp_mw_x = asr(sz_x, 1)
    local exp_mw_y = asr(sz_y, 1)
    if P[19].x ~= exp_mw_x or P[19].y ~= exp_mw_y then
        print(string.format("  [Yaw %d] FAILED MW: got (%d,%d), expected (%d,%d)", current_yaw, P[19].x, P[19].y, exp_mw_x, exp_mw_y))
        yaw_ok = false
    end

    -- Check Inset Pillar Base Ring (Indices 20..23):
    -- P0 = Sx/4 + Sz/4
    local exp_p0_x = asr(sx_x, 2) + asr(sz_x, 2)
    local exp_p0_y = asr(sx_y, 2) + asr(sz_y, 2)
    if P[20].x ~= exp_p0_x or P[20].y ~= exp_p0_y then
        print(string.format("  [Yaw %d] FAILED Pillar P0: got (%d,%d), expected (%d,%d)", current_yaw, P[20].x, P[20].y, exp_p0_x, exp_p0_y))
        yaw_ok = false
    end

    -- P1 = P0 + Sx/2
    local exp_p1_x = exp_p0_x + asr(sx_x, 1)
    local exp_p1_y = exp_p0_y + asr(sx_y, 1)
    if P[21].x ~= exp_p1_x or P[21].y ~= exp_p1_y then
        print(string.format("  [Yaw %d] FAILED Pillar P1: got (%d,%d), expected (%d,%d)", current_yaw, P[21].x, P[21].y, exp_p1_x, exp_p1_y))
        yaw_ok = false
    end

    -- P2 = P1 + Sz/2
    local exp_p2_x = exp_p1_x + asr(sz_x, 1)
    local exp_p2_y = exp_p1_y + asr(sz_y, 1)
    if P[22].x ~= exp_p2_x or P[22].y ~= exp_p2_y then
        print(string.format("  [Yaw %d] FAILED Pillar P2: got (%d,%d), expected (%d,%d)", current_yaw, P[22].x, P[22].y, exp_p2_x, exp_p2_y))
        yaw_ok = false
    end

    -- P3 = P0 + Sz/2
    local exp_p3_x = exp_p0_x + asr(sz_x, 1)
    local exp_p3_y = exp_p0_y + asr(sz_y, 1)
    if P[23].x ~= exp_p3_x or P[23].y ~= exp_p3_y then
        print(string.format("  [Yaw %d] FAILED Pillar P3: got (%d,%d), expected (%d,%d)", current_yaw, P[23].x, P[23].y, exp_p3_x, exp_p3_y))
        yaw_ok = false
    end

    -- Check Inset Pillar Top Ring at +2h (Indices 24..27):
    for k = 0, 3 do
        if P[24 + k].x ~= P[20 + k].x or P[24 + k].y ~= P[20 + k].y - 28 then
            print(string.format("  [Yaw %d] FAILED Pillar Top P%d: got (%d,%d), expected (%d,%d)",
                current_yaw, k, P[24 + k].x, P[24 + k].y, P[20 + k].x, P[20 + k].y - 28))
            yaw_ok = false
        end
    end

    -- Check General Anchor Resolver Anchor(3, 5, 2):
    local exp_test_x = ORIGIN_X + 3 * sx_x + 5 * sz_x + 2 * sy_x
    local exp_test_y = ORIGIN_Y + 3 * sx_y + 5 * sz_y + 2 * sy_y
    if atest.x ~= exp_test_x or atest.y ~= exp_test_y then
        print(string.format("  [Yaw %d] FAILED Anchor(3,5,2): got (%d,%d), expected (%d,%d)",
            current_yaw, atest.x, atest.y, exp_test_x, exp_test_y))
        yaw_ok = false
    end

    if not yaw_ok then
        fail_count = fail_count + 1
    end

    -- Log periodic progress
    if current_yaw == 1 or current_yaw == 30 or current_yaw == 60 or current_yaw == 90 or current_yaw == 120 then
        local quad_label = "0 deg"
        if current_yaw == 30 then quad_label = "90 deg"
        elseif current_yaw == 60 then quad_label = "180 deg"
        elseif current_yaw == 90 then quad_label = "270 deg"
        elseif current_yaw == 120 then quad_label = "360 deg"
        end
        print(string.format("  [Yaw %d/%d (%s)] Sx=(%d,%d) Sz=(%d,%d) Anchor(0,0)=(%d,%d) Anchor(3,5,2)=(%d,%d) %s",
            current_yaw, total_yaws, quad_label, sx_x, sx_y, sz_x, sz_y, a000.x, a000.y, atest.x, atest.y,
            yaw_ok and "PASS" or "FAIL"))
    end

    -- Check termination or advance to next yaw angle
    if current_yaw >= total_yaws then
        if fail_count == 0 then
            print(string.format("TEST PASSED: All %d orbital yaw angles passed watertight & canonical lattice checks.", total_yaws))
            emu.stop(0)
        else
            print(string.format("TEST FAILED: %d/%d yaw angles failed checks.", fail_count, total_yaws))
            emu.stop(1)
        end
        return
    end

    current_yaw = current_yaw + 1
    emu.writeWord(YAW_INPUT, current_yaw, emu.memType.gsuWorkRam)
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
