test_setup = 0x0003
test_stop  = 0x0024
INPUT_A    = 0x0AB6
INPUT_B    = 0x0ABC
OUTPUT     = 0x08CC

local cases = {
	{
		a = {0x0000, 0x0000, 0x0000},
		b = {0x0000, 0x0000, 0x0000},
		exp = {0x0000, 0x0000, 0x0000}
	},
	{
		a = {0x0001, 0x0002, 0x0003},
		b = {0x0004, 0x0005, 0x0006},
		exp = {0x0005, 0x0007, 0x0009}
	},
	{
		a = {0x0100, 0x0200, 0x0300},
		b = {0x0400, 0x0500, 0x0600},
		exp = {0x0500, 0x0700, 0x0900}
	},
	{
		a = {0xFFFF, 0xFFFE, 0xFFFD},
		b = {0x0001, 0x0002, 0x0003},
		exp = {0x0000, 0x0000, 0x0000}
	},
	{
		a = {0x0064, 0xFFCE, 0x0014},
		b = {0xFFE2, 0x0014, 0xFFCE},
		exp = {0x0046, 0xFFE2, 0xFFE2}
	},
	{
		a = {0xFF00, 0xFE00, 0xFD00},
		b = {0xFF00, 0xFE00, 0xFD00},
		exp = {0xFE00, 0xFC00, 0xFA00}
	},
	{
		a = {0x7FFF, 0x8000, 0xFFFF},
		b = {0x0001, 0x8000, 0x0001},
		exp = {0x8000, 0x0000, 0x0000}
	},
	{
		a = {0x1234, 0x5678, 0x9ABC},
		b = {0x4321, 0x1111, 0x2222},
		exp = {0x5555, 0x6789, 0xBCDE}
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
	print("Starting vector3_add test suite...")
	writeInput(index)
end

function onTestStop(address, value)
	local rx = emu.readWord(OUTPUT + 0, emu.memType.gsuWorkRam, false)
	local ry = emu.readWord(OUTPUT + 2, emu.memType.gsuWorkRam, false)
	local rz = emu.readWord(OUTPUT + 4, emu.memType.gsuWorkRam, false)

	local c = cases[index]
	local match = (rx == c.exp[1]) and (ry == c.exp[2]) and (rz == c.exp[3])

	if match then
		print(string.format("  [%d/%d] PASSED: (%04X,%04X,%04X) + (%04X,%04X,%04X) = (%04X,%04X,%04X)",
			index, #cases,
			c.a[1], c.a[2], c.a[3],
			c.b[1], c.b[2], c.b[3],
			rx, ry, rz))
	else
		print(string.format("  [%d/%d] FAILED: (%04X,%04X,%04X) + (%04X,%04X,%04X) -> got (%04X,%04X,%04X), expected (%04X,%04X,%04X)",
			index, #cases,
			c.a[1], c.a[2], c.a[3],
			c.b[1], c.b[2], c.b[3],
			rx, ry, rz,
			c.exp[1], c.exp[2], c.exp[3]))
		fail_count = fail_count + 1
	end

	if index >= #cases then
		if fail_count == 0 then
			print("TEST PASSED: All vector3_add tests passed.")
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
