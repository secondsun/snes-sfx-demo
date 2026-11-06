package dev.secondsun.superx.tools.packer.model

import dev.secondsun.superx.tools.packer.ui.TextureRenderer
import org.junit.jupiter.api.Assertions.*
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.io.TempDir
import java.io.File
import javax.imageio.ImageIO

class ModelTest {

    @Test
    fun testSnesColorBlackClamping() {
        val black = SnesColor.fromRgb888(0, 0, 0)
        assertEquals(1, black.r)
        assertEquals(0, black.g)
        assertEquals(0, black.b)
        assertEquals(0x0001, black.bgr555)

        val transparent = SnesColor.TRANSPARENT
        assertEquals(0, transparent.r)
        assertEquals(0, transparent.g)
        assertEquals(0, transparent.b)
        // bgr555 property clamps (0,0,0) to 1 if evaluated through bgr555
        assertEquals(1, transparent.bgr555)
    }

    @Test
    fun testPaletteBgr555Binary() {
        val palette = SnesPalette()
        val bytes = palette.toBgr555Binary()
        assertEquals(32, bytes.size)

        // Slot 0 is $0000
        assertEquals(0.toByte(), bytes[0])
        assertEquals(0.toByte(), bytes[1])

        // Slot 1 defaults to $0001 (little endian: low byte 0x01, high byte 0x00)
        assertEquals(0x01.toByte(), bytes[2])
        assertEquals(0x00.toByte(), bytes[3])
    }

    @Test
    fun testSourceTextureBoundsAndOverlap() {
        val pixels = ByteArray(16 * 16)
        val tex1 = SourceTexture("tex1", 16, 16, 0, 0, pixels)
        val tex2 = SourceTexture("tex2", 16, 16, 8, 8, pixels)
        val tex3 = SourceTexture("tex3", 16, 16, 16, 0, pixels)

        assertTrue(tex1.intersects(tex2))
        assertFalse(tex1.intersects(tex3))
    }

    @Test
    fun testTextureAtlasBinaryGeneration() {
        val pixels1 = ByteArray(16 * 16) { 1 } // slot 1
        val pixels2 = ByteArray(16 * 16) { 2 } // slot 2

        val tex1 = SourceTexture("tex1", 16, 16, 0, 0, pixels1)
        val tex2 = SourceTexture("tex2", 16, 16, 16, 0, pixels2)

        val atlas = TextureAtlas(32, 32, listOf(tex1, tex2))
        val bin = atlas.generateBinary()

        assertEquals(32 * 32, bin.size)
        // (0, 0) should be 1
        assertEquals(1.toByte(), bin[0])
        // (16, 0) should be 2
        assertEquals(2.toByte(), bin[16])
        // (0, 16) should be 0 (unoccupied)
        assertEquals(0.toByte(), bin[16 * 32])
    }

    @Test
    fun testAtlasAutoPack() {
        val pixels = ByteArray(16 * 16)
        val textures = (0..3).map { i ->
            SourceTexture("tex$i", 16, 16, 0, 0, pixels)
        }

        val atlas = TextureAtlas(32, 32, textures)
        val packed = atlas.autoPack(16)
        assertNotNull(packed)
        assertEquals(4, packed!!.textures.size)

        // All 4 textures should have distinct non-overlapping positions
        for (i in 0 until 4) {
            for (j in i + 1 until 4) {
                assertFalse(packed.textures[i].intersects(packed.textures[j]))
            }
        }
    }

