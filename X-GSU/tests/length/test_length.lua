﻿--emu.log(string.format("%x", emu.readWord(0x59b,emu.memType.gsuWorkRam,false)))
--emu.log("input")
--emu.log(emu.getLabelAddress("input"))

-- Vectors
local input = {
	--{0xbeb3, 0x2f20, 0x55e6},    -- Vector v13
	{0x0014, 0x0000, 0x0000},   -- Vector v1
	{0x0000, 0x0100, 0x0000},   -- Vector v2
	{0x0000, 0x0000, 0x0100},   -- Vector v3
	{0xfe00, 0x0300, 0x0500},   -- Vector v4
	{0x0400, 0x0100, 0x0300},   -- Vector v5
	{0x0200, 0x0200, 0x0200},   -- Vector v6
	{0x0100, 0x0200, 0x0300},   -- Vector v7
	{0x0300, 0x0000, 0x0400},   -- Vector v8
	{0x0100, 0x0100, 0x0100},   -- Vector v9
	{0x0000, 0x0300, 0x0000},   -- Vector v10
	{0x0100, 0x0400, 0x0200},   -- Vector v11
	{0x0400, 0x0400, 0x0400}   -- Vector v12
	
  }
  
  -- Lengths
  local expected = {
    --0x75bd,     -- Length of v13
	0x0014,    -- Length of v1
	0x0100,    -- Length of v2
	0x0100,    -- Length of v3
	0x062a,    -- Length of v4
	0x0519,    -- Length of v5
	0x0376,    -- Length of v6
	0x03bd,    -- Length of v7
	0x0500,    -- Length of v8
	0x01bb,    -- Length of v9
	0x0300,    -- Length of v10
	0x0495,    -- Length of v11
	0x06ed    -- Length of v12
	
  }
index = 1
output = 0x0
fail = 0

inputAddress = 0x73C
outputAddress = 0x742

emu.writeWord(inputAddress + 0, input[index][1], emu.memType.gsuWorkRam)
emu.writeWord(inputAddress + 2, input[index][2], emu.memType.gsuWorkRam)
emu.writeWord(inputAddress + 4, input[index][3], emu.memType.gsuWorkRam)

function compareAndLogOutput(address, value)
	
	emu.breakExecution()
	emu.log("Checking")
	
	local read = emu.readWord(outputAddress,emu.memType.gsuWorkRam,false)
	if read ~= expected[index] then
		fail = 1
		emu.log(expected[index])
		emu.log(index)

		emu.log(string.format("Error lookat(%x) was %x expected %x", index,read,expected[index]))
	end
	index=index+1
	if index < 13 then 
		emu.writeWord(inputAddress + 0, input[index][1], emu.memType.gsuWorkRam)
		emu.writeWord(inputAddress + 2, input[index][2], emu.memType.gsuWorkRam)	
		emu.writeWord(inputAddress + 4, input[index][3], emu.memType.gsuWorkRam)
	end 
	if index ~= 13 then 
	 emu.resume()
	end
end


emu.addMemoryCallback(compareAndLogOutput,
					  emu.callbackType.exec,
					  0x00024,
					  0x00024,
					  4,
					  emu.memType.gsuWorkRam)