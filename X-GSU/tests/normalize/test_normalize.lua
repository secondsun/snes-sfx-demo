--emu.log(string.format("%x", emu.readWord(0x59b,emu.memType.gsuWorkRam,false)))
--emu.log("input")
--emu.log(emu.getLabelAddress("input"))
--input = {0x1833, 0x48e6,0x30cd, 0xFF77,0x0000,0x0044}
--expected = {0x0044, 0x00cd, 0x0089,0xff1b,0x0,0x0072}
expected = {0xff1b,0x0,0x0072}
index = 1
output = 0x0
fail = 0



function compareAndLogOutput(address, value)
	--local read = emu.readWord(0x36A + 2*(index -1),emu.memType.gsuWorkRam,false)

	emu.log("Checking")
	while (index <= 3)
	do 
		local read = emu.readWord(0x3BC + 2*(index -1),emu.memType.gsuWorkRam,false)
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
					  0x0051,
					  0x0051,
					  4,
					  emu.memType.gsuWorkRam)