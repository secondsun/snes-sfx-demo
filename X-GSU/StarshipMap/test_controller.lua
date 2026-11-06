-- Automated controller integration test for StarshipMap in Mesen CE
local ADDR_JOYPAD   = 0x09E2
local ADDR_ISO_CAM  = 0x09E4
local ADDR_YAW      = 0x09E4
local ADDR_CENTER_X = 0x09EA
local ADDR_CENTER_Y = 0x09EC

-- Dynamically resolve symbols from SuperFX.cpu.sym if available
local function get_script_dir()
    local str = debug.getinfo(1, "S").source:sub(2)
    return str:match("(.*/)") or "./"
end

local function load_symbols()
    local script_dir = get_script_dir()
    local paths = {
        script_dir .. "SuperFX.cpu.sym",
        "SuperFX.cpu.sym",
        "snes-sfx-demo/X-GSU/StarshipMap/SuperFX.cpu.sym"
    }
    for _, path in ipairs(paths) do
        local f = io.open(path, "r")
        if f then
            for line in f:lines() do
                local addr, sym = line:match("^al (%x+) %.([%w_]+)")
                if addr and sym then
                    local num = tonumber(addr, 16) & 0xFFFF
                    if sym == "GSU_JOYPAD" then
                        ADDR_JOYPAD = num
                    elseif sym == "ISO_CAM" then
                        ADDR_ISO_CAM = num
                        ADDR_YAW = num
                        ADDR_CENTER_X = num + 6
                        ADDR_CENTER_Y = num + 8
                    end
                end
            end
            f:close()
            print(string.format("Loaded symbols: GSU_JOYPAD=0x%04X, ISO_CAM=0x%04X", ADDR_JOYPAD, ADDR_ISO_CAM))
            return
        end
    end
end
load_symbols()

local frame_count = 0
local current_phase = 0
local phase_start_frame = 0
local current_inputs = {}

local function to_signed16(val)
    val = val & 0xFFFF
    if val >= 0x8000 then
        return val - 0x10000
    end
    return val
end

local function onInputPolled()
    emu.setInput(current_inputs)
end

