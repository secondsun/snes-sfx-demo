test_setup = 0x0003
test_stop  = 0x0024
INPUT      = 0x0AA8
OUTPUT     = 0x0AAE

local input = {
	{0x0015, 0x0000, 0x0000},   -- Vector v1
	{0x0000, 0x0100, 0x0000},   -- Vector v2
	{0x0000, 0x0000, 0x0100},   -- Vector v3
	{0xfe00, 0x0300, 0x0500},   -- Vector v4
	{0x0400, 0x0100, 0x0300},   -- Vector v5
	{0x0200, 0x0200, 0x0200},   -- Vector v6
	{0x0100, 0x0200, 0x0300},   -- Vector v7
	{0x0300, 0x0000, 0x0400},   -- Vector v8
	{0x0100, 0x0100, 0x0100},   -- Vector v9
	{0x0000, 0x0300, 0x0000},   -- Vector v10
	{0x0100, 0x0400, 0x0200},   -- Vector v11
	{0x0400, 0x0400, 0x0400}    -- Vector v12
}

local expected = {
	0x0015,    -- Length of v1
	0x0100,    -- Length of v2
	0x0100,    -- Length of v3
	0x062a,    -- Length of v4
	0x0519,    -- Length of v5
	0x0376,    -- Length of v6
	0x03bd,    -- Length of v7
	0x0500,    -- Length of v8
	0x01bb,    -- Length of v9
	0x0300,    -- Length of v10
	0x0495,    -- Length of v11
	0x06ed     -- Length of v12
}

local index = 1
local fail_count = 0

function writeInput(idx)
	local v = input[idx]
	emu.writeWord(INPUT + 0, v[1], emu.memType.gsuWorkRam)
	emu.writeWord(INPUT + 2, v[2], emu.memType.gsuWorkRam)
	emu.writeWord(INPUT + 4, v[3], emu.memType.gsuWorkRam)
end

function onTestSetup(address, value)
	print("Starting vector3_length test suite...")
	writeInput(index)
end

function onTestStop(address, value)
	local result = emu.readWord(OUTPUT, emu.memType.gsuWorkRam, false)
	local exp = expected[index]
	local v = input[index]

	if result == exp then
		print(string.format("  [%d/12] PASSED: v=(0x%04X, 0x%04X, 0x%04X) -> len=0x%04X",
			index, v[1], v[2], v[3], result))
	else
		print(string.format("  [%d/12] FAILED: v=(0x%04X, 0x%04X, 0x%04X) -> got 0x%04X, expected 0x%04X",
			index, v[1], v[2], v[3], result, exp))
		fail_count = fail_count + 1
	end

	if index >= #input then
		if fail_count == 0 then
			print("TEST PASSED: All vector3_length tests passed.")
			emu.stop(0)
		else
			print(string.format("TEST FAILED: %d tests failed.", fail_count))
			emu.stop(1)
		end
		return
	end

	index = index + 1
	writeInput(index)
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