    @Test
    fun testAtlasIndexGenerator() {
        val pixels = ByteArray(16 * 16)
        val tex = SourceTexture("hero", 16, 16, 0, 0, pixels)
        val atlas = TextureAtlas(64, 64, listOf(tex))

        val indexStr = AtlasIndexGenerator.generate(atlas, "game")
        assertTrue(indexStr.contains("ATLAS_WIDTH        = 64"))
        assertTrue(indexStr.contains("ATLAS_STRIDE_SHIFT = 6"))
        assertTrue(indexStr.contains("TEXTURE_ID_HERO = 0"))
        assertTrue(indexStr.contains("TEXTURE_HERO_OFFSET = 0"))
        assertTrue(indexStr.contains("TEXTURE_TABLE:"))
        assertTrue(indexStr.contains(".word .loword(textures_binary + TEXTURE_HERO_OFFSET), 15, 15, ATLAS_STRIDE_SHIFT ; 0: hero (16x16)"))
    }

    @Test
    fun testVirtualSlicesAndAliases() {
        val pixels = ByteArray(32 * 32)
        val stone = SourceTexture("stone", 32, 32, 0, 64, pixels)
        val slice = VirtualSlice("parapet", "stone", 0, 0, 32, 16)
        val alias = DescriptorAlias("water_deep", "stone")

        val atlas = TextureAtlas(
            width = 64,
            height = 128,
            textures = listOf(stone),
            slices = listOf(slice),
            aliases = listOf(alias),
            descriptorOrder = listOf("stone", "water_deep", "parapet")
        )

        val descriptors = atlas.resolvedDescriptors()
        assertEquals(3, descriptors.size)
        assertEquals("stone", descriptors[0].name)
        assertEquals("water_deep", descriptors[1].name)
        assertEquals("parapet", descriptors[2].name)

        assertEquals(0, descriptors[2].x)
        assertEquals(64, descriptors[2].y)
        assertEquals(32, descriptors[2].width)
        assertEquals(16, descriptors[2].height)
        assertEquals(4096, descriptors[2].romOffset) // (64 * 64 + 0)

        val indexStr = AtlasIndexGenerator.generate(atlas, "TEXTURES")
        assertTrue(indexStr.contains("TEXTURE_ID_STONE = 0"))
        assertTrue(indexStr.contains("TEXTURE_ID_WATER_DEEP = 1"))
        assertTrue(indexStr.contains("TEXTURE_ID_PARAPET = 2"))
        assertTrue(indexStr.contains(".word .loword(textures_binary + TEXTURE_PARAPET_OFFSET), 31, 15, ATLAS_STRIDE_SHIFT ; 2: parapet (32x16)"))
    }

    @Test
    fun testAsciiPixelParsingAndFormatting() {
        val asciiInput = """
            123456789ABCDEF.
            ................
            1...............
            ...............F
        """.trimIndent()

        // 16x4
        val pixels = ProjectService.asciiToPixels(asciiInput, 16, 4)
        assertEquals(16 * 4, pixels.size)
        assertEquals(1.toByte(), pixels[0])
        assertEquals(15.toByte(), pixels[14])
        assertEquals(0.toByte(), pixels[15])
        assertEquals(0.toByte(), pixels[16])
        assertEquals(1.toByte(), pixels[32])
        assertEquals(15.toByte(), pixels[63])

        val formattedAscii = ProjectService.pixelsToAscii(pixels, 16, 4)
        assertEquals(asciiInput, formattedAscii)
    }

    @Test
    fun testProjectServiceSaveAndLoad(@TempDir tempDir: File) {
        val projFile = File(tempDir, "test.sfxproj")
        val pixels = ByteArray(16 * 16) { 3 }
        val tex = SourceTexture("coin", 16, 16, 16, 16, pixels)
        val atlas = TextureAtlas(64, 64, listOf(tex))
        val palette = SnesPalette().withSlot(3, SnesColor(31, 31, 0), assigned = true)

        ProjectService.saveProject(projFile, "test", atlas, palette, 16)

        assertTrue(projFile.exists())
        assertTrue(File(tempDir, "test.bin").exists())
        assertTrue(File(tempDir, "test.pal").exists())
        assertFalse(File(tempDir, "test_graphics.bin").exists())
        assertFalse(File(tempDir, "test_palette.bin").exists())
        assertTrue(File(tempDir, "test.i").exists())
        assertTrue(File(tempDir, "test_atlas.png").exists())

        val (loadedAtlas, loadedPalette, gridSnap) = ProjectService.loadProject(projFile)
        assertEquals(64, loadedAtlas.width)
        assertEquals(64, loadedAtlas.height)
        assertEquals(16, gridSnap)
        assertEquals(1, loadedAtlas.textures.size)
        assertEquals("coin", loadedAtlas.textures[0].name)
        assertEquals(16, loadedAtlas.textures[0].x)
        assertEquals(16, loadedAtlas.textures[0].y)
        assertEquals(3, loadedAtlas.textures[0].getPixel(0, 0))
        assertTrue(loadedPalette.isAssigned(3))
        assertEquals(SnesColor(31, 31, 0), loadedPalette[3])
    }

