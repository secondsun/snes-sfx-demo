	
--create lookup table for octal to binary
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

literalTable = 0x095C
lengthTable = 0x09DE
positionTable = 0x0A60
TestStop = 0x004e

function checkTables(address, value)
	emu.breakExecution()
end

emu.addMemoryCallback(checkTables,
					  emu.callbackType.exec,
					  TestStop,
					  TestStop,
					  4,
					  emu.memType.gsuWorkRam)

