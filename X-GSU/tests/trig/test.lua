test_setup = 0x0003
test_stop  = 0x005A
OUTPUT     = 0x0AE2

local cases = {
    { r12 = 120, sin = 0x0000, cos = 0x4000 },
    { r12 = 119, sin = 0xFCA7, cos = 0x3FEA },
    { r12 = 118, sin = 0xF94F, cos = 0x3FA6 },
    { r12 = 117, sin = 0xF5FD, cos = 0x3F36 },
    { r12 = 116, sin = 0xF2B2, cos = 0x3E9A },
    { r12 = 115, sin = 0xEF70, cos = 0x3DD2 },
    { r12 = 114, sin = 0xEC39, cos = 0x3CDE },
    { r12 = 113, sin = 0xE910, cos = 0x3BC0 },
    { r12 = 112, sin = 0xE5F8, cos = 0x3A78 },
    { r12 = 111, sin = 0xE2F2, cos = 0x3906 },
    { r12 = 110, sin = 0xE000, cos = 0x376D },
    { r12 = 109, sin = 0xDD25, cos = 0x35AD },
    { r12 = 108, sin = 0xDA62, cos = 0x33C7 },
    { r12 = 107, sin = 0xD7B9, cos = 0x31BD },
    { r12 = 106, sin = 0xD52D, cos = 0x2F90 },
    { r12 = 105, sin = 0xD2BF, cos = 0x2D41 },
    { r12 = 104, sin = 0xD070, cos = 0x2AD3 },
    { r12 = 103, sin = 0xCE43, cos = 0x2847 },
    { r12 = 102, sin = 0xCC39, cos = 0x259E },
    { r12 = 101, sin = 0xCA53, cos = 0x22DB },
    { r12 = 100, sin = 0xC893, cos = 0x2000 },
    { r12 = 99, sin = 0xC6FA, cos = 0x1D0E },
    { r12 = 98, sin = 0xC588, cos = 0x1A08 },
    { r12 = 97, sin = 0xC440, cos = 0x16F0 },
    { r12 = 96, sin = 0xC322, cos = 0x13C7 },
    { r12 = 95, sin = 0xC22E, cos = 0x1090 },
    { r12 = 94, sin = 0xC166, cos = 0x0D4E },
    { r12 = 93, sin = 0xC0CA, cos = 0x0A03 },
    { r12 = 92, sin = 0xC05A, cos = 0x06B1 },
    { r12 = 91, sin = 0xC016, cos = 0x0359 },
    { r12 = 90, sin = 0xC000, cos = 0x0000 },
    { r12 = 89, sin = 0xC016, cos = 0xFCA7 },
    { r12 = 88, sin = 0xC05A, cos = 0xF94F },
    { r12 = 87, sin = 0xC0CA, cos = 0xF5FD },
    { r12 = 86, sin = 0xC166, cos = 0xF2B2 },
    { r12 = 85, sin = 0xC22E, cos = 0xEF70 },
    { r12 = 84, sin = 0xC322, cos = 0xEC39 },
    { r12 = 83, sin = 0xC440, cos = 0xE910 },
    { r12 = 82, sin = 0xC588, cos = 0xE5F8 },
    { r12 = 81, sin = 0xC6FA, cos = 0xE2F2 },
    { r12 = 80, sin = 0xC893, cos = 0xE000 },
    { r12 = 79, sin = 0xCA53, cos = 0xDD25 },
    { r12 = 78, sin = 0xCC39, cos = 0xDA62 },
    { r12 = 77, sin = 0xCE43, cos = 0xD7B9 },
    { r12 = 76, sin = 0xD070, cos = 0xD52D },
    { r12 = 75, sin = 0xD2BF, cos = 0xD2BF },
    { r12 = 74, sin = 0xD52D, cos = 0xD070 },
    { r12 = 73, sin = 0xD7B9, cos = 0xCE43 },
    { r12 = 72, sin = 0xDA62, cos = 0xCC39 },
    { r12 = 71, sin = 0xDD25, cos = 0xCA53 },
    { r12 = 70, sin = 0xE000, cos = 0xC893 },
    { r12 = 69, sin = 0xE2F2, cos = 0xC6FA },
    { r12 = 68, sin = 0xE5F8, cos = 0xC588 },
    { r12 = 67, sin = 0xE910, cos = 0xC440 },
    { r12 = 66, sin = 0xEC39, cos = 0xC322 },
    { r12 = 65, sin = 0xEF70, cos = 0xC22E },
    { r12 = 64, sin = 0xF2B2, cos = 0xC166 },
    { r12 = 63, sin = 0xF5FD, cos = 0xC0CA },
    { r12 = 62, sin = 0xF94F, cos = 0xC05A },
    { r12 = 61, sin = 0xFCA7, cos = 0xC016 },
    { r12 = 60, sin = 0x0000, cos = 0xC000 },
    { r12 = 59, sin = 0x0359, cos = 0xC016 },
    { r12 = 58, sin = 0x06B1, cos = 0xC05A },
    { r12 = 57, sin = 0x0A03, cos = 0xC0CA },
    { r12 = 56, sin = 0x0D4E, cos = 0xC166 },
    { r12 = 55, sin = 0x1090, cos = 0xC22E },
    { r12 = 54, sin = 0x13C7, cos = 0xC322 },
    { r12 = 53, sin = 0x16F0, cos = 0xC440 },
    { r12 = 52, sin = 0x1A08, cos = 0xC588 },
    { r12 = 51, sin = 0x1D0E, cos = 0xC6FA },
    { r12 = 50, sin = 0x2000, cos = 0xC893 },
    { r12 = 49, sin = 0x22DB, cos = 0xCA53 },
    { r12 = 48, sin = 0x259E, cos = 0xCC39 },
    { r12 = 47, sin = 0x2847, cos = 0xCE43 },
    { r12 = 46, sin = 0x2AD3, cos = 0xD070 },
    { r12 = 45, sin = 0x2D41, cos = 0xD2BF },
    { r12 = 44, sin = 0x2F90, cos = 0xD52D },
    { r12 = 43, sin = 0x31BD, cos = 0xD7B9 },
    { r12 = 42, sin = 0x33C7, cos = 0xDA62 },
    { r12 = 41, sin = 0x35AD, cos = 0xDD25 },
    { r12 = 40, sin = 0x376D, cos = 0xE000 },
    { r12 = 39, sin = 0x3906, cos = 0xE2F2 },
    { r12 = 38, sin = 0x3A78, cos = 0xE5F8 },
    { r12 = 37, sin = 0x3BC0, cos = 0xE910 },
    { r12 = 36, sin = 0x3CDE, cos = 0xEC39 },
    { r12 = 35, sin = 0x3DD2, cos = 0xEF70 },
    { r12 = 34, sin = 0x3E9A, cos = 0xF2B2 },
    { r12 = 33, sin = 0x3F36, cos = 0xF5FD },
    { r12 = 32, sin = 0x3FA6, cos = 0xF94F },
    { r12 = 31, sin = 0x3FEA, cos = 0xFCA7 },
    { r12 = 30, sin = 0x4000, cos = 0x0000 },
    { r12 = 29, sin = 0x3FEA, cos = 0x0359 },
    { r12 = 28, sin = 0x3FA6, cos = 0x06B1 },
    { r12 = 27, sin = 0x3F36, cos = 0x0A03 },
    { r12 = 26, sin = 0x3E9A, cos = 0x0D4E },
    { r12 = 25, sin = 0x3DD2, cos = 0x1090 },
    { r12 = 24, sin = 0x3CDE, cos = 0x13C7 },
    { r12 = 23, sin = 0x3BC0, cos = 0x16F0 },
    { r12 = 22, sin = 0x3A78, cos = 0x1A08 },
    { r12 = 21, sin = 0x3906, cos = 0x1D0E },
    { r12 = 20, sin = 0x376D, cos = 0x2000 },
    { r12 = 19, sin = 0x35AD, cos = 0x22DB },
    { r12 = 18, sin = 0x33C7, cos = 0x259E },
    { r12 = 17, sin = 0x31BD, cos = 0x2847 },
    { r12 = 16, sin = 0x2F90, cos = 0x2AD3 },
    { r12 = 15, sin = 0x2D41, cos = 0x2D41 },
    { r12 = 14, sin = 0x2AD3, cos = 0x2F90 },
    { r12 = 13, sin = 0x2847, cos = 0x31BD },
    { r12 = 12, sin = 0x259E, cos = 0x33C7 },
    { r12 = 11, sin = 0x22DB, cos = 0x35AD },
    { r12 = 10, sin = 0x2000, cos = 0x376D },
    { r12 = 9, sin = 0x1D0E, cos = 0x3906 },
    { r12 = 8, sin = 0x1A08, cos = 0x3A78 },
    { r12 = 7, sin = 0x16F0, cos = 0x3BC0 },
    { r12 = 6, sin = 0x13C7, cos = 0x3CDE },
    { r12 = 5, sin = 0x1090, cos = 0x3DD2 },
    { r12 = 4, sin = 0x0D4E, cos = 0x3E9A },
    { r12 = 3, sin = 0x0A03, cos = 0x3F36 },
    { r12 = 2, sin = 0x06B1, cos = 0x3FA6 },
    { r12 = 1, sin = 0x0359, cos = 0x3FEA },
}

local index = 1
local fail_count = 0

function onTestSetup(address, value)
    print("Starting trig test suite (120 iterations)...")
end

function onTestStop(address, value)
    local r_sin = emu.readWord(OUTPUT + 0, emu.memType.gsuWorkRam, false)
    local r_cos = emu.readWord(OUTPUT + 2, emu.memType.gsuWorkRam, false)

    local c = cases[index]
    local match = (r_sin == c.sin) and (r_cos == c.cos)

    if match then
        print(string.format("  [%d/%d] PASSED: angle=%d -> sin=0x%04X, cos=0x%04X",
            index, #cases, c.r12, r_sin, r_cos))
    else
        print(string.format("  [%d/%d] FAILED: angle=%d -> got sin=0x%04X cos=0x%04X, exp sin=0x%04X cos=0x%04X",
            index, #cases, c.r12, r_sin, r_cos, c.sin, c.cos))
        fail_count = fail_count + 1
    end

    if index >= #cases then
        if fail_count == 0 then
            print("TEST PASSED: All trig tests passed.")
            emu.stop(0)
        else
            print(string.format("TEST FAILED: %d tests failed.", fail_count))
            emu.stop(1)
        end
        return
    end

    index = index + 1
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
