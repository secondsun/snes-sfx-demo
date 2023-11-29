
UNCOMPRESSED = 0x538
COMPRESSED = UNCOMPRESSED  + 4
PACK_CHUNKS = UNCOMPRESSED  + 8

function compareAndLogOutput(address, value)
	emu.log("compare")
	local uncompressedHi = emu.readWord (UNCOMPRESSED,emu.memType.gsuWorkRam,false)
	emu.log(uncompressedHi )
	local uncompressedLow = emu.readWord(UNCOMPRESSED + 2,emu.memType.gsuWorkRam,false)
	emu.log(uncompressedLow)
	local compressedHi = emu.readWord(COMPRESSED,emu.memType.gsuWorkRam,false)
	local compressedLow = emu.readWord(COMPRESSED + 2,emu.memType.gsuWorkRam,false)

	local packChunks = emu.readWord(PACK_CHUNKS,emu.memType.gsuWorkRam,false)
	
	if compressedHi ~= 0x0 then
		emu.log(string.format("Error compressedHi was %x expected %x", compressedHi,0x0))
	end
	if compressedLow ~= 0x7b then
		emu.log(string.format("Error compressedLow was %x expected %x", compressedLow,0x7b))
	end
	
	if uncompressedHi ~= 0x00 then
		emu.log(string.format("Error uncompressedHi was %x expected %x", uncompressedHi,0x0))
	end
	
	if uncompressedLow ~= 0x156 then
		emu.log(string.format("Error cunompressedLow was %x expected %x", uncompressedLow,0x156 ))
	end
	
	if packChunks ~= 0x1 then
		emu.log(string.format("Error packChunks was %x expected %x", packChunks,0x1))
	end
end

emu.addMemoryCallback(compareAndLogOutput,
					  emu.callbackType.exec,
					  0x0023,
					  0x0023,
					  4,
					  emu.memType.gsuWorkRam)