--emu.log(string.format("%x", emu.readWord(0x59b,emu.memType.gsuWorkRam,false)))
--emu.log("input")
--emu.log(emu.getLabelAddress("input"))

expected = {0xfc00,0x0,0xfbfc}
index = 1
output = 0x0
fail = 0

testcall = 0x004A
testsetup = 0x0042
teststop = 0x0087
POLYGON_LIST = 0x0794
lookat = 0x0574
camera_lookAt_XAXIS=0x047D

function test_setup(address, value)
  verticies = {
		{0xc000,0xc000,0xc000},
		{0xc000,0x4000,0xc000},
		{0x4000,0x4000,0xc000},
		{0x4000,0xc000,0xc000},
		{0xc000,0xc000,0x4000},
		{0xc000,0x4000,0x4000},
		{0x4000,0x4000,0x4000},
		{0x4000,0xc000,0x4000}
  }
  faces = {
	{1,2,3},
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
		emu.writeWord(POLYGON_LIST+18*(index-1),verticies[faces[index][1]][1],emu.memType.gsuWorkRam)
		emu.writeWord(POLYGON_LIST+18*(index-1)+2,verticies[faces[index][1]][2],emu.memType.gsuWorkRam)
		emu.writeWord(POLYGON_LIST+18*(index-1)+4,verticies[faces[index][1]][3],emu.memType.gsuWorkRam)
		--V2
		emu.writeWord(POLYGON_LIST+18*(index-1)+6,verticies[faces[index][2]][1],emu.memType.gsuWorkRam)
		emu.writeWord(POLYGON_LIST+18*(index-1)+8,verticies[faces[index][2]][2],emu.memType.gsuWorkRam)
		emu.writeWord(POLYGON_LIST+18*(index-1)+10,verticies[faces[index][2]][3],emu.memType.gsuWorkRam)
		--V3
		emu.writeWord(POLYGON_LIST+18*(index-1)+12,verticies[faces[index][3]][1],emu.memType.gsuWorkRam)
		emu.writeWord(POLYGON_LIST+18*(index-1)+14,verticies[faces[index][3]][2],emu.memType.gsuWorkRam)
		emu.writeWord(POLYGON_LIST+18*(index-1)+16,verticies[faces[index][3]][3],emu.memType.gsuWorkRam)
		
	end

	

end

function checkLookAt(address, value)
	--local read = emu.readWord(0x36A + 2*(index -1),emu.memType.gsuWorkRam,false)
	emu.breakExecution()
	emu.log("Checking lookAt")
	for matrixIndex=0,3
	do 
		local x = emu.readWord(lookat + 8*matrixIndex,emu.memType.gsuWorkRam,false)
		local y = emu.readWord(lookat + 2+ 8*matrixIndex,emu.memType.gsuWorkRam,false)
		local z = emu.readWord(lookat + 4+ 8*matrixIndex,emu.memType.gsuWorkRam,false)
		local w = emu.readWord(lookat + 6+ 8*matrixIndex,emu.memType.gsuWorkRam,false)
		emu.log(string.format("{%x,%x,%x,%x}\n", x,y,z,w))
	end
	
end

function compareAndLogOutput(address, value)
	--local read = emu.readWord(0x36A + 2*(index -1),emu.memType.gsuWorkRam,false)
	emu.breakExecution()
	emu.log("Checking Polygon")
	for vertexIndex=0,2
	do 
		local x = emu.readWord(POLYGON_LIST + 6*vertexIndex,emu.memType.gsuWorkRam,false)
		local y = emu.readWord(POLYGON_LIST + 2 + 6*vertexIndex,emu.memType.gsuWorkRam,false)
		local z = emu.readWord(POLYGON_LIST + 4 + 6*vertexIndex,emu.memType.gsuWorkRam,false)
		emu.log(string.format("{%x,%x,%x}\n", x,y,z))
	end
	
end

function break_(address, value)
	--local read = emu.readWord(0x36A + 2*(index -1),emu.memType.gsuWorkRam,false)
	emu.breakExecution()
	emu.log("Break X axis")
end

emu.addMemoryCallback(break_,
					  emu.callbackType.exec,
					  camera_lookAt_XAXIS,
					  camera_lookAt_XAXIS,
					  4,
					  emu.memType.gsuWorkRam)

emu.addMemoryCallback(checkLookAt,
					  emu.callbackType.exec,
					  testcall,
					  testcall,
					  4,
					  emu.memType.gsuWorkRam)


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