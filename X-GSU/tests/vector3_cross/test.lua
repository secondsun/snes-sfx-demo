test_setup = 0x0003
test_stop  = 0x0024
INPUT_A    = 0x0AB6
INPUT_B    = 0x0ABC
OUTPUT     = 0x08D8

local cases = {
	{
		-- Unit X cross Unit Y = Unit Z
		a = {0x0100, 0x0000, 0x0000},
		b = {0x0000, 0x0100, 0x0000},
		exp = {0x0000, 0x0000, 0x0100}
	},
	{
		-- Unit Y cross Unit Z = Unit X
		a = {0x0000, 0x0100, 0x0000},
		b = {0x0000, 0x0000, 0x0100},
		exp = {0x0100, 0x0000, 0x0000}
	},
	{
		-- Unit Z cross Unit X = Unit Y
		a = {0x0000, 0x0000, 0x0100},
		b = {0x0100, 0x0000, 0x0000},
		exp = {0x0000, 0x0100, 0x0000}
	},
	{
		-- Unit Y cross Unit X = -Unit Z
		a = {0x0000, 0x0100, 0x0000},
		b = {0x0100, 0x0000, 0x0000},
		exp = {0x0000, 0x0000, 0xFF00}
	},
	{
		-- Parallel vectors: cross product is 0
		a = {0x0100, 0x0200, 0x0300},
		b = {0x0100, 0x0200, 0x0300},
		exp = {0x0000, 0x0000, 0x0000}
	},
	{
		-- Non-trivial: (1, 2, 3) x (4, 5, 6) = (-3, 6, -3)
		a = {0x0100, 0x0200, 0x0300},
		b = {0x0400, 0x0500, 0x0600},
		exp = {0xFD00, 0x0600, 0xFD00}
	},
	{
		-- Fractional: (0.5, -1.0, 2.0) x (2.0, 0.5, -1.0) = (0, 4.5, 2.25)
		a = {0x0080, 0xFF00, 0x0200},
		b = {0x0200, 0x0080, 0xFF00},
		exp = {0x0000, 0x0480, 0x0240}
	},
	{
		-- Zero vector
		a = {0x0000, 0x0000, 0x0000},
		b = {0x0123, 0x4567, 0x89AB},
		exp = {0x0000, 0x0000, 0x0000}
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
	print("Starting vector3_cross test suite...")
	writeInput(index)
end

function onTestStop(address, value)
	local rx = emu.readWord(OUTPUT + 0, emu.memType.gsuWorkRam, false)
	local ry = emu.readWord(OUTPUT + 2, emu.memType.gsuWorkRam, false)
	local rz = emu.readWord(OUTPUT + 4, emu.memType.gsuWorkRam, false)

	local c = cases[index]
	local match = (rx == c.exp[1]) and (ry == c.exp[2]) and (rz == c.exp[3])

	if match then
		print(string.format("  [%d/%d] PASSED: (%04X,%04X,%04X) x (%04X,%04X,%04X) = (%04X,%04X,%04X)",
			index, #cases,
			c.a[1], c.a[2], c.a[3],
			c.b[1], c.b[2], c.b[3],
			rx, ry, rz))
	else
		print(string.format("  [%d/%d] FAILED: (%04X,%04X,%04X) x (%04X,%04X,%04X) -> got (%04X,%04X,%04X), expected (%04X,%04X,%04X)",
			index, #cases,
			c.a[1], c.a[2], c.a[3],
			c.b[1], c.b[2], c.b[3],
			rx, ry, rz,
			c.exp[1], c.exp[2], c.exp[3]))
		fail_count = fail_count + 1
	end

	if index >= #cases then
		if fail_count == 0 then
			print("TEST PASSED: All vector3_cross tests passed.")
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
