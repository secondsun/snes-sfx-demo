-- ==============================================================================
-- superfx-fps.lua — SuperFX (GSU) Engine FPS Monitor & Screen Overlay for Mesen
-- ==============================================================================
-- Purpose:
--   Monitors the render frame rate of the SuperFX RISC coprocessor for games and
--   demos powered by the X-GSU library (e.g., IsoEngine, StarshipMap, SpriteScale).
--
-- How it works:
--   In X-GSU / SuperFX double-buffered rendering architectures, the SNES CPU's
--   VBlank interrupt swaps display buffers by toggling the zero-page flag
--   `VRAM_screen_select` (alternating between 0 and 1) once a full SuperFX frame
--   has been computed and DMA'd into VRAM.
--   This script tracks writes and transitions to `VRAM_screen_select`, calculates
--   both a 1-second rolling FPS and instantaneous frame latency, and renders a
--   real-time On-Screen Display (OSD) directly onto the game screen via
--   Mesen's `emu.drawString()`.
--
-- Compatibility & Loading:
--   - Load interactively at runtime in Mesen via:
--       Debug -> Script Window -> New / Open -> Run
--   - Run headlessly in testrunner mode:
--       Mesen --testrunner utilities/superfx-fps.lua IsoEngine/SuperFX.sfc
--
-- Interoperability for Agents & Tooling:
--   - Performance metrics are published to the global table `_G.SuperFX_FPS`
--     so external scripts, profilers, and agent MCP tools can inspect them.
--   - Emits structured console logs for headless parsing and automated analysis.
-- ==============================================================================

local CONFIG = {
    -- Overlay screen position (in SNES 256x224 pixels)
    x = 8,
    y = 8,

    -- Display configuration
    show_details = true,         -- Show latency (ms, frames) and total frame counts
    bg_color = 0x80000000,       -- Semi-transparent black background box (or 0xFF000000)

    -- Dynamic text colors based on FPS performance
    color_high = 0x00FF66,       -- Green (>= 20 FPS)
    color_med  = 0xFFFF00,       -- Yellow (>= 12 FPS)
    color_low  = 0xFF4444,       -- Red (< 12 FPS)
    color_sub  = 0xCCCCCC,       -- Light grey for secondary stats

    -- Thresholds
    fps_high_threshold = 20.0,
    fps_med_threshold  = 12.0,

    -- Measurement parameters
    window_frames = 60,          -- Rolling window in SNES frames (~1.0s at NTSC 60.0988 Hz)
    console_log_interval = 60,   -- Emit console log every N SNES frames (~1s, 0 = disable)
    fallback_addr = 0x003C       -- Default address for VRAM_screen_select if sym missing
}

-- SNES NTSC Master Refresh Rate
local SNES_FPS = 60.0988

-- State variables
local vram_screen_select_addr = nil
local last_rom_path = nil
local initialized = false

local snes_frame_count = 0
local sfx_frame_count = 0

local last_vram_val = nil
local last_swap_snes_frame = nil
local first_swap_snes_frame = nil

-- Rolling window of SNES frame timestamps where buffer swaps occurred
local swap_history = {}

-- Metrics
local current_rolling_fps = 0.0
local instant_fps = 0.0
local instant_delta_frames = 0
local instant_delta_ms = 0.0
local min_fps = nil
local max_fps = nil

-- Global export table for agent / script interoperability
_G.SuperFX_FPS = {
    current_fps = 0.0,
    instant_fps = 0.0,
    average_fps = 0.0,
    frame_time_ms = 0.0,
    sfx_frame_count = 0,
    snes_frame_count = 0,
    min_fps = 0.0,
    max_fps = 0.0,
    vram_select_addr = nil
}

-- ------------------------------------------------------------------------------
-- Symbol Resolution Helper
-- ------------------------------------------------------------------------------
local function get_script_dir()
    local src = debug.getinfo(1, "S").source
    if src:sub(1, 1) == "@" then
        src = src:sub(2)
    end
    return src:match("(.*/)") or "./"
end

local function parse_sym_file(path)
    local f = io.open(path, "r")
    if not f then return nil end

    local addr = nil
    for line in f:lines() do
        local hex_addr, sym = line:match("^al (%x+) %.([%w_]+)")
        if hex_addr and sym == "VRAM_screen_select" then
            addr = tonumber(hex_addr, 16) & 0xFFFF
            break
        end
    end
    f:close()
    return addr
