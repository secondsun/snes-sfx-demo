package dev.secondsun.superx.tools.packer.ui

import dev.secondsun.superx.tools.packer.model.SnesColor
import dev.secondsun.superx.tools.packer.model.SourceTexture
import org.junit.jupiter.api.Assertions.*
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.io.TempDir
import java.io.File

class PackerStateTest {

    @Test
    fun testInitialStateNotDirty() {
        val state = PackerState()
        assertFalse(state.hasUnsavedChanges, "Newly created state should not have unsaved changes")
    }

    @Test
    fun testModifyingAtlasMarksDirty(@TempDir tempDir: File) {
        val state = PackerState()
        assertFalse(state.hasUnsavedChanges)

        val tex = SourceTexture("test", 16, 16, 0, 0, ByteArray(256))
        state.atlas = state.atlas.withTexture(tex)
        assertTrue(state.hasUnsavedChanges, "Adding a texture should mark unsaved changes")

        // Save project and verify clean
        val projFile = File(tempDir, "test.sfxproj")
        val saved = state.saveProject(projFile)
        assertTrue(saved)
        assertFalse(state.hasUnsavedChanges, "Saving should clear unsaved changes")
    }

    @Test
    fun testModifyingPaletteMarksDirty(@TempDir tempDir: File) {
        val state = PackerState()
        val projFile = File(tempDir, "test.sfxproj")
        state.saveProject(projFile)
        assertFalse(state.hasUnsavedChanges)

        // Modify a palette slot
        state.updatePaletteSlot(2, SnesColor(15, 15, 15))
        assertTrue(state.hasUnsavedChanges, "Updating palette slot should mark unsaved changes")

        // New project should reset dirty flag
        state.newProject()
        assertFalse(state.hasUnsavedChanges, "New project should not have unsaved changes")
    }

    @Test
    fun testOpenProjectClearsDirty(@TempDir tempDir: File) {
        val state = PackerState()
        val tex = SourceTexture("sprite", 16, 16, 0, 0, ByteArray(256))
        state.atlas = state.atlas.withTexture(tex)
        assertTrue(state.hasUnsavedChanges)

        val projFile = File(tempDir, "sample.sfxproj")
        state.saveProject(projFile)
        assertFalse(state.hasUnsavedChanges)

        // Make another change
        state.updatePaletteSlot(3, SnesColor(5, 5, 5))
        assertTrue(state.hasUnsavedChanges)

        // Re-open saved file
        state.openProject(projFile)
        assertFalse(state.hasUnsavedChanges, "Opening project should clear unsaved changes")
    }

    @Test
    fun testLastImportDirectory() {
        val state = PackerState()
        state.lastImportDirectory = "/tmp"
        assertEquals("/tmp", state.lastImportDirectory)
    }
}

