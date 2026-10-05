test_setup = 0x0003
test_stop  = 0x001E
INPUT      = 0x0AA6
OUTPUT     = 0x0AAA

-- Test 400 (0x00000190), expected sqrt = 20 (0x0014)
local input_high = 0x0000
local input_low  = 0x0190
local expected   = 0x0014

function onTestSetup(address, value)
	print(string.format("Setting sqrt input: 0x%04X%04X", input_high, input_low))
	emu.writeWord(INPUT, input_high, emu.memType.gsuWorkRam)
	emu.writeWord(INPUT + 2, input_low, emu.memType.gsuWorkRam)
	emu.breakExecution()
end

function onTestStop(address, value)
	emu.breakExecution()
	local result = emu.readWord(OUTPUT, emu.memType.gsuWorkRam, false)
	local msg = string.format("OUTPUT = 0x%04X (expected: 0x%04X)", result, expected)
	print(msg)
	emu.log(msg)

	if result == expected then
		print("TEST PASSED: gsu_sqrt32 correctly calculated square root.")
		emu.stop(0)
	else
		print(string.format("TEST FAILED: got 0x%04X, expected 0x%04X", result, expected))
		emu.stop(1)
	end
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