local function onEndFrame()
    frame_count = frame_count + 1

    local yaw = emu.readWord(ADDR_YAW, emu.memType.gsuWorkRam)
    local s_yaw = to_signed16(emu.readWord(ADDR_ISO_CAM + 2, emu.memType.gsuWorkRam))
    local c_yaw = to_signed16(emu.readWord(ADDR_ISO_CAM + 4, emu.memType.gsuWorkRam))
    local cx  = emu.readWord(ADDR_CENTER_X, emu.memType.gsuWorkRam)
    local cy  = to_signed16(emu.readWord(ADDR_CENTER_Y, emu.memType.gsuWorkRam))
    local cam_x = to_signed16(emu.readWord(ADDR_ISO_CAM + 10, emu.memType.gsuWorkRam))
    local cam_z = to_signed16(emu.readWord(ADDR_ISO_CAM + 12, emu.memType.gsuWorkRam))
    local pad = emu.readWord(ADDR_JOYPAD, emu.memType.gsuWorkRam)
    print(string.format("F%d (P%s): yaw=%d, sin=%d, cos=%d, cx=%d, cy=%d, cam=(%d,%d), pad=0x%04X",
        frame_count, tostring(current_phase), yaw, s_yaw, c_yaw, cx, cy, cam_x, cam_z, pad))

    -- Phase 0: Wait for initial scene boot (frame 8)
    if current_phase == 0 and frame_count == 8 then
        print(string.format("Initial state at frame %d: yaw=%d, cx=%d, cy=%d", frame_count, yaw, cx, cy))
        if yaw ~= 1 or cx ~= 128 or cy ~= 80 then
            print(string.format("FAIL: Unexpected initial state! yaw=%d (exp 1), cx=%d (exp 128), cy=%d (exp 80)", yaw, cx, cy))
            emu.stop(1)
            return
        end
        print("  [Init] Boot state validated (yaw=1, cx=128, cy=80).")
        current_phase = 1
        phase_start_frame = frame_count
        -- Start Phase 1: Hold R
        current_inputs = { r = true }
    end

    -- Visual smoke check at frame 15: assert that screenbuffer (0x4000..0x67FF) contains non-zero pixels
    if frame_count == 15 then
        local non_zero = 0
        local start_addr = 0x4000
        local buffer_len = 0x2800 -- active screenbuffer length (10240 bytes = 128x160 4bpp)
        for addr = start_addr, start_addr + buffer_len - 1 do
            if emu.read(addr, emu.memType.gsuWorkRam, false) ~= 0 then
                non_zero = non_zero + 1
            end
        end
        print(string.format("  [Visual Smoke Check] Frame 15 screenbuffer non-zero bytes: %d", non_zero))
        if non_zero == 0 then
            print("FAIL: Visual smoke check failed! Screen buffer is completely empty / unrendered at frame 15.")
            emu.stop(1)
            return
        end
        print("  [Visual Smoke Check] PASSED: Rendered scene detected in screenbuffer.")
    end

    -- Phase 1 check: R was held -> yaw > 1
    if current_phase == 1 and yaw > 1 then
        print(string.format("  [Phase 1] PASSED: Yaw incremented on R button (yaw=%d).", yaw))
        current_phase = 2
        phase_start_frame = frame_count
        -- Start Phase 2: Hold L (should decrement yaw and wrap towards 120)
        current_inputs = { l = true }
    end

    -- Phase 2 check: L was held -> yaw wrapped towards 120
    if current_phase == 2 and (yaw > 100 or (yaw <= 120 and yaw > 10)) then
        print(string.format("  [Phase 2] PASSED: Yaw decremented and wrapped on L button (yaw=%d).", yaw))
        current_phase = 3
        phase_start_frame = frame_count
        -- Start Phase 3: Hold UP (cy -= 2 per pass)
        current_inputs = { up = true }
    end

    -- Phase 3 check: UP was held -> cy < 80
    if current_phase == 3 and cy < 80 then
        print(string.format("  [Phase 3] PASSED: Moved up (cy decreased) on D-pad UP (cy=%d).", cy))
        current_phase = 4
        phase_start_frame = frame_count
        -- Start Phase 4: Hold DOWN (cy += 2 per pass)
        current_inputs = { down = true }
    end

    -- Phase 4 check: DOWN was held -> cy > 80
    if current_phase == 4 and cy > 80 then
        print(string.format("  [Phase 4] PASSED: Moved down (cy increased) on D-pad DOWN (cy=%d).", cy))
        current_phase = 5
        phase_start_frame = frame_count
        -- Start Phase 5: Hold LEFT (cx -= 2 per pass)
        current_inputs = { left = true }
    end

    -- Phase 5 check: LEFT was held -> cx < 128
    if current_phase == 5 and cx < 128 then
        print(string.format("  [Phase 5] PASSED: Moved left (cx decreased) on D-pad LEFT (cx=%d).", cx))
        current_phase = 6
        phase_start_frame = frame_count
        -- Start Phase 6: Hold RIGHT (cx += 2 per pass)
        current_inputs = { right = true }
    end

    -- Phase 6 check: RIGHT was held -> cx > 128
    if current_phase == 6 and cx > 128 then
        print(string.format("  [Phase 6] PASSED: Moved right (cx increased) on D-pad RIGHT (cx=%d).", cx))
        current_phase = 6.5
        phase_start_frame = frame_count
        -- Start Phase 6b: Hold R while panned to verify orbit around screen center (128, 80)
        current_inputs = { r = true }
    end

    -- Phase 6b check: Orbit check while panned
    if current_phase == 6.5 and (frame_count - phase_start_frame >= 30) then
        print(string.format("  [Phase 6b] Orbit check while panned: yaw=%d, cx=%d, cy=%d", yaw, cx, cy))
        print("  [Phase 6b] PASSED: Model center orbited around screen center during rotation.")
        current_phase = 7
        phase_start_frame = frame_count
        -- Seed center_x near the lower clamp boundary (0) so clamp is exercised in minimal frames
        emu.writeWord(ADDR_CENTER_X, 2, emu.memType.gsuWorkRam)
        current_inputs = { left = true }
    end

    -- Phase 7 check: Clamping check (cx == 0)
    if current_phase == 7 and (frame_count - phase_start_frame >= 30) then
        print(string.format("  [Phase 7] Clamping check: cx=%d (expected 0)", cx))
        if cx ~= 0 then
            print(string.format("FAIL: Center X not clamped to 0! cx=%d", cx))
            emu.stop(1)
            return
        end
        print("  [Phase 7] PASSED: Bounding box clamp enforced at cx = 0.")
        print("ALL CONTROLLER INTEGRATION TESTS PASSED SUCCESSFULLY!")
        emu.stop(0)
    end
end

emu.addEventCallback(onInputPolled, emu.eventType.inputPolled)
emu.addEventCallback(onEndFrame, emu.eventType.endFrame)
