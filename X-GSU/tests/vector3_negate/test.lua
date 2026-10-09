test_setup = 0x0003
test_stop  = 0x0021
INPUT      = 0x0AA6
OUTPUT     = 0x08C2

local cases = {
	{
		input = {0x0000, 0x0000, 0x0000},
		exp   = {0x0000, 0x0000, 0x0000}
	},
	{
		input = {0x0001, 0x0002, 0x0003},
		exp   = {0xFFFF, 0xFFFE, 0xFFFD}
	},
	{
		input = {0x0100, 0x0200, 0x0300},
		exp   = {0xFF00, 0xFE00, 0xFD00}
	},
	{
		input = {0xFFFF, 0xFFFE, 0xFFFD},
		exp   = {0x0001, 0x0002, 0x0003}
	},
	{
		input = {0x0064, 0xFFCE, 0x0014},
		exp   = {0xFF9C, 0x0032, 0xFFEC}
	},
	{
		input = {0x8000, 0x7FFF, 0x0001},
		exp   = {0x8000, 0x8001, 0xFFFF}
	},
	{
		input = {0x1234, 0xABCD, 0x5555},
		exp   = {0xEDCC, 0x5433, 0xAAAB}
	},
	{
		input = {0x7FFF, 0x7FFF, 0x7FFF},
		exp   = {0x8001, 0x8001, 0x8001}
	}
}

local index = 1
local fail_count = 0

function writeInput(idx)
	local c = cases[idx]
	emu.writeWord(INPUT + 0, c.input[1], emu.memType.gsuWorkRam)
	emu.writeWord(INPUT + 2, c.input[2], emu.memType.gsuWorkRam)
	emu.writeWord(INPUT + 4, c.input[3], emu.memType.gsuWorkRam)
end

function onTestSetup(address, value)
	print("Starting vector3_negate test suite...")
	writeInput(index)
end

function onTestStop(address, value)
	local rx = emu.readWord(OUTPUT + 0, emu.memType.gsuWorkRam, false)
	local ry = emu.readWord(OUTPUT + 2, emu.memType.gsuWorkRam, false)
	local rz = emu.readWord(OUTPUT + 4, emu.memType.gsuWorkRam, false)

	local c = cases[index]
	local match = (rx == c.exp[1]) and (ry == c.exp[2]) and (rz == c.exp[3])

	if match then
		print(string.format("  [%d/%d] PASSED: -(%04X,%04X,%04X) = (%04X,%04X,%04X)",
			index, #cases,
			c.input[1], c.input[2], c.input[3],
			rx, ry, rz))
	else
		print(string.format("  [%d/%d] FAILED: -(%04X,%04X,%04X) -> got (%04X,%04X,%04X), expected (%04X,%04X,%04X)",
			index, #cases,
			c.input[1], c.input[2], c.input[3],
			rx, ry, rz,
			c.exp[1], c.exp[2], c.exp[3]))
		fail_count = fail_count + 1
	end

	if index >= #cases then
		if fail_count == 0 then
			print("TEST PASSED: All vector3_negate tests passed.")
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
