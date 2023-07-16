﻿--emu.log(string.format("%x", emu.readWord(0x59b,emu.memType.gsuWorkRam,false)))
--emu.log("input")
--emu.log(emu.getLabelAddress("input"))
input = {0x0, 0x1, 0x2, 0x3, 0x4, 0x5, 0x6, 0x7, 0x8, 0x9, 0xa, 0xb, 0xc, 0xd, 0xe, 0xf, 0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17, 0x18, 0x19, 0x1a, 0x1b, 0x1c, 0x1d, 0x1e, 0x1f, 0x20, 0x21, 0x22, 0x23, 0x24, 0x25, 0x26, 0x27, 0x28, 0x29, 0x2a, 0x2b, 0x2c, 0x2d, 0x2e, 0x2f, 0x30, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39, 0x3a, 0x3b, 0x3c, 0x3d, 0x3e, 0x3f, 0x40, 0x41, 0x42, 0x43, 0x44, 0x45, 0x46, 0x47, 0x48, 0x49, 0x4a, 0x4b, 0x4c, 0x4d, 0x4e, 0x4f, 0x50, 0x51, 0x52, 0x53, 0x54, 0x55, 0x56, 0x57, 0x58, 0x59, 0x5a, 0x5b, 0x5c, 0x5d, 0x5e, 0x5f, 0x60, 0x61, 0x62, 0x63, 0x64, 0x65, 0x66, 0x67, 0x68, 0x69, 0x6a, 0x6b, 0x6c, 0x6d, 0x6e, 0x6f, 0x70, 0x71, 0x72, 0x73, 0x74, 0x75, 0x76, 0x77, 0x78, 0x79, 0x7a, 0x7b, 0x7c, 0x7d, 0x7e, 0x7f, 0x80, 0x81, 0x82, 0x83, 0x84, 0x85, 0x86, 0x87, 0x88, 0x89, 0x8a, 0x8b, 0x8c, 0x8d, 0x8e, 0x8f, 0x90, 0x91, 0x92, 0x93, 0x94, 0x95, 0x96, 0x97, 0x98, 0x99, 0x9a, 0x9b, 0x9c, 0x9d, 0x9e, 0x9f, 0xa0, 0xa1, 0xa2, 0xa3, 0xa4, 0xa5, 0xa6, 0xa7, 0xa8, 0xa9, 0xaa, 0xab, 0xac, 0xad, 0xae, 0xaf, 0xb0, 0xb1, 0xb2, 0xb3, 0xb4, 0xb5, 0xb6, 0xb7, 0xb8, 0xb9, 0xba, 0xbb, 0xbc, 0xbd, 0xbe, 0xbf, 0xc0, 0xc1, 0xc2, 0xc3, 0xc4, 0xc5, 0xc6, 0xc7, 0xc8, 0xc9, 0xca, 0xcb, 0xcc, 0xcd, 0xce, 0xcf, 0xd0, 0xd1, 0xd2, 0xd3, 0xd4, 0xd5, 0xd6, 0xd7, 0xd8, 0xd9, 0xda, 0xdb, 0xdc, 0xdd, 0xde, 0xdf, 0xe0, 0xe1, 0xe2, 0xe3, 0xe4, 0xe5, 0xe6, 0xe7, 0xe8, 0xe9, 0xea, 0xeb, 0xec, 0xed, 0xee, 0xef, 0xf0, 0xf1, 0xf2, 0xf3, 0xf4, 0xf5, 0xf6, 0xf7, 0xf8, 0xf9, 0xfa, 0xfb, 0xfc, 0xfd, 0xfe, 0xff, 0x400, 0x401, 0x402, 0x403, 0x404, 0x405, 0x406, 0x407, 0x408, 0x409, 0x40a, 0x40b, 0x40c, 0x40d, 0x40e, 0x40f, 0x410, 0x411, 0x412, 0x413, 0x414, 0x415, 0x416, 0x417, 0x418, 0x419, 0x41a, 0x41b, 0x41c, 0x41d, 0x41e, 0x41f, 0x420, 0x421, 0x422, 0x423, 0x424, 0x425, 0x426, 0x427, 0x428, 0x429, 0x42a, 0x42b, 0x42c, 0x42d, 0x42e, 0x42f, 0x430, 0x431, 0x432, 0x433, 0x434, 0x435, 0x436, 0x437, 0x438, 0x439, 0x43a, 0x43b, 0x43c, 0x43d, 0x43e, 0x43f, 0x440, 0x441, 0x442, 0x443, 0x444, 0x445, 0x446, 0x447, 0x448, 0x449, 0x44a, 0x44b, 0x44c, 0x44d, 0x44e, 0x44f, 0x450, 0x451, 0x452, 0x453, 0x454, 0x455, 0x456, 0x457, 0x458, 0x459, 0x45a, 0x45b, 0x45c, 0x45d, 0x45e, 0x45f, 0x460, 0x461, 0x462, 0x463, 0x464, 0x465, 0x466, 0x467, 0x468, 0x469, 0x46a, 0x46b, 0x46c, 0x46d, 0x46e, 0x46f, 0x470, 0x471, 0x472, 0x473, 0x474, 0x475, 0x476, 0x477, 0x478, 0x479, 0x47a, 0x47b, 0x47c, 0x47d, 0x47e, 0x47f, 0x480, 0x481, 0x482, 0x483, 0x484, 0x485, 0x486, 0x487, 0x488, 0x489, 0x48a, 0x48b, 0x48c, 0x48d, 0x48e, 0x48f, 0x490, 0x491, 0x492, 0x493, 0x494, 0x495, 0x496, 0x497, 0x498, 0x499, 0x49a, 0x49b, 0x49c, 0x49d, 0x49e, 0x49f, 0x4a0, 0x4a1, 0x4a2, 0x4a3, 0x4a4, 0x4a5, 0x4a6, 0x4a7, 0x4a8, 0x4a9, 0x4aa, 0x4ab, 0x4ac, 0x4ad, 0x4ae, 0x4af, 0x4b0, 0x4b1, 0x4b2, 0x4b3, 0x4b4, 0x4b5, 0x4b6, 0x4b7, 0x4b8, 0x4b9, 0x4ba, 0x4bb, 0x4bc, 0x4bd, 0x4be, 0x4bf, 0x4c0, 0x4c1, 0x4c2, 0x4c3, 0x4c4, 0x4c5, 0x4c6, 0x4c7, 0x4c8, 0x4c9, 0x4ca, 0x4cb, 0x4cc, 0x4cd, 0x4ce, 0x4cf, 0x4d0, 0x4d1, 0x4d2, 0x4d3, 0x4d4, 0x4d5, 0x4d6, 0x4d7, 0x4d8, 0x4d9, 0x4da, 0x4db, 0x4dc, 0x4dd, 0x4de, 0x4df, 0x4e0, 0x4e1, 0x4e2, 0x4e3, 0x4e4, 0x4e5, 0x4e6, 0x4e7, 0x4e8, 0x4e9, 0x4ea, 0x4eb, 0x4ec, 0x4ed, 0x4ee, 0x4ef, 0x4f0, 0x4f1, 0x4f2, 0x4f3, 0x4f4, 0x4f5, 0x4f6, 0x4f7, 0x4f8, 0x4f9, 0x4fa, 0x4fb, 0x4fc, 0x4fd, 0x4fe, 0x4ff, 0x1000, 0x1001, 0x1002, 0x1003, 0x1004, 0x1005, 0x1006, 0x1007, 0x1008, 0x1009, 0x100a, 0x100b, 0x100c, 0x100d, 0x100e, 0x100f, 0x1010, 0x1011, 0x1012, 0x1013, 0x1014, 0x1015, 0x1016, 0x1017, 0x1018, 0x1019, 0x101a, 0x101b, 0x101c, 0x101d, 0x101e, 0x101f, 0x1020, 0x1021, 0x1022, 0x1023, 0x1024, 0x1025, 0x1026, 0x1027, 0x1028, 0x1029, 0x102a, 0x102b, 0x102c, 0x102d, 0x102e, 0x102f, 0x1030, 0x1031, 0x1032, 0x1033, 0x1034, 0x1035, 0x1036, 0x1037, 0x1038, 0x1039, 0x103a, 0x103b, 0x103c, 0x103d, 0x103e, 0x103f, 0x1040, 0x1041, 0x1042, 0x1043, 0x1044, 0x1045, 0x1046, 0x1047, 0x1048, 0x1049, 0x104a, 0x104b, 0x104c, 0x104d, 0x104e, 0x104f, 0x1050, 0x1051, 0x1052, 0x1053, 0x1054, 0x1055, 0x1056, 0x1057, 0x1058, 0x1059, 0x105a, 0x105b, 0x105c, 0x105d, 0x105e, 0x105f, 0x1060, 0x1061, 0x1062, 0x1063, 0x1064, 0x1065, 0x1066, 0x1067, 0x1068, 0x1069, 0x106a, 0x106b, 0x106c, 0x106d, 0x106e, 0x106f, 0x1070, 0x1071, 0x1072, 0x1073, 0x1074, 0x1075, 0x1076, 0x1077, 0x1078, 0x1079, 0x107a, 0x107b, 0x107c, 0x107d, 0x107e, 0x107f, 0x1080, 0x1081, 0x1082, 0x1083, 0x1084, 0x1085, 0x1086, 0x1087, 0x1088, 0x1089, 0x108a, 0x108b, 0x108c, 0x108d, 0x108e, 0x108f, 0x1090, 0x1091, 0x1092, 0x1093, 0x1094, 0x1095, 0x1096, 0x1097, 0x1098, 0x1099, 0x109a, 0x109b, 0x109c, 0x109d, 0x109e, 0x109f, 0x10a0, 0x10a1, 0x10a2, 0x10a3, 0x10a4, 0x10a5, 0x10a6, 0x10a7, 0x10a8, 0x10a9, 0x10aa, 0x10ab, 0x10ac, 0x10ad, 0x10ae, 0x10af, 0x10b0, 0x10b1, 0x10b2, 0x10b3, 0x10b4, 0x10b5, 0x10b6, 0x10b7, 0x10b8, 0x10b9, 0x10ba, 0x10bb, 0x10bc, 0x10bd, 0x10be, 0x10bf, 0x10c0, 0x10c1, 0x10c2, 0x10c3, 0x10c4, 0x10c5, 0x10c6, 0x10c7, 0x10c8, 0x10c9, 0x10ca, 0x10cb, 0x10cc, 0x10cd, 0x10ce, 0x10cf, 0x10d0, 0x10d1, 0x10d2, 0x10d3, 0x10d4, 0x10d5, 0x10d6, 0x10d7, 0x10d8, 0x10d9, 0x10da, 0x10db, 0x10dc, 0x10dd, 0x10de, 0x10df, 0x10e0, 0x10e1, 0x10e2, 0x10e3, 0x10e4, 0x10e5, 0x10e6, 0x10e7, 0x10e8, 0x10e9, 0x10ea, 0x10eb, 0x10ec, 0x10ed, 0x10ee, 0x10ef, 0x10f0, 0x10f1, 0x10f2, 0x10f3, 0x10f4, 0x10f5, 0x10f6, 0x10f7, 0x10f8, 0x10f9, 0x10fa, 0x10fb, 0x10fc, 0x10fd, 0x10fe, 0x10ff, 0x5c00, 0x5c01, 0x5c02, 0x5c03, 0x5c04, 0x5c05, 0x5c06, 0x5c07, 0x5c08, 0x5c09, 0x5c0a, 0x5c0b, 0x5c0c, 0x5c0d, 0x5c0e, 0x5c0f, 0x5c10, 0x5c11, 0x5c12, 0x5c13, 0x5c14, 0x5c15, 0x5c16, 0x5c17, 0x5c18, 0x5c19, 0x5c1a, 0x5c1b, 0x5c1c, 0x5c1d, 0x5c1e, 0x5c1f, 0x5c20, 0x5c21, 0x5c22, 0x5c23, 0x5c24, 0x5c25, 0x5c26, 0x5c27, 0x5c28, 0x5c29, 0x5c2a, 0x5c2b, 0x5c2c, 0x5c2d, 0x5c2e, 0x5c2f, 0x5c30, 0x5c31, 0x5c32, 0x5c33, 0x5c34, 0x5c35, 0x5c36, 0x5c37, 0x5c38, 0x5c39, 0x5c3a, 0x5c3b, 0x5c3c, 0x5c3d, 0x5c3e, 0x5c3f, 0x5c40, 0x5c41, 0x5c42, 0x5c43, 0x5c44, 0x5c45, 0x5c46, 0x5c47, 0x5c48, 0x5c49, 0x5c4a, 0x5c4b, 0x5c4c, 0x5c4d, 0x5c4e, 0x5c4f, 0x5c50, 0x5c51, 0x5c52, 0x5c53, 0x5c54, 0x5c55, 0x5c56, 0x5c57, 0x5c58, 0x5c59, 0x5c5a, 0x5c5b, 0x5c5c, 0x5c5d, 0x5c5e, 0x5c5f, 0x5c60, 0x5c61, 0x5c62, 0x5c63, 0x5c64, 0x5c65, 0x5c66, 0x5c67, 0x5c68, 0x5c69, 0x5c6a, 0x5c6b, 0x5c6c, 0x5c6d, 0x5c6e, 0x5c6f, 0x5c70, 0x5c71, 0x5c72, 0x5c73, 0x5c74, 0x5c75, 0x5c76, 0x5c77, 0x5c78, 0x5c79, 0x5c7a, 0x5c7b, 0x5c7c, 0x5c7d, 0x5c7e, 0x5c7f, 0x5c80, 0x5c81, 0x5c82, 0x5c83, 0x5c84, 0x5c85, 0x5c86, 0x5c87, 0x5c88, 0x5c89, 0x5c8a, 0x5c8b, 0x5c8c, 0x5c8d, 0x5c8e, 0x5c8f, 0x5c90, 0x5c91, 0x5c92, 0x5c93, 0x5c94, 0x5c95, 0x5c96, 0x5c97, 0x5c98, 0x5c99, 0x5c9a, 0x5c9b, 0x5c9c, 0x5c9d, 0x5c9e, 0x5c9f, 0x5ca0, 0x5ca1, 0x5ca2, 0x5ca3, 0x5ca4, 0x5ca5, 0x5ca6, 0x5ca7, 0x5ca8, 0x5ca9, 0x5caa, 0x5cab, 0x5cac, 0x5cad, 0x5cae, 0x5caf, 0x5cb0, 0x5cb1, 0x5cb2, 0x5cb3, 0x5cb4, 0x5cb5, 0x5cb6, 0x5cb7, 0x5cb8, 0x5cb9, 0x5cba, 0x5cbb, 0x5cbc, 0x5cbd, 0x5cbe, 0x5cbf, 0x5cc0, 0x5cc1, 0x5cc2, 0x5cc3, 0x5cc4, 0x5cc5, 0x5cc6, 0x5cc7, 0x5cc8, 0x5cc9, 0x5cca, 0x5ccb, 0x5ccc, 0x5ccd, 0x5cce, 0x5ccf, 0x5cd0, 0x5cd1, 0x5cd2, 0x5cd3, 0x5cd4, 0x5cd5, 0x5cd6, 0x5cd7, 0x5cd8, 0x5cd9, 0x5cda, 0x5cdb, 0x5cdc, 0x5cdd, 0x5cde, 0x5cdf, 0x5ce0, 0x5ce1, 0x5ce2, 0x5ce3, 0x5ce4, 0x5ce5, 0x5ce6, 0x5ce7, 0x5ce8, 0x5ce9, 0x5cea, 0x5ceb, 0x5cec, 0x5ced, 0x5cee, 0x5cef, 0x5cf0, 0x5cf1, 0x5cf2, 0x5cf3, 0x5cf4, 0x5cf5, 0x5cf6, 0x5cf7, 0x5cf8, 0x5cf9, 0x5cfa, 0x5cfb, 0x5cfc, 0x5cfd, 0x5cfe, 0x5cff}
expected = {0xff1b, 0x0, 0x71, 0x0 , 0xffa5, 0x99, 0xff49, 0x0 , 0xffbc, 0xff33, 0xff77, 0x0 , 0x0, 0x0, 0x0, 0x100}
index = 1
output = 0x0
fail = 0



function compareAndLogOutput(address, value)
	--local read = emu.readWord(0x36A + 2*(index -1),emu.memType.gsuWorkRam,false)

	emu.log("Checking")
	while (index <= 16)
	do 
		local read = emu.readWord(0x36A + 2*(index -1),emu.memType.gsuWorkRam,false)
		if read ~= expected[index] then
			fail = 1
			emu.log(input[index])
			emu.log(read)
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