    @Test
    fun testSourceTextureFloodFillContiguous() {
        val pixels = ByteArray(16 * 16) { 0 }
        val tex = SourceTexture("test", 16, 16, 0, 0, pixels)
        val filled = tex.floodFill(4, 4, 3)

        assertEquals(3, filled.getPixel(4, 4))
        for (y in 0 until 16) {
            for (x in 0 until 16) {
                assertEquals(3, filled.getPixel(x, y), "Pixel at ($x, $y) should be filled with 3")
            }
        }
    }

    @Test
    fun testSourceTextureFloodFillWithBoundaries() {
        val pixels = ByteArray(16 * 16) { 0 }
        // Create vertical barrier at x = 8
        for (y in 0 until 16) {
            pixels[y * 16 + 8] = 1
        }
        val tex = SourceTexture("test", 16, 16, 0, 0, pixels)
        val filled = tex.floodFill(2, 2, 5)

        for (y in 0 until 16) {
            for (x in 0 until 16) {
                when {
                    x < 8 -> assertEquals(5, filled.getPixel(x, y), "Left side should be filled with 5")
                    x == 8 -> assertEquals(1, filled.getPixel(x, y), "Barrier should remain 1")
                    else -> assertEquals(0, filled.getPixel(x, y), "Right side should remain 0")
                }
            }
        }
    }

    @Test
    fun testSourceTextureFloodFillBufferNoOp() {
        val pixels = ByteArray(16 * 16) { 2 }
        val before = pixels.copyOf()
        SourceTexture.floodFillBuffer(pixels, 16, 16, 0, 0, 2, 2)
        assertArrayEquals(before, pixels)
    }

    @Test
    fun testSourceTextureFloodFillTransparency() {
        val pixels = ByteArray(16 * 16) { 4 }
        val tex = SourceTexture("test", 16, 16, 0, 0, pixels)
        val filled = tex.floodFill(0, 0, 0)
        for (i in 0 until 16 * 16) {
            assertEquals(0, filled.indexedPixels[i].toInt() and 0x0F)
        }
    }

    @Test
    fun testProjectServiceExportAssets(@TempDir tempDir: File) {
        val pixels = ByteArray(16 * 16) { 5 }
        val tex = SourceTexture("gem", 16, 16, 0, 0, pixels)
        val atlas = TextureAtlas(32, 32, listOf(tex))
        val palette = SnesPalette().withSlot(5, SnesColor(0, 31, 31), assigned = true)

        val exported = ProjectService.exportAssets(
            destinationDir = tempDir,
            baseName = "LEVEL1",
            atlas = atlas,
            palette = palette
        )

        assertTrue(exported.graphicsBinFile.exists())
        assertEquals("LEVEL1.bin", exported.graphicsBinFile.name)
        assertEquals(32 * 32, exported.graphicsBinFile.length().toInt())
        assertArrayEquals(atlas.generateBinary(), exported.graphicsBinFile.readBytes())

        assertTrue(exported.paletteBinFile.exists())
        assertEquals("LEVEL1.pal", exported.paletteBinFile.name)
        assertEquals(32, exported.paletteBinFile.length().toInt())
        assertArrayEquals(palette.toBgr555Binary(), exported.paletteBinFile.readBytes())

        assertTrue(exported.indexFile.exists())
        assertEquals("LEVEL1.i", exported.indexFile.name)
        val indexText = exported.indexFile.readText()
        assertTrue(indexText.contains("TEXTURE_ID_GEM = 0"))
        assertTrue(indexText.contains("TEXTURE_TABLE:"))

        assertTrue(exported.pngFile.exists())
        assertEquals("LEVEL1_atlas.png", exported.pngFile.name)
        val img = ImageIO.read(exported.pngFile)
        assertNotNull(img)
        assertEquals(32, img.width)
        assertEquals(32, img.height)
    }

