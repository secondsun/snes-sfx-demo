test_setup = 0x0003
test_start = 0x0005
test_stop  = 0x0024
OUTPUT     = 0x041A

function onTestStop(address, value)
	emu.log(string.format("GSU reached test_stop at 0x%04X", address))

	local expected = { 0xDE, 0xAD, 0xBE, 0xEF, 0xCA, 0xFE, 0xBA, 0xBE }
	local pass = true

	for i = 1, #expected do
		local byte_val = emu.read(OUTPUT + i - 1, emu.memType.gsuWorkRam, false)
		local msg = string.format("OUTPUT[%d] = 0x%02X (expected: 0x%02X)", i - 1, byte_val, expected[i])
		print(msg)
		emu.log(msg)
		if byte_val ~= expected[i] then
			pass = false
		end
	end

	emu.breakExecution()
	if pass then
		print("TEST PASSED: rom_to_ram copied all bytes correctly.")
		--emu.stop(0)
	else
		print("TEST FAILED: byte mismatch detected.")
		--emu.stop(1)
	end
end

emu.addMemoryCallback(onTestStop,
					  emu.callbackType.exec,
					  test_stop,
					  test_stop,
					  4,
					  emu.memType.gsuWorkRam)
