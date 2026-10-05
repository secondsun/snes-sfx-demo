test_setup = 0x0042
test_stop  = 0x0098
POLYGON_LIST = 0x0B20
LOOKAT_MATRIX = 0x096A

local verticies = {
	{0xc000, 0xc000, 0xc000},
	{0xc000, 0x4000, 0xc000},
	{0x4000, 0x4000, 0xc000},
	{0x4000, 0xc000, 0xc000},
	{0xc000, 0xc000, 0x4000},
	{0xc000, 0x4000, 0x4000},
	{0x4000, 0x4000, 0x4000},
	{0x4000, 0xc000, 0x4000}
}

local faces = {
	{1,2,3}, {3,8,4},
	{1,5,6}, {1,6,2},
	{7,3,2}, {7,2,6},
	{4,8,5}, {4,5,1},
	{8,7,6}, {8,6,5},
	{3,4,1}, {3,1,2}
}

function to_signed16(val)
	if val >= 0x8000 then return val - 0x10000 else return val end
end

function diff(a, b)
	return math.abs(to_signed16(a) - to_signed16(b))
end

-- Eye is at (0, 0, 20.0 = 0x1400), lookAt (0, 0, 0), up (0, 1.0, 0)
-- View matrix transforms: x' = x, y' = y, z' = z - 20.0 (z - 0x1400)
local eye_z_offset = 0x1400

function onTestSetup(address, value)
	print("Starting vector3_transform test suite (36 vertices)...")
	for idx = 1, 12 do
		for v = 1, 3 do
			local vert_idx = faces[idx][v]
			local coords = verticies[vert_idx]
			local base = POLYGON_LIST + (idx - 1) * 18 + (v - 1) * 6
			emu.writeWord(base + 0, coords[1], emu.memType.gsuWorkRam)
			emu.writeWord(base + 2, coords[2], emu.memType.gsuWorkRam)
			emu.writeWord(base + 4, coords[3], emu.memType.gsuWorkRam)
		end
	end
end

function onTestStop(address, value)
	local fail_count = 0
	local vert_count = 0

	for idx = 1, 12 do
		for v = 1, 3 do
			vert_count = vert_count + 1
			local vert_idx = faces[idx][v]
			local coords = verticies[vert_idx]
			local base = POLYGON_LIST + (idx - 1) * 18 + (v - 1) * 6

			local rx = emu.readWord(base + 0, emu.memType.gsuWorkRam, false)
			local ry = emu.readWord(base + 2, emu.memType.gsuWorkRam, false)
			local rz = emu.readWord(base + 4, emu.memType.gsuWorkRam, false)

			local exp_x = coords[1]
			local exp_y = coords[2]
			-- z' = z - 0x1400
			local exp_z = (to_signed16(coords[3]) - eye_z_offset) & 0xFFFF

			local dx = diff(rx, exp_x)
			local dy = diff(ry, exp_y)
			local dz = diff(rz, exp_z)

			if dx <= 150 and dy <= 150 and dz <= 150 then
				-- Passed
			else
				print(string.format("  [Face %d, v%d] FAILED: got (0x%04X, 0x%04X, 0x%04X), exp (0x%04X, 0x%04X, 0x%04X) [diff: %d, %d, %d]",
					idx, v, rx, ry, rz, exp_x, exp_y, exp_z, dx, dy, dz))
				fail_count = fail_count + 1
			end
		end
	end

	if fail_count == 0 then
		print("TEST PASSED: All 36 vertices correctly transformed by LookAt view matrix.")
		emu.stop(0)
	else
		print(string.format("TEST FAILED: %d/36 vertices failed.", fail_count))
		emu.stop(1)
	end
end

emu.addMemoryCallback(onTestSetup,
					  emu.callbackType.exec,
					  test_setup,
					  test_setup,
					  4,
					  emu.memType.gsuWorkRam)

emu.addMemoryCallback(onTestStop,
					  emu.callbackType.exec,
					  test_stop,
					  test_stop,
					  4,
					  emu.memType.gsuWorkRam)
