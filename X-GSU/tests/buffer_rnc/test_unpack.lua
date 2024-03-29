﻿--create lookup table for octal to binary
oct2bin = {
    ['0'] = '000',
    ['1'] = '001',
    ['2'] = '010',
    ['3'] = '011',
    ['4'] = '100',
    ['5'] = '101',
    ['6'] = '110',
    ['7'] = '111'
}
function getOct2bin(a) return oct2bin[a] end
function convertBin(n)
    local s = string.format('%o', n)
    s = s:gsub('.', getOct2bin)
    return s
end

UNCOMPRESSED = 0x622
COMPRESSED = UNCOMPRESSED  + 4
PACK_CHUNKS = UNCOMPRESSED  + 8

function checkHeader(address, value)
	emu.breakExecution()
	emu.log("compare")
	local uncompressedHi = emu.readWord(UNCOMPRESSED,emu.memType.gsuWorkRam,false)
	emu.log(string.format("0x%x\n",uncompressedHi ))
	local uncompressedLow = emu.readWord(UNCOMPRESSED + 2,emu.memType.gsuWorkRam,false)
	emu.log(string.format("0x%x\n",uncompressedLow ))
	local compressedHi = emu.readWord(COMPRESSED,emu.memType.gsuWorkRam,false)
	local compressedLow = emu.readWord(COMPRESSED + 2,emu.memType.gsuWorkRam,false)
	emu.log(string.format("0x%x\n",compressedHi ))
	emu.log(string.format("0x%x\n",compressedLow ))
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
		emu.log(string.format("Error unompressedLow was %x expected %x", uncompressedLow,0x156 ))
	end
	
	if packChunks ~= 0x1 then
		emu.log(string.format("Error packChunks was %x expected %x", packChunks,0x1))
	end
	
end


expected = {0,1,25,0,0,3,2,0,4,2,0,24,0,0,48,2,0,64,4,0,18,3,0,1,0,0,0,0,0,12,4,0,0,0,0,61,5,1,123,0,1,10,2,1,21,3,0,16,1,0,87,6,1,82,5,1,88,5,0,3,2,0,115,0,1,45,6,1,1,1,0,51,7,1,6,7,1,64,0,1,90,2,1,107,6,0,112,2,1,12,1,1,1,1,1,55}
input = {3,1,7,3,1,7,3,1,7,3,1,7,3,1,7,3,1,7,3,1,7,3,1,7,3,1,7,3,1,7,3,1,7,3,1,7,3,1,7,3,1,7,3,1,7,3,1,7,3,1,7,3,1,7,3,1,7,3,1,7,3,1,7,3,1,7,3,1,7,3,1,7,3,1,7,3,1,7,3,1,7,3,1,7,3,1,7,3,1,7,3,1,7,3,1,7}

OUTPUT = 0x870
INPUT = 0x86E
WORD = 0x65E + 12
index = 1

function setupBufferRead(ignore, ignore2) 
	emu.breakExecution()
	emu.log("setup buffer read")
	emu.writeWord(INPUT, input[index], emu.memType.gsuWorkRam)
	emu.resume()
end

function logWord(ignore, ignore2) 
	emu.breakExecution()
	word = emu.readWord(WORD, emu.memType.gsuWorkRam)
	emu.log(string.format("word is (%x, %o, %s)",word,word, convertBin(word)))
	--emu.resume()
end

function checkBufferRead(ignore, ignore2) 
	emu.breakExecution()
	emu.log("check buffer read")
	
	data = emu.readWord(OUTPUT, emu.memType.gsuWorkRam)
	emu.log(index)
	emu.log(expected[index])
	if data ~= expected[index] then
		emu.log(string.format("Error byte readbuffer(%d) was %x expected %x", input[index], data, expected[index]))
	end

	index = index + 1
	--emu.resume()
end


emu.addMemoryCallback(checkBufferRead,
					  emu.callbackType.exec,
					  0x005A,
					  0x005A,
					  4,
					  emu.memType.gsuWorkRam)

emu.addMemoryCallback(setupBufferRead,
					  emu.callbackType.exec,
					  0x0040,
					  0x0040,
					  4,
					  emu.memType.gsuWorkRam)					  

emu.addMemoryCallback(checkHeader,
					  emu.callbackType.exec,
					  0x001F,
					  0x001F,
					  4,
					  emu.memType.gsuWorkRam)

					  
emu.addMemoryCallback(logWord,
	emu.callbackType.exec,
	0x05E1,
	0x05E1,
	4,
	emu.memType.gsuWorkRam)


emu.addMemoryCallback(logWord,
	emu.callbackType.exec,
	0x059C,
	0x059C,
	4,
	emu.memType.gsuWorkRam)