    @Test
    fun testTextureRendererWriteAtlasPng(@TempDir tempDir: File) {
        val pixels = ByteArray(16 * 16) { 2 }
        val tex = SourceTexture("box", 16, 16, 16, 16, pixels)
        val atlas = TextureAtlas(32, 32, listOf(tex))
        val palette = SnesPalette().withSlot(2, SnesColor(31, 0, 0), assigned = true)

        val pngFile = File(tempDir, "atlas.png")
        TextureRenderer.writeAtlasPng(atlas, palette, pngFile)

        assertTrue(pngFile.exists())
        val img = ImageIO.read(pngFile)
        assertNotNull(img)
        assertEquals(32, img.width)
        assertEquals(32, img.height)

        // Top-left (0,0) is unoccupied (slot 0) -> alpha must be 0 (transparent)
        val transparentRgb = img.getRGB(0, 0)
        assertEquals(0, (transparentRgb ushr 24) and 0xFF, "Unoccupied texel should be transparent")

        // Pixel at (16, 16) is slot 2 (red) -> alpha must be 255 (opaque)
        val texelRgb = img.getRGB(16, 16)
        assertEquals(255, (texelRgb ushr 24) and 0xFF, "Texture texel should be opaque")
    }

    @Test
    fun testPixelsAsciiTakesPrecedenceOverPixelsHex(@TempDir tempDir: File) {
        val projFile = File(tempDir, "precedence.sfxproj")
        val initialPixels = ByteArray(16 * 16) { 2 }
        val tex = SourceTexture("tile", 16, 16, 0, 0, initialPixels)
        val atlas = TextureAtlas(16, 16, listOf(tex))
        val palette = SnesPalette().withSlot(2, SnesColor(31, 0, 0), assigned = true)
            .withSlot(7, SnesColor(0, 31, 0), assigned = true)

        ProjectService.saveProject(projFile, "precedence", atlas, palette, 16)

        // Simulate editing pixelsAscii in .sfxproj while leaving stale pixelsHex ("0202...") intact
        val json = projFile.readText().replace("2".repeat(16), "7".repeat(16))
        projFile.writeText(json)

        val (loadedAtlas, _, _) = ProjectService.loadProject(projFile)
        assertEquals(7, loadedAtlas.textures[0].getPixel(0, 0))
        assertEquals(7, loadedAtlas.textures[0].getPixel(15, 15))
    }

    @Test
    fun testSampleTexturesProjectIfPresent(@TempDir tempDir: File) {
        val sampleProj = File("TEXTURES.sfxproj")
        if (sampleProj.exists()) {
            val (atlas, palette, gridSnap) = ProjectService.loadProject(sampleProj)
            val tempProj = File(tempDir, "TEXTURES.sfxproj")
            ProjectService.saveProject(tempProj, "TEXTURES", atlas, palette, gridSnap)
            assertTrue(File(tempDir, "TEXTURES.bin").exists())
            assertTrue(File(tempDir, "TEXTURES.pal").exists())
            assertTrue(File(tempDir, "TEXTURES.i").exists())
            assertTrue(File(tempDir, "TEXTURES_atlas.png").exists())
        }
    }
}

