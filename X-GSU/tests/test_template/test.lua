
test_setup = 0 -- Agent set this to the lower two bytes of value of test_setup in Test.cpu.sym
test_start = 0 -- Agent set this to the lower two bytes of value of test_start in Test.cpu.sym
test_stop = 0  -- Agent set this to the lower two bytes of value of test_stop in Test.cpu.sym

function onTestSetup(address, value)
	emu.log("setup")
	emu.breakExecution()
end

function onTestStart(address, value)
	emu.log("start")
	emu.breakExecution()
end

function onTestStop(address, value)
	emu.log("stop")
	-- emu.stop exits mesen and returns the specified exit code
	-- call it when you have finished your tests
	emu.stop(0)
end

emu.addMemoryCallback(onTestSetup,
					  emu.callbackType.exec,
					  test_setup,
					  test_setup,
					  4,
					  emu.memType.gsuWorkRam)

emu.addMemoryCallback(onTestStart,
					  emu.callbackType.exec,
					  test_start,
					  test_start,
					  4,
					  emu.memType.gsuWorkRam)


emu.addMemoryCallback(onTestStop,
					  emu.callbackType.exec,
					  test_stop,
					  test_stop,
					  4,
					  emu.memType.gsuWorkRam)

