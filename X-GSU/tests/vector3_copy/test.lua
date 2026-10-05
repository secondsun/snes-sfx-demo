test_setup = 0x0003
test_stop  = 0x0024
INPUT      = 0x0AB6
OUTPUT     = 0x0ABC

local cases = {
	{0x0000, 0x0000, 0x0000},
	{0x1234, 0x5678, 0x9ABC},
	{0xFFFF, 0x8000, 0x7FFF},
	{0xAAAA, 0x5555, 0xDEAD},
	{0xBEEF, 0xCAFE, 0xBABE},
	{0x0100, 0x0200, 0x0300}
}

local index = 1
local fail_count = 0

function writeInput(idx)
	local v = cases[idx]
	emu.writeWord(INPUT + 0, v[1], emu.memType.gsuWorkRam)
	emu.writeWord(INPUT + 2, v[2], emu.memType.gsuWorkRam)
	emu.writeWord(INPUT + 4, v[3], emu.memType.gsuWorkRam)
	-- Clear destination first to ensure copy actually writes it
	emu.writeWord(OUTPUT + 0, 0x0000, emu.memType.gsuWorkRam)
	emu.writeWord(OUTPUT + 2, 0x0000, emu.memType.gsuWorkRam)
	emu.writeWord(OUTPUT + 4, 0x0000, emu.memType.gsuWorkRam)
end

function onTestSetup(address, value)
	print("Starting vector3_copy test suite...")
	writeInput(index)
end

function onTestStop(address, value)
	local rx = emu.readWord(OUTPUT + 0, emu.memType.gsuWorkRam, false)
	local ry = emu.readWord(OUTPUT + 2, emu.memType.gsuWorkRam, false)
	local rz = emu.readWord(OUTPUT + 4, emu.memType.gsuWorkRam, false)

	local exp = cases[index]
	local match = (rx == exp[1]) and (ry == exp[2]) and (rz == exp[3])

	if match then
		print(string.format("  [%d/%d] PASSED: copied (%04X,%04X,%04X) -> (%04X,%04X,%04X)",
			index, #cases,
			exp[1], exp[2], exp[3],
			rx, ry, rz))
	else
		print(string.format("  [%d/%d] FAILED: copied (%04X,%04X,%04X) -> got (%04X,%04X,%04X)",
			index, #cases,
			exp[1], exp[2], exp[3],
			rx, ry, rz))
		fail_count = fail_count + 1
	end

	if index >= #cases then
		if fail_count == 0 then
			print("TEST PASSED: All vector3_copy tests passed.")
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
