--emu.log(string.format("%x", emu.readWord(0x59b,emu.memType.gsuWorkRam,false)))
--emu.log("input")
--emu.log(emu.getLabelAddress("input"))

expected = {0xff4c,0x0,0xb5,0x14,0x16,0xfd,0x16,0xfbbd,0xff4d,0x20,0xff4d,0xd1da,0x0,0x0,0x0,0x100}
index = 1
output = 0x0
fail = 0



function compareAndLogOutput(address, value)
	--local read = emu.readWord(0x36A + 2*(index -1),emu.memType.gsuWorkRam,false)

	emu.log("Checking")
	while (index <= 16)
	do 
		local read = emu.readWord(0x772 + 2*(index -1),emu.memType.gsuWorkRam,false)
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