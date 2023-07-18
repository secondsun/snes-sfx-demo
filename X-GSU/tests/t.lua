emu.log(tostring(emu.getLabelAddress("INPUT")['address']))
emu.log(emu.readWord(emu.getLabelAddress("INPUT")['address'], emu.memType.gsuWorkRam,false))
emu.log(emu.readWord(emu.getLabelAddress("OUTPUT")['address'], emu.memType.gsuWorkRam,false))


emu.log(emu.readWord(0x05B4, emu.memType.gsuWorkRam,false))
emu.log(emu.readWord(0x5b6, emu.memType.gsuWorkRam,false))