end

local function resolve_vram_screen_select()
    local resolved_addr = nil
    local resolved_path = nil

    -- 1. Try reading path of loaded ROM from Mesen API
    local rom_info = (emu.getRomInfo and emu.getRomInfo()) or nil
    if rom_info and rom_info.path and rom_info.path ~= "" then
        local rom_dir = rom_info.path:match("(.*/)") or ""
        local rom_base = rom_info.path:match(".*/(.*)%.[^%.]+$") or "SuperFX"

        local candidate_syms = {
            rom_dir .. rom_base .. ".cpu.sym",
            rom_dir .. "SuperFX.cpu.sym",
            rom_dir .. "Test.cpu.sym"
        }
        for _, path in ipairs(candidate_syms) do
            local a = parse_sym_file(path)
            if a then
                resolved_addr = a
                resolved_path = path
                break
            end
        end
    end

    -- 2. Try candidate paths relative to this script / project structure
    if not resolved_addr then
        local script_dir = get_script_dir()
        local fallback_syms = {
            script_dir .. "../IsoEngine/SuperFX.cpu.sym",
            script_dir .. "../StarshipMap/SuperFX.cpu.sym",
            script_dir .. "../../SpriteScale/SuperFX.cpu.sym",
            script_dir .. "SuperFX.cpu.sym",
            "SuperFX.cpu.sym",
            "snes-sfx-demo/X-GSU/IsoEngine/SuperFX.cpu.sym",
            "snes-sfx-demo/X-GSU/StarshipMap/SuperFX.cpu.sym",
            "snes-sfx-demo/SpriteScale/SuperFX.cpu.sym"
        }
        for _, path in ipairs(fallback_syms) do
            local a = parse_sym_file(path)
            if a then
                resolved_addr = a
                resolved_path = path
                break
            end
        end
    end

    if resolved_addr then
        vram_screen_select_addr = resolved_addr
        local msg = string.format("[SFX-FPS] Resolved VRAM_screen_select at 0x%04X (from %s)",
                                  resolved_addr, resolved_path)
        print(msg)
        emu.log(msg)
    else
        vram_screen_select_addr = CONFIG.fallback_addr
        local msg = string.format("[SFX-FPS] Could not locate .cpu.sym; defaulting VRAM_screen_select to 0x%04X",
                                  vram_screen_select_addr)
        print(msg)
        emu.log(msg)
    end

    _G.SuperFX_FPS.vram_select_addr = vram_screen_select_addr
end

-- ------------------------------------------------------------------------------
-- Core Measurement Logic
-- ------------------------------------------------------------------------------
local function record_buffer_swap(new_val)
    sfx_frame_count = sfx_frame_count + 1
    table.insert(swap_history, snes_frame_count)

    if not first_swap_snes_frame then
        first_swap_snes_frame = snes_frame_count
    end

    if last_swap_snes_frame then
        instant_delta_frames = snes_frame_count - last_swap_snes_frame
        if instant_delta_frames > 0 then
            instant_fps = SNES_FPS / instant_delta_frames
            instant_delta_ms = (instant_delta_frames / SNES_FPS) * 1000.0

            if min_fps == nil or instant_fps < min_fps then
                min_fps = instant_fps
            end
            if max_fps == nil or instant_fps > max_fps then
                max_fps = instant_fps
            end
        end
    end
    last_swap_snes_frame = snes_frame_count
    last_vram_val = new_val
end

local function onVramSelectWrite(address, value)
    -- VRAM_screen_select is a binary toggle between screen 0 and screen 1
    local v = value & 0xFF
    if v == 0 or v == 1 then
        if last_vram_val ~= nil and v ~= last_vram_val then
            record_buffer_swap(v)
        else
            last_vram_val = v
        end
    end
end

