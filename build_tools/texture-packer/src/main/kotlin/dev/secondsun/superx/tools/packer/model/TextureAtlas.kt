package dev.secondsun.superx.tools.packer.model

/**
 * The composite power-of-two graphics buffer into which multiple [SourceTexture]s are positioned and merged.
 *
 * Encoded as unpacked 1-byte-per-texel (values 0..15) in row-major order.
 * Width and height are independent powers of two within {16, 32, 64, 128, 256}.
 */
data class TextureAtlas(
    val width: Int = 128,
    val height: Int = 128,
    val textures: List<SourceTexture> = emptyList()
) {
    init {
        require(width in SourceTexture.VALID_DIMENSIONS && SourceTexture.isPowerOfTwo(width)) {
            "Atlas width must be power of two in ${SourceTexture.VALID_DIMENSIONS}, got $width"
        }
        require(height in SourceTexture.VALID_DIMENSIONS && SourceTexture.isPowerOfTwo(height)) {
            "Atlas height must be power of two in ${SourceTexture.VALID_DIMENSIONS}, got $height"
        }
    }

    val strideShift: Int
        get() = Integer.numberOfTrailingZeros(width)

    val heightShift: Int
        get() = Integer.numberOfTrailingZeros(height)

    val sizeBytes: Int
        get() = width * height

    /**
     * Checks if placing a texture at (x, y) is within bounds and doesn't collide with other textures.
     * [excludeTextureIndex] allows ignoring the texture currently being dragged/repositioned.
     */
    fun canPlace(candidate: SourceTexture, newX: Int, newY: Int, excludeTextureIndex: Int = -1): Boolean {
        if (newX < 0 || newY < 0 || newX + candidate.width > width || newY + candidate.height > height) {
            return false
        }
        val testTex = candidate.copy(x = newX, y = newY)
        for (i in textures.indices) {
            if (i == excludeTextureIndex) continue
            if (testTex.intersects(textures[i])) {
                return false
            }
        }
        return true
    }

    /**
     * Finds the first valid non-overlapping position for a texture aligned to [gridSize].
     */
    fun findPlacement(candidate: SourceTexture, gridSize: Int = 16): Pair<Int, Int>? {
        for (y in 0..(height - candidate.height) step gridSize) {
            for (x in 0..(width - candidate.width) step gridSize) {
                if (canPlace(candidate, x, y)) {
                    return Pair(x, y)
                }
            }
        }
        return null
    }

    /**
     * Adds a texture to the atlas.
     */
    fun withTexture(texture: SourceTexture): TextureAtlas {
        return copy(textures = textures + texture)
    }

    /**
     * Updates an existing texture at [index].
     */
    fun withUpdatedTexture(index: Int, updated: SourceTexture): TextureAtlas {
        require(index in textures.indices) { "Invalid texture index $index" }
        val list = textures.toMutableList()
        list[index] = updated
        return copy(textures = list)
    }

    /**
     * Removes the texture at [index].
     */
    fun withoutTexture(index: Int): TextureAtlas {
        require(index in textures.indices) { "Invalid texture index $index" }
        val list = textures.toMutableList()
        list.removeAt(index)
        return copy(textures = list)
    }

    /**
     * Generates the 1-byte-per-texel linear binary buffer (width * height bytes).
     * Any unassigned or transparent space is 0x00.
     */
    fun generateBinary(): ByteArray {
        val buffer = ByteArray(sizeBytes) // initialized to 0 (transparent)
        for (tex in textures) {
            for (v in 0 until tex.height) {
                val atlasRowOffset = (tex.y + v) * width + tex.x
                val texRowOffset = v * tex.width
                for (u in 0 until tex.width) {
                    val pixel = tex.indexedPixels[texRowOffset + u]
                    buffer[atlasRowOffset + u] = pixel
                }
            }
        }
        return buffer
    }

    /**
     * Automatically packs all textures into the atlas using a shelf packing algorithm aligned to [gridSize].
     * Returns a new TextureAtlas with updated coordinates, or null if they don't fit.
     */
    fun autoPack(gridSize: Int = 16): TextureAtlas? {
        // Sort textures by height descending, then width descending
        val sortedWithIndices = textures.mapIndexed { idx, tex -> Pair(idx, tex) }
            .sortedWith(compareByDescending<Pair<Int, SourceTexture>> { it.second.height }
                .thenByDescending { it.second.width })

        val newPositions = Array(textures.size) { Pair(0, 0) }
        var currentY = 0
        var currentX = 0
        var shelfHeight = 0

        for ((origIdx, tex) in sortedWithIndices) {
            // Check if tex fits in current shelf
            if (currentX + tex.width > width) {
                // Move to next shelf
                currentX = 0
                val rawY = currentY + shelfHeight
                currentY = roundUp(rawY, gridSize)
                shelfHeight = 0
            }

            if (currentY + tex.height > height) {
                // Doesn't fit in current atlas dimensions
                return null
            }

            newPositions[origIdx] = Pair(currentX, currentY)
            shelfHeight = maxOf(shelfHeight, tex.height)
            currentX = roundUp(currentX + tex.width, gridSize)
        }

        val packedTextures = textures.mapIndexed { idx, tex ->
            val pos = newPositions[idx]
            tex.copy(x = pos.first, y = pos.second)
        }

        return copy(textures = packedTextures)
    }

    /**
     * Calculates the minimum power-of-two dimensions in {16, 32, 64, 128, 256} needed
     * to contain all currently placed textures without moving them.
     */
    fun autoFitDimensions(): Pair<Int, Int> {
        var maxX = 16
        var maxY = 16
        for (tex in textures) {
            maxX = maxOf(maxX, tex.x + tex.width)
            maxY = maxOf(maxY, tex.y + tex.height)
        }

        val fitWidth = SourceTexture.VALID_DIMENSIONS.filter { it >= maxX }.minOrNull() ?: 256
        val fitHeight = SourceTexture.VALID_DIMENSIONS.filter { it >= maxY }.minOrNull() ?: 256
        return Pair(fitWidth, fitHeight)
    }

    companion object {
        private fun roundUp(value: Int, grid: Int): Int {
            if (grid <= 1) return value
            val rem = value % grid
            return if (rem == 0) value else value + (grid - rem)
        }
    }
}

