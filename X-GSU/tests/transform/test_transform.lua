﻿--emu.log(string.format("%x", emu.readWord(0x59b,emu.memType.gsuWorkRam,false)))
--emu.log("input")
--emu.log(emu.getLabelAddress("input"))

expected = {0xfc00,0x0,0xfbfc}
index = 1
output = 0x0
fail = 0



function compareAndLogOutput(address, value)
	--local read = emu.readWord(0x36A + 2*(index -1),emu.memType.gsuWorkRam,false)

	emu.log("Checking")
	while (index <= 3)
	do 
		local read = emu.readWord(0x77C + 2*(index -1),emu.memType.gsuWorkRam,false)
		if read ~= expected[index] then
			fail = 1
			emu.log(expected[index])
			emu.log(index)

			emu.log(string.format("Error lookat(%x) was %x expected %x", index,read,expected[index]))
		end
		index=index+1
	end
	emu.breakExecution()
end


emu.addMemoryCallback(compareAndLogOutput,
					  emu.callbackType.exec,
					  0x0071,
					  0x0071,
					  4,
					  emu.memType.gsuWorkRam)