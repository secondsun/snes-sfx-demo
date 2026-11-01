package dev.secondsun.superx.tools.packer

import dev.secondsun.superx.tools.packer.model.*
import org.junit.jupiter.api.Assertions.*
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.io.TempDir
import java.io.File

class CliMainTest {

    @Test
    fun testCliPackAndValidate(@TempDir tempDir: File) {
        val projFile = File(tempDir, "TEST_CLI.sfxproj")
        val pixels = ByteArray(16 * 16) { 1 }
        val tex = SourceTexture("box", 16, 16, 0, 0, pixels)
        val slice = VirtualSlice("box_half", "box", 0, 0, 16, 16)
        val alias = DescriptorAlias("box_dup", "box")

        val atlas = TextureAtlas(
            width = 32,
            height = 32,
            textures = listOf(tex),
            slices = listOf(slice),
            aliases = listOf(alias)
        )
        val palette = SnesPalette().withSlot(1, SnesColor(31, 0, 0), assigned = true)

        ProjectService.saveProject(projFile, "TEST_CLI", atlas, palette, 16)

        // Run validate via CliMain
        CliMain.main(arrayOf("validate", projFile.absolutePath))

        // Run pack via CliMain
        CliMain.main(arrayOf("pack", projFile.absolutePath))

        assertTrue(File(tempDir, "TEST_CLI.bin").exists())
        assertTrue(File(tempDir, "TEST_CLI.pal").exists())
        assertTrue(File(tempDir, "TEST_CLI.i").exists())
        assertTrue(File(tempDir, "TEST_CLI_atlas.png").exists())

        val includeContent = File(tempDir, "TEST_CLI.i").readText()
        assertTrue(includeContent.contains("TEXTURE_ID_BOX = 0"))
        assertTrue(includeContent.contains("TEXTURE_ID_BOX_DUP = 1"))
        assertTrue(includeContent.contains("TEXTURE_ID_BOX_HALF = 2"))
        assertTrue(includeContent.contains(".segment \"GSUDATA\""))
        assertTrue(includeContent.contains(".export TEXTURE_TABLE"))
    }
}

