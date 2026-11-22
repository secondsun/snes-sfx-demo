-- test.lua - Mesen CE hardware unit test for sfx-optimizer R10 stack spill lowering
io.stdout:setvbuf("no")
test_setup    = 0x000A
test_stop     = 0x007E
TEST_CASE_IDX = 0x0CB2
TEST_RESULT   = 0x0CB4

local index = 1
local fail_count = 0
local cases = {
    { name = "14 Simultaneously Live Variables (R10 Spill Frame)", expected = 191 },
    { name = "Spilled Variables Inside forR Loop (+4B backuploop deltaSp)", expected = 273 },
    { name = "Flag-Preserving Spilled Decrement Loop (sub #1; bne)", expected = 128 },
    { name = "Call Passing Spilled Arg & Storing Spilled Return", expected = 111 },
}

function runCase(idx)
    emu.writeWord(TEST_CASE_IDX, idx, emu.memType.gsuWorkRam)
end

local started = false
function onTestSetup(address, value)
    if not started then
        started = true
        print("==================================================================")
        print(" Starting test_spill_alloc Unit Test Suite")
        print("==================================================================")
        runCase(index)
    end
end

function onTestStop(address, value)
    local actual = emu.readWord(TEST_RESULT + 0, emu.memType.gsuWorkRam, false)
    local sp_before = emu.readWord(TEST_RESULT + 2, emu.memType.gsuWorkRam, false)
    local sp_after  = emu.readWord(TEST_RESULT + 4, emu.memType.gsuWorkRam, false)
    local sentinel  = emu.readWord(TEST_RESULT + 6, emu.memType.gsuWorkRam, false)
    local c = cases[index]

    local ok = (actual == c.expected) and (sp_before == sp_after) and (sentinel == 0xBEEF)
    if ok then
        print(string.format("  [%d/%d] PASSED: %s", index, #cases, c.name))
        print(string.format("         Detail: val=%d (exp %d), r10=%04X->%04X, sent=%04X",
            actual, c.expected, sp_before, sp_after, sentinel))
    else
        fail_count = fail_count + 1
        print(string.format("  [%d/%d] FAILED: %s", index, #cases, c.name))
        print(string.format("         Detail: val=%d (exp %d), r10=%04X->%04X, sent=%04X",
            actual, c.expected, sp_before, sp_after, sentinel))
    end

    index = index + 1
    if index <= #cases then
        runCase(index)
    else
        print("==================================================================")
        if fail_count == 0 then
            print("TEST PASSED: All 4 test_spill_alloc tests passed.")
            emu.stop(0)
        else
            print(string.format("TEST FAILED: %d/%d cases failed.", fail_count, #cases))
            emu.stop(1)
        end
    end
end

emu.addMemoryCallback(onTestSetup, emu.callbackType.exec, test_setup, test_setup, emu.cpuType.gsu, emu.memType.gsuWorkRam)
emu.addMemoryCallback(onTestStop, emu.callbackType.exec, test_stop, test_stop, emu.cpuType.gsu, emu.memType.gsuWorkRam)
