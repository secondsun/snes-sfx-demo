-- test.lua for plot_texel test
local test_stop = 0x0142
local idle_addr = 0x035B

-- Synchronize test_stop and idle from Test.cpu.sym if available
local sym_file = io.open("snes-sfx-demo/X-GSU/tests/plot_texel/Test.cpu.sym", "r") or io.open("Test.cpu.sym", "r")
if sym_file then
    for line in sym_file:lines() do
        local addr, name = line:match("al%s+([0-9A-Fa-f]+)%s+%.([%w_]+)")
        if name == "test_stop" then
            test_stop = tonumber(addr:sub(-4), 16)
        elseif name == "idle" then
            idle_addr = tonumber(addr:sub(-4), 16)
        end
    end
    sym_file:close()
end

print(string.format("Registered test_stop at GSU address: 0x%04X", test_stop))
print(string.format("Registered idle at CPU address: 0x%04X", idle_addr or 0))

local test_finished = false
local all_passed = false
local post_stop_frames = 0

emu.addEventCallback(function()
    if test_finished then
        post_stop_frames = post_stop_frames + 1
        if post_stop_frames >= 4 then
            local screenshot = emu.takeScreenshot()
            if screenshot then
                local out_path = "/Users/summerspittman/Projects/retro-superfx/snes-sfx-demo/X-GSU/tests/plot_texel/actual_render.png"
                local sf = io.open(out_path, "wb")
                if sf then
                    sf:write(screenshot)
                    sf:close()
                    print("Saved render screenshot to: " .. out_path)
                end
            end
            if all_passed then
                emu.stop(0)
            else
                emu.stop(1)
            end
        end
    end
end, emu.eventType.endFrame)

-- Load TEXTURES_graphics.bin
local candidates = {
    "snes-sfx-demo/X-GSU/IsoEngine/Data/TEXTURES_graphics.bin",
    "../../IsoEngine/Data/TEXTURES_graphics.bin",
    "IsoEngine/Data/TEXTURES_graphics.bin",
    "X-GSU/IsoEngine/Data/TEXTURES_graphics.bin",
    "/Users/summerspittman/Projects/retro-superfx/snes-sfx-demo/X-GSU/IsoEngine/Data/TEXTURES_graphics.bin"
}

local tex_data = nil
for _, path in ipairs(candidates) do
    local f = io.open(path, "rb")
    if f then
        tex_data = f:read("*all")
        f:close()
        print("Loaded texture binary from: " .. path .. " (" .. #tex_data .. " bytes)")
        break
    end
end

if not tex_data then
    print("ERROR: Could not locate TEXTURES_graphics.bin")
    emu.stop(1)
    return
end

local function getExpectedTexel(x, y)
    local offset = y * 64 + x + 1
    if offset > #tex_data then
        return 0
    end
    return string.byte(tex_data, offset)
end

local function getFramebufferPixel(x, y)
    local screenbase = 0x4000
    local tx = math.floor(x / 8)
    local ty = math.floor(y / 8)
    local tileIndex = tx * 20 + ty
    local tileAddress = screenbase + tileIndex * 32 + (y % 8) * 2

    local b0 = emu.read(tileAddress + 0, emu.memType.gsuWorkRam, false)
    local b1 = emu.read(tileAddress + 1, emu.memType.gsuWorkRam, false)
    local b2 = emu.read(tileAddress + 16, emu.memType.gsuWorkRam, false)
    local b3 = emu.read(tileAddress + 17, emu.memType.gsuWorkRam, false)

    local shift = 7 - (x % 8)
    local bit0 = (b0 >> shift) & 1
    local bit1 = (b1 >> shift) & 1
    local bit2 = (b2 >> shift) & 1
    local bit3 = (b3 >> shift) & 1

    return bit0 | (bit1 << 1) | (bit2 << 2) | (bit3 << 3)
end

local stopped = false

function onTestStop(address, value)
    if stopped then return end
    stopped = true
    print("test_stop reached! Verifying framebuffer bitplanes against TEXTURES_graphics.bin...")
    pcall(function()
        local state = emu.getState()
        print(string.format("CPU PC: 0x%06X", state.cpu.pc or 0))
    end)

    local total_checked = 0
    local mismatches = 0
    local first_mismatch = nil

    -- Check Rows 0..63, Cols 0..63 (64x64 = 4096 pixels)
    for y = 0, 63 do
        for x = 0, 63 do
            total_checked = total_checked + 1
            local expected = getExpectedTexel(x, y)
            local actual = getFramebufferPixel(x, y)
            if actual ~= expected then
                mismatches = mismatches + 1
                if not first_mismatch then
                    first_mismatch = string.format("Mismatch at (x=%d, y=%d): expected %d, got %d", x, y, expected, actual)
                end
            end
        end
    end

    -- Check Rows 64..95, Cols 0..31 (32x32 = 1024 pixels)
    for y = 64, 95 do
        for x = 0, 31 do
            total_checked = total_checked + 1
            local expected = getExpectedTexel(x, y)
            local actual = getFramebufferPixel(x, y)
            if actual ~= expected then
                mismatches = mismatches + 1
                if not first_mismatch then
                    first_mismatch = string.format("Mismatch at (x=%d, y=%d): expected %d, got %d", x, y, expected, actual)
                end
            end
        end
    end

    print(string.format("Checked %d pixels in framebuffer.", total_checked))
    if mismatches == 0 then
        print("PASS: All " .. total_checked .. " pixels in the 4 bitplanes matched TEXTURES_graphics.bin exactly!")
    else
        print(string.format("FAIL: %d / %d pixels mismatched!", mismatches, total_checked))
        if first_mismatch then
            print("  First mismatch: " .. first_mismatch)
        end
    end

    all_passed = (mismatches == 0)
    test_finished = true
end

emu.addMemoryCallback(onTestStop,
                      emu.callbackType.exec,
                      test_stop,
                      test_stop,
                      4,
                      emu.memType.gsuWorkRam)
