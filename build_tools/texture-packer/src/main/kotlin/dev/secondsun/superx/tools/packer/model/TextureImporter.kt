package dev.secondsun.superx.tools.packer.model

import java.awt.image.BufferedImage
import java.io.File
import javax.imageio.ImageIO

/**
 * Result of attempting to import a bitmap file.
 */
sealed class ImportResult {
    data class Success(
        val texture: SourceTexture,
        val updatedPalette: SnesPalette
    ) : ImportResult()

    data class NeedsRemapping(
        val rawImage: BufferedImage,
        val suggestedName: String,
        val uniqueColors: List<SnesColor>,
        val currentPalette: SnesPalette,
        val unmappedColors: List<SnesColor>
    ) : ImportResult()

    data class Error(
        val message: String
    ) : ImportResult()
}

object TextureImporter {

    fun importFromFile(file: File, currentPalette: SnesPalette): ImportResult {
        val image: BufferedImage
        try {
            image = ImageIO.read(file) ?: return ImportResult.Error("Could not decode image from '${file.name}'")
        } catch (e: Exception) {
            return ImportResult.Error("Failed to read image '${file.name}': ${e.message}")
        }

        val baseName = file.nameWithoutExtension
        val suggestedName = SourceTexture.sanitizeToIdentifier(baseName)
        return importFromImage(image, suggestedName, currentPalette)
    }

    fun importFromImage(
        image: BufferedImage,
        name: String,
        currentPalette: SnesPalette
    ): ImportResult {
        val width = image.width
        val height = image.height

        if (width !in SourceTexture.VALID_DIMENSIONS || !SourceTexture.isPowerOfTwo(width)) {
            return ImportResult.Error("Image width $width is not a supported power of two in ${SourceTexture.VALID_DIMENSIONS}")
        }
        if (height !in SourceTexture.VALID_DIMENSIONS || !SourceTexture.isPowerOfTwo(height)) {
            return ImportResult.Error("Image height $height is not a supported power of two in ${SourceTexture.VALID_DIMENSIONS}")
        }

        // Extract unique opaque colors and check transparency
        val uniqueOpaqueColors = LinkedHashSet<SnesColor>()
        for (y in 0 until height) {
            for (x in 0 until width) {
                val argb = image.getRGB(x, y)
                val alpha = (argb shr 24) and 0xFF
                if (alpha >= 128) {
                    val r = (argb shr 16) and 0xFF
                    val g = (argb shr 8) and 0xFF
                    val b = argb and 0xFF
                    uniqueOpaqueColors.add(SnesColor.fromRgb888(r, g, b))
                }
            }
        }

        // Check if colors fit in current palette
        var workingPalette = currentPalette
        val unmappedColors = mutableListOf<SnesColor>()
        val colorToSlotMap = mutableMapOf<SnesColor, Int>()

        for (color in uniqueOpaqueColors) {
            val exactIdx = workingPalette.findExactIndex(color)
            if (exactIdx != null) {
                colorToSlotMap[color] = exactIdx
            } else {
                val freeSlot = workingPalette.findFirstUnassignedSlot()
                if (freeSlot != null) {
                    workingPalette = workingPalette.withSlot(freeSlot, color, assigned = true)
                    colorToSlotMap[color] = freeSlot
                } else {
                    unmappedColors.add(color)
                }
            }
        }

        if (unmappedColors.isNotEmpty()) {
            return ImportResult.NeedsRemapping(
                rawImage = image,
                suggestedName = name,
                uniqueColors = uniqueOpaqueColors.toList(),
                currentPalette = currentPalette,
                unmappedColors = unmappedColors
            )
        }

        // Successfully mapped all colors
        val texture = createTextureFromImage(image, name, colorToSlotMap)
        return ImportResult.Success(texture, workingPalette)
    }

    /**
     * Converts a BufferedImage to a SourceTexture using the supplied color mapping.
     */
    fun createTextureFromImage(
        image: BufferedImage,
        name: String,
        colorMapping: Map<SnesColor, Int>,
        fallbackPalette: SnesPalette? = null
    ): SourceTexture {
        val width = image.width
        val height = image.height
        val pixels = ByteArray(width * height)

        for (y in 0 until height) {
            for (x in 0 until width) {
                val argb = image.getRGB(x, y)
                val alpha = (argb shr 24) and 0xFF
                val slot = if (alpha < 128) {
                    0 // Transparent
                } else {
                    val r = (argb shr 16) and 0xFF
                    val g = (argb shr 8) and 0xFF
                    val b = argb and 0xFF
                    val color = SnesColor.fromRgb888(r, g, b)
                    colorMapping[color] ?: fallbackPalette?.findNearestAssignedIndex(color) ?: 1
                }
                pixels[y * width + x] = (slot and 0x0F).toByte()
            }
        }

        return SourceTexture(
            name = name,
            width = width,
            height = height,
            x = 0,
            y = 0,
            indexedPixels = pixels
        )
    }
}

