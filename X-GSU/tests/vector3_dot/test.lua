test_setup = 0x0003
test_stop  = 0x0028
INPUT_A    = 0x0ABA
INPUT_B    = 0x0AC0
OUTPUT     = 0x0AC6

local cases = {
	{
		a = {0x0100, 0x0000, 0x0000},
		b = {0x0000, 0x0100, 0x0000},
		exp = 0x0000
	},
	{
		a = {0x0100, 0x0000, 0x0000},
		b = {0x0100, 0x0000, 0x0000},
		exp = 0x0100
	},
	{
		a = {0x0000, 0x0100, 0x0000},
		b = {0x0000, 0xFF00, 0x0000},
		exp = 0xFF00
	},
	{
		a = {0x0100, 0x0200, 0x0300},
		b = {0x0400, 0xFB00, 0x0600},
		exp = 0x0C00
	},
	{
		a = {0x0080, 0x0080, 0x0080},
		b = {0x0080, 0x0080, 0x0080},
		exp = 0x00C0
	},
	{
		a = {0xFF80, 0x0100, 0xFE00},
		b = {0x0200, 0x0080, 0xFF00},
		exp = 0x0180
	},
	{
		a = {0x0000, 0x0000, 0x0000},
		b = {0x1234, 0x5678, 0x9ABC},
		exp = 0x0000
	},
	{
		a = {0x0093, 0x0093, 0x0093},
		b = {0x0093, 0x0093, 0x0093},
		exp = 0x00FC
	}
}

local index = 1
local fail_count = 0

function writeInput(idx)
	local c = cases[idx]
	emu.writeWord(INPUT_A + 0, c.a[1], emu.memType.gsuWorkRam)
	emu.writeWord(INPUT_A + 2, c.a[2], emu.memType.gsuWorkRam)
	emu.writeWord(INPUT_A + 4, c.a[3], emu.memType.gsuWorkRam)

	emu.writeWord(INPUT_B + 0, c.b[1], emu.memType.gsuWorkRam)
	emu.writeWord(INPUT_B + 2, c.b[2], emu.memType.gsuWorkRam)
	emu.writeWord(INPUT_B + 4, c.b[3], emu.memType.gsuWorkRam)
end

function onTestSetup(address, value)
	print("Starting vector3_dot test suite...")
	writeInput(index)
end

function onTestStop(address, value)
	local result = emu.readWord(OUTPUT, emu.memType.gsuWorkRam, false)
	local c = cases[index]

	if result == c.exp then
		print(string.format("  [%d/%d] PASSED: (%04X,%04X,%04X) . (%04X,%04X,%04X) = 0x%04X",
			index, #cases,
			c.a[1], c.a[2], c.a[3],
			c.b[1], c.b[2], c.b[3],
			result))
	else
		print(string.format("  [%d/%d] FAILED: (%04X,%04X,%04X) . (%04X,%04X,%04X) -> got 0x%04X, expected 0x%04X",
			index, #cases,
			c.a[1], c.a[2], c.a[3],
			c.b[1], c.b[2], c.b[3],
			result, c.exp))
		fail_count = fail_count + 1
	end

	if index >= #cases then
		if fail_count == 0 then
			print("TEST PASSED: All vector3_dot tests passed.")
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
