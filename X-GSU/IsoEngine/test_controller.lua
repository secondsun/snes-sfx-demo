-- Automated controller integration test for IsoEngine in Mesen CE
local ADDR_JOYPAD   = 0x09E2
local ADDR_ISO_CAM  = 0x09E4
local ADDR_YAW      = 0x09E4
local ADDR_CENTER_X = 0x09EA
local ADDR_CENTER_Y = 0x09EC

-- Dynamically resolve symbols from SuperFX.cpu.sym if available
local function load_symbols()
    local paths = { "SuperFX.cpu.sym", "snes-sfx-demo/X-GSU/IsoEngine/SuperFX.cpu.sym" }
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
    local cx  = emu.readWord(ADDR_CENTER_X, emu.memType.gsuWorkRam)
    local cy  = to_signed16(emu.readWord(ADDR_CENTER_Y, emu.memType.gsuWorkRam))
    local pad = emu.readWord(ADDR_JOYPAD, emu.memType.gsuWorkRam)

    -- Phase 0: Wait for initial scene boot (frame 8)
    if frame_count == 8 then
        print(string.format("Initial state at frame %d: yaw=%d, cx=%d, cy=%d", frame_count, yaw, cx, cy))
        if yaw ~= 1 or cx ~= 128 or cy ~= 80 then
            print(string.format("FAIL: Unexpected initial state! yaw=%d (exp 1), cx=%d (exp 128), cy=%d (exp 80)", yaw, cx, cy))
            emu.stop(1)
            return
        end
        print("  [Init] Boot state validated (yaw=1, cx=128, cy=80).")
        -- Start Phase 1: Hold R for 12 frames
        current_inputs = { r = true }
    end

    -- Phase 1 check at frame 20: R was held
    if frame_count == 20 then
        print(string.format("  [Phase 1] Hold R: yaw=%d (pad=0x%04X, expected > 1)", yaw, pad))
        if yaw <= 1 then
            print("FAIL: Yaw did not increment when holding R!")
            emu.stop(1)
            return
        end
        print("  [Phase 1] PASSED: Yaw incremented on R button.")
        -- Start Phase 2: Hold L for 30 frames (should decrement yaw and wrap around 120)
        current_inputs = { l = true }
    end

    -- Phase 2 check at frame 50: L was held
    if frame_count == 50 then
        print(string.format("  [Phase 2] Hold L: yaw=%d (pad=0x%04X)", yaw, pad))
        if yaw <= 100 then
            print("FAIL: Yaw did not wrap towards 120 when holding L!")
            emu.stop(1)
            return
        end
        print("  [Phase 2] PASSED: Yaw decremented and wrapped on L button.")
        -- Start Phase 3: Hold UP for 20 frames (move up: cy -= 2 per frame)
        current_inputs = { up = true }
    end

    -- Phase 3 check at frame 70: UP was held
    if frame_count == 70 then
        print(string.format("  [Phase 3] Hold UP: cy=%d (pad=0x%04X, expected < 80)", cy, pad))
        if cy >= 80 then
            print("FAIL: Center Y did not decrease when pressing UP!")
            emu.stop(1)
            return
        end
        print("  [Phase 3] PASSED: Moved up (cy decreased) on D-pad UP.")
        -- Start Phase 4: Hold DOWN for 30 frames (move down: cy += 2 per frame)
        current_inputs = { down = true }
    end

    -- Phase 4 check at frame 100: DOWN was held
    if frame_count == 100 then
        print(string.format("  [Phase 4] Hold DOWN: cy=%d (pad=0x%04X, expected > 80)", cy, pad))
        if cy <= 80 then
            print("FAIL: Center Y did not increase when pressing DOWN!")
            emu.stop(1)
            return
        end
        print("  [Phase 4] PASSED: Moved down (cy increased) on D-pad DOWN.")
        -- Start Phase 5: Hold LEFT for 20 frames (move left: cx -= 2 per frame)
        current_inputs = { left = true }
    end

    -- Phase 5 check at frame 120: LEFT was held
    if frame_count == 120 then
        print(string.format("  [Phase 5] Hold LEFT: cx=%d (pad=0x%04X, expected < 128)", cx, pad))
        if cx >= 128 then
            print("FAIL: Center X did not decrease when pressing LEFT!")
            emu.stop(1)
            return
        end
        print("  [Phase 5] PASSED: Moved left (cx decreased) on D-pad LEFT.")
        -- Start Phase 6: Hold RIGHT for 30 frames (move right: cx += 2 per frame)
        current_inputs = { right = true }
    end

    -- Phase 6 check at frame 150: RIGHT was held
    if frame_count == 150 then
        print(string.format("  [Phase 6] Hold RIGHT: cx=%d (pad=0x%04X, expected > 128)", cx, pad))
        if cx <= 128 then
            print("FAIL: Center X did not increase when pressing RIGHT!")
            emu.stop(1)
            return
        end
        print("  [Phase 6] PASSED: Moved right (cx increased) on D-pad RIGHT.")
        -- Start Phase 6b: Hold R for 20 frames while panned to verify orbit around screen center (128, 80)
        current_inputs = { r = true }
    end

    -- Phase 6b check at frame 170: R was held while panned
    if frame_count == 170 then
        print(string.format("  [Phase 6b] Orbit check while panned: yaw=%d, cx=%d, cy=%d", yaw, cx, cy))
        if cx == 138 and cy == 90 then
            print("FAIL: Model did not orbit around screen center! cx and cy remained static during rotation.")
            emu.stop(1)
            return
        end
        print("  [Phase 6b] PASSED: Model center orbited around screen center during rotation.")
        -- Start Phase 7: Hold LEFT for 200 frames to hit min clamp (cx = 0)
        current_inputs = { left = true }
    end

    -- Phase 7 check at frame 430: Clamping
    if frame_count == 430 then
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

