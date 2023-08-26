--emu.log(string.format("%x", emu.readWord(0x59b,emu.memType.gsuWorkRam,false)))
--emu.log("input")
--emu.log(emu.getLabelAddress("input"))
input_low = {0x0190}
input_high = {0x0000}
expected = {0x0014}
index = 1
output = 0x0
fail = 0

input_addr  = 0x0718
output_addr  = 0x071C
test_setup = 0x0003
test_stop = 0x0034
function setupFirstTest(address, value)
	emu.log("setup")
	emu.log(string.format("0x%04x%04x",input_high[1],input_low[1]))
	emu.writeWord(input_addr,input_high[1],emu.memType.gsuWorkRam)
	emu.writeWord(input_addr + 2,input_low[1],emu.memType.gsuWorkRam)
	emu.breakExecution()
end

emu.addMemoryCallback(setupFirstTest,
					  emu.callbackType.exec,
					  test_setup,
					  test_setup,
					  4,
					  emu.memType.gsuWorkRam)

function setNextInput()
	emu.log(string.format("0x%x%x",input_high[index],input_low[index]))
	emu.writeWord(input_addr, input_high[index], emu.memType.gsuWorkRam)
	emu.writeWord(input_addr + 2, input_low[index], emu.memType.gsuWorkRam)
end

function compareAndLogOutput(address, value)
	local read = emu.readWord(output_addr,emu.memType.gsuWorkRam,false)

	emu.log("Checking")

	if read ~= expected[index] then
		fail = 1
		emu.log(string.format("Error sqrt(0x%x%x) was %x expected %x",input_high[index],input_low[index],read,expected[index]))
	end
	index=index+1
	loopOrExit()
end

function loopOrExit()
	if index > 1 then
		emu.log("Done")
		--emu.stop(fail)
		emu.breakExecution()
	else
		setNextInput()
	end
end


emu.addMemoryCallback(compareAndLogOutput,
					  emu.callbackType.exec,
					  test_stop,
					  test_stop,
					  4,
					  emu.memType.gsuWorkRam)