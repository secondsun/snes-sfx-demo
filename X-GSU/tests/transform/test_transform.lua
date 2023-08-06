--emu.log(string.format("%x", emu.readWord(0x59b,emu.memType.gsuWorkRam,false)))
--emu.log("input")
--emu.log(emu.getLabelAddress("input"))

expected = {0xfc00,0x0,0xfbfc}
index = 1
output = 0x0
fail = 0

testsetup = 0x0042
teststop = 0x0084
POLYGON_LIST = 0x0792
function test_setup(address, value)
  verticies = {
		{0xFF00,0xFF00,0xFF00},
		{0xFF00,0x0100,0xFF00},
		{0x0100,0x0100,0xFF00},
		{0x0100,0xFF00,0xFF00},
		{0xFF00,0xFF00,0x0100},
		{0xFF00,0x0100,0x0100},
		{0x0100,0x0100,0x0100},
		{0x0100,0xFF00,0x0100}
  }
  faces = {
	{3,7,8},
	{3,8,4},

	{1,5,6},
	{1,6,2},

	{7,3,2},
	{7,2,6},

	{4,8,5},
	{4,5,1},
	
	{8,7,6},
	{8,6,5},

	{3,4,1},
	{3,1,2},
	}
	
	emu.breakExecution()
	emu.log("Loading")
	
	
	for index=1,12 do
		--V1
		emu.writeWord(POLYGON_LIST+16*(index-1),verticies[faces[index][1]][1],emu.memType.gsuWorkRam)
		emu.writeWord(POLYGON_LIST+16*(index-1)+2,verticies[faces[index][1]][2],emu.memType.gsuWorkRam)
		emu.writeWord(POLYGON_LIST+16*(index-1)+4,verticies[faces[index][1]][3],emu.memType.gsuWorkRam)
		--V2
		emu.writeWord(POLYGON_LIST+16*(index-1)+6,verticies[faces[index][2]][1],emu.memType.gsuWorkRam)
		emu.writeWord(POLYGON_LIST+16*(index-1)+8,verticies[faces[index][2]][2],emu.memType.gsuWorkRam)
		emu.writeWord(POLYGON_LIST+16*(index-1)+10,verticies[faces[index][2]][3],emu.memType.gsuWorkRam)
		--V3
		emu.writeWord(POLYGON_LIST+16*(index-1)+12,verticies[faces[index][3]][1],emu.memType.gsuWorkRam)
		emu.writeWord(POLYGON_LIST+16*(index-1)+14,verticies[faces[index][3]][2],emu.memType.gsuWorkRam)
		emu.writeWord(POLYGON_LIST+16*(index-1)+16,verticies[faces[index][3]][3],emu.memType.gsuWorkRam)
		
	end

	

end

function compareAndLogOutput(address, value)
	--local read = emu.readWord(0x36A + 2*(index -1),emu.memType.gsuWorkRam,false)

	emu.log("Checking")
	while (index <= 3)
	do 
		local read = emu.readWord(POLYGON_LIST + 2*(index -1),emu.memType.gsuWorkRam,false)
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



emu.addMemoryCallback(test_setup,
					  emu.callbackType.exec,
					  testsetup,
					  testsetup,
					  4,
					  emu.memType.gsuWorkRam)


emu.addMemoryCallback(compareAndLogOutput,
					  emu.callbackType.exec,
					  teststop,
					  teststop,
					  4,
					  emu.memType.gsuWorkRam)