-- ------------------------------------------------------------------------------
-- Per-Frame Update & Screen Overlay
-- ------------------------------------------------------------------------------
local function onEndFrame()
    snes_frame_count = snes_frame_count + 1

    -- Detect ROM load or ROM swap
    local rom_info = (emu.getRomInfo and emu.getRomInfo()) or nil
    local current_rom = rom_info and rom_info.path or nil
    if not initialized or current_rom ~= last_rom_path then
        resolve_vram_screen_select()
        last_rom_path = current_rom

        -- Register memory callback on VRAM_screen_select write
        if vram_screen_select_addr then
            pcall(function()
                emu.addMemoryCallback(onVramSelectWrite,
                                      emu.callbackType.write,
                                      vram_screen_select_addr,
                                      vram_screen_select_addr,
                                      emu.cpuType.snes,
                                      emu.memType.snesMemory)
            end)
        end
        initialized = true
    end

    -- Fallback polling check in case memory callback is delayed or missed
    if vram_screen_select_addr then
        local current_val = emu.read(vram_screen_select_addr, emu.memType.snesMemory, false)
        if (current_val == 0 or current_val == 1) then
            if last_vram_val ~= nil and current_val ~= last_vram_val then
                record_buffer_swap(current_val)
            else
                last_vram_val = current_val
            end
        end
    end

    -- Prune swaps older than sliding window (CONFIG.window_frames)
    local cutoff_frame = snes_frame_count - CONFIG.window_frames
    while #swap_history > 0 and swap_history[1] <= cutoff_frame do
        table.remove(swap_history, 1)
    end

    -- Calculate rolling FPS over the window
    if first_swap_snes_frame and snes_frame_count > first_swap_snes_frame then
        local effective_span = math.min(snes_frame_count - first_swap_snes_frame, CONFIG.window_frames)
        if effective_span > 0 then
            current_rolling_fps = (#swap_history / effective_span) * SNES_FPS
        end
    else
        current_rolling_fps = 0.0
    end

    -- Calculate cumulative session average
    local avg_fps = 0.0
    if first_swap_snes_frame and snes_frame_count > first_swap_snes_frame then
        local total_span = snes_frame_count - first_swap_snes_frame
        avg_fps = (sfx_frame_count / total_span) * SNES_FPS
    end

    -- Update global interoperability structure
    _G.SuperFX_FPS.current_fps = current_rolling_fps
    _G.SuperFX_FPS.instant_fps = instant_fps
    _G.SuperFX_FPS.average_fps = avg_fps
    _G.SuperFX_FPS.frame_time_ms = instant_delta_ms
    _G.SuperFX_FPS.sfx_frame_count = sfx_frame_count
    _G.SuperFX_FPS.snes_frame_count = snes_frame_count
    _G.SuperFX_FPS.min_fps = min_fps or 0.0
    _G.SuperFX_FPS.max_fps = max_fps or 0.0

    -- Pick color based on performance
    local fps_color = CONFIG.color_low
    if current_rolling_fps >= CONFIG.fps_high_threshold then
        fps_color = CONFIG.color_high
    elseif current_rolling_fps >= CONFIG.fps_med_threshold then
        fps_color = CONFIG.color_med
    end

    -- Render on-screen display (OSD)
    local x = CONFIG.x
    local y = CONFIG.y

    local fps_text
    if sfx_frame_count == 0 then
        fps_text = "SFX FPS: -- (waiting for engine)"
    else
        fps_text = string.format("SFX FPS: %.1f", current_rolling_fps)
    end

    -- Main FPS Header
    emu.drawString(x, y, fps_text, fps_color, CONFIG.bg_color)

    -- Secondary Metrics
    if CONFIG.show_details and sfx_frame_count > 0 then
        local line2 = string.format("Time: %.1fms (%df) | Avg: %.1f",
                                    instant_delta_ms, instant_delta_frames, avg_fps)
        local line3 = string.format("Frames: %d SFX / %d SNES",
                                    sfx_frame_count, snes_frame_count)

        emu.drawString(x, y + 10, line2, CONFIG.color_sub, CONFIG.bg_color)
        emu.drawString(x, y + 20, line3, CONFIG.color_sub, CONFIG.bg_color)
    end

    -- Periodic console output for headless testrunner / agents
    if CONFIG.console_log_interval > 0 and (snes_frame_count % CONFIG.console_log_interval == 0) then
        print(string.format("[SFX_FPS] snes_f=%d sfx_f=%d fps=%.1f instant_fps=%.1f latency=%.1fms avg=%.1f",
                            snes_frame_count, sfx_frame_count, current_rolling_fps,
                            instant_fps, instant_delta_ms, avg_fps))
    end
end

-- ------------------------------------------------------------------------------
-- Register Mesen Event Callbacks
-- ------------------------------------------------------------------------------
emu.addEventCallback(onEndFrame, emu.eventType.endFrame)

local init_msg = "[SFX-FPS] SuperFX FPS monitor loaded. Listening for VRAM_screen_select swaps..."
print(init_msg)
emu.log(init_msg)
