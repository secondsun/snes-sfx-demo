-- test.lua for draw_textured_triangle test
local test_stop = 0x00D4
local idle_addr = 0x035B

-- Synchronize test_stop and idle from Test.cpu.sym if available
local sym_file = io.open("snes-sfx-demo/X-GSU/tests/draw_textured_triangle/Test.cpu.sym", "r") or io.open("Test.cpu.sym", "r")
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
        if post_stop_frames >= 8 then
            local screenshot = emu.takeScreenshot()
            if screenshot then
                local out_path = "/Users/summerspittman/Projects/retro-superfx/snes-sfx-demo/X-GSU/tests/draw_textured_triangle/actual_render.png"
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

-- TEXTURE_TABLE offsets in TEXTURES.i
local TEXTURE_TABLE = {
    [0] = 0x0000, -- roof
    [1] = 0x0020, -- grass
    [2] = 0x0000, -- character
    [3] = 0x0800, -- sand
    [4] = 0x0820, -- water
    [5] = 0x1000, -- stone
}

local function sampleTexel(u, v, table_index)
    local base = TEXTURE_TABLE[table_index] or 0
    local offset = base + (v * 64) + u + 1
    if offset < 1 or offset > #tex_data then
        return 0
    end
    return string.byte(tex_data, offset)
end

local function s16(v)
    v = v & 0xFFFF
    if v >= 0x8000 then
        return v - 0x10000
    end
    return v
end

local function recip_lookup(d)
    if d <= 0 then return 0 end
    if d == 1 or d == 2 then return 0x7FFF end
    if d >= 256 then return 0x0100 end
    return math.floor((65536 / d) + 0.5)
end

local function gsu_interp(val_top, val_bot, f_reg)
    local delta = s16(val_bot - val_top)
    local doubled = s16(delta * 2)
    local prod = math.floor((doubled * s16(f_reg)) / 65536)
    return s16(val_top + prod)
end

-- Reference model of SuperFX draw_textured_triangle
local function rasterizeExpectedTriangle(fb, verts, table_index)
    local SCREEN_WIDTH = 128
    local SCREEN_HEIGHT = 160

    local minY = verts[1].y
    local maxY = verts[1].y
    for i = 2, 3 do
        if verts[i].y < minY then minY = verts[i].y end
        if verts[i].y > maxY then maxY = verts[i].y end
    end

    if minY < 0 then minY = 0 end
    if maxY > SCREEN_HEIGHT - 1 then maxY = SCREEN_HEIGHT - 1 end
    if minY > maxY then return end

    for curr_y = minY, maxY do
        local xMin = 0x7FFF
        local xMax = -0x8000
        local minU, maxU = 0, 0
        local minV, maxV = 0, 0

        for i = 1, 3 do
            local j = (i % 3) + 1
            local v0 = verts[i]
            local v1 = verts[j]

            local top, bot = nil, nil
            if v0.y <= curr_y and curr_y < v1.y then
                top, bot = v0, v1
            elseif v1.y <= curr_y and curr_y < v0.y then
                top, bot = v1, v0
            end

            if top and bot then
                local dy = bot.y - top.y
                local recip_dy = recip_lookup(dy)
                local diff_y = curr_y - top.y
                local lmult_lo = (diff_y * recip_dy) & 0xFFFF
                local f_reg = lmult_lo >> 1

                local x = gsu_interp(top.x, bot.x, f_reg)
                local u = gsu_interp(top.u, bot.u, f_reg)
                local v = gsu_interp(top.v, bot.v, f_reg)

                if x < xMin then
                    xMin = x
                    minU = u
                    minV = v
                end
                if x > xMax then
                    xMax = x
                    maxU = u
                    maxV = v
                end
            end
        end

        if xMin < xMax then
            local startX = math.max(0, xMin)
            local endX = math.min(SCREEN_WIDTH - 1, xMax)
            if startX <= endX then
                local dx = xMax - xMin
                local recip_dx = recip_lookup(dx)
                local recip_dx_q15 = (dx == 1) and 0x7FFF or ((recip_dx - 1) >> 1)
                for x = startX, endX do
                    local diff_x = x - xMin
                    local f_reg = (diff_x * recip_dx_q15) & 0xFFFF

                    local u = gsu_interp(minU, maxU, f_reg)
                    local v = gsu_interp(minV, maxV, f_reg)

                    local tu = ((u >> 8) & 0xFF) & 31
                    local tv = ((v >> 8) & 0xFF) & 31
                    fb[curr_y * SCREEN_WIDTH + x] = sampleTexel(tu, tv, table_index)
                end
            end
        elseif xMin == xMax and xMin >= 0 and xMin < SCREEN_WIDTH then
            local tu = ((minU >> 8) & 0xFF) & 31
            local tv = ((minV >> 8) & 0xFF) & 31
            fb[curr_y * SCREEN_WIDTH + xMin] = sampleTexel(tu, tv, table_index)
        end
    end
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
    print("test_stop reached! Verifying draw_textured_triangle framebuffer...")

    local expected_fb = {}
    for i = 0, 128 * 160 - 1 do
        expected_fb[i] = 0
    end

    -- Triangle 1: (0,0)-(31,0)-(0,31), roof (0)
    rasterizeExpectedTriangle(expected_fb, {
        { x = 0,  y = 0,  u = 0x0000, v = 0x0000 },
        { x = 31, y = 0,  u = 0x1F00, v = 0x0000 },
        { x = 0,  y = 31, u = 0x0000, v = 0x1F00 },
    }, 0)

    -- Triangle 2: (40,8)-(88,24)-(52,64), grass (1)
    rasterizeExpectedTriangle(expected_fb, {
        { x = 40, y = 8,  u = 0x0000, v = 0x0000 },
        { x = 88, y = 24, u = 0x1F00, v = 0x0000 },
        { x = 52, y = 64, u = 0x0000, v = 0x1F00 },
    }, 1)

    local total_checked = 0
    local non_zero_pixels = 0
    local mismatches = 0
    local first_mismatch = nil

    for y = 0, 159 do
        for x = 0, 127 do
            total_checked = total_checked + 1
            local expected = expected_fb[y * 128 + x]
            local actual = getFramebufferPixel(x, y)
            if actual ~= 0 then
                non_zero_pixels = non_zero_pixels + 1
            end
            if actual ~= expected then
                mismatches = mismatches + 1
                if not first_mismatch then
                    first_mismatch = string.format("Mismatch at (x=%d, y=%d): expected %d, got %d", x, y, expected, actual)
                end
            end
        end
    end

    print(string.format("Checked %d pixels (%d non-zero textured pixels rendered).", total_checked, non_zero_pixels))
    if mismatches == 0 and non_zero_pixels > 500 then
        print("PASS: All " .. total_checked .. " pixels matched expected textured triangle rasterization!")
        all_passed = true
    else
        print(string.format("FAIL: %d mismatches, %d non-zero pixels!", mismatches, non_zero_pixels))
        if first_mismatch then
            print("  First mismatch: " .. first_mismatch)
        end
        all_passed = false
    end

    test_finished = true
end

emu.addMemoryCallback(onTestStop,
                      emu.callbackType.exec,
                      test_stop,
                      test_stop,
                      4,
                      emu.memType.gsuWorkRam)
