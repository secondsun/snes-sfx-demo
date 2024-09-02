--emu.log(string.format("%x", emu.readWord(0x59b,emu.memType.gsuWorkRam,false)))
--emu.log("input")
--emu.log(emu.getLabelAddress("input"))
--input = {0x1833, 0x48e6,0x30cd, 0xFF77,0x0000,0x0044}
--expected = {0x0044, 0x00cd, 0x0089,0xff1b,0x0,0x0072}
input = {0x4000,0x4000,0x4000}
expected =  {0x0094, 0x0094, 0x0094}
CAMERA = 0x702
NORMAL_OUT = 0x6CE
index = 1
in_index = 1
output = 0x0
fail = 0



function compareAndLogOutput(address, value)
	--local read = emu.readWord(0x36A + 2*(index -1),emu.memType.gsuWorkRam,false)

	emu.log("Checking")
	while (index <= 3)
	do 
		local read = emu.readWord(NORMAL_OUT + 2*(index -1),emu.memType.gsuWorkRam,false)
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

function setupInput(address, value)
	--local read = emu.readWord(0x36A + 2*(index -1),emu.memType.gsuWorkRam,false)

	emu.log("Updating")
	while (in_index <= 3)
	do 
		emu.writeWord(CAMERA + 2*(in_index -1), input[in_index], emu.memType.gsuWorkRam)
		in_index=in_index+1
	end
	
end

emu.addMemoryCallback(setupInput,
					  emu.callbackType.exec,
					  0x0004,
					  0x0004,
					  4,
					  emu.memType.gsuWorkRam)

emu.addMemoryCallback(compareAndLogOutput,
					  emu.callbackType.exec,
					  0x0016,
					  0x0016,
					  4,
					  emu.memType.gsuWorkRam)