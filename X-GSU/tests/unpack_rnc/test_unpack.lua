
UNCOMPRESSED = 0x532
COMPRESSED = 0x534
PACK_CHUNKS = 0x538

function compareAndLogOutput(address, value)
	local uncompressedHi = emu.readWord (UNCOMPRESSED,emu.memType.gsuWorkRam,false)
	local uncompressedLow = emu.readWord(UNCOMPRESSED + 2,emu.memType.gsuWorkRam,false)

	local compressedHi = emu.readWord(COMPRESSED,emu.memType.gsuWorkRam,false)
	local compressedLow = emu.readWord(COMPRESSED + 2,emu.memType.gsuWorkRam,false)

	local packChunks = emu.readWord(PACK_CHUNKS,emu.memType.gsuWorkRam,false)
	
	if compressedHi ~= 0x5 then
		emu.log(string.format("Error compressedHi was %x expected %x", compressedHi,0x5))
	end
	if compressedLow ~= 0x3872 then
		emu.log(string.format("Error compressedLow was %x expected %x", compressedLow,0x3872))
	end
	
	if uncompressedHi ~= 0x0136 then
		emu.log(string.format("Error uncompressedHi was %x expected %x", compressedHi,0x5))
	end
	
	if uncompressedLow ~= 0x3e00 then
		emu.log(string.format("Error cunompressedLow was %x expected %x", compressedHi,0x5))
	end
	
	if packChunks ~= 0xbe then
		emu.log(string.format("Error packChunks was %x expected %x", packChunks,0xbe))
	end
end


emu.addMemoryCallback(compareAndLogOutput,
					  emu.callbackType.exec,
					  0x0030,
					  0x0030,
					  4,
					  emu.memType.gsuWorkRam)