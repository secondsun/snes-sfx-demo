package dev.secondsun.superx.tools.packer.model

/**
 * A virtual sub-rectangle descriptor defined inside an existing [SourceTexture].
 *
 * Coordinates (x, y) are relative to the top-left of [sourceTexture].
 * Dimensions must be independent powers of two within {16, 32, 64, 128, 256}.
 */
data class VirtualSlice(
    val name: String,
    val sourceTexture: String,
    val x: Int = 0,
    val y: Int = 0,
    val width: Int,
    val height: Int
) {
    init {
        require(SourceTexture.isValidCa65Identifier(name)) {
            "Slice name '$name' is not a valid ca65 identifier (must match [A-Za-z_][A-Za-z0-9_]*)"
        }
        require(width in SourceTexture.VALID_DIMENSIONS && SourceTexture.isPowerOfTwo(width)) {
            "Slice width must be a power of two in ${SourceTexture.VALID_DIMENSIONS}, got $width"
        }
        require(height in SourceTexture.VALID_DIMENSIONS && SourceTexture.isPowerOfTwo(height)) {
            "Slice height must be a power of two in ${SourceTexture.VALID_DIMENSIONS}, got $height"
        }
    }

    val uMask: Int get() = width - 1
    val vMask: Int get() = height - 1
    val widthShift: Int get() = Integer.numberOfTrailingZeros(width)
}

/**
 * An alternate symbolic identifier mapping to an existing texture or slice descriptor in TEXTURE_TABLE.
 */
data class DescriptorAlias(
    val name: String,
    val target: String
) {
    init {
        require(SourceTexture.isValidCa65Identifier(name)) {
            "Alias name '$name' is not a valid ca65 identifier (must match [A-Za-z_][A-Za-z0-9_]*)"
        }
    }
}

/**
 * Complete resolved metadata for an 8-byte texture descriptor entry.
 */
data class TextureDescriptorInfo(
    val name: String,
    val x: Int,
    val y: Int,
    val width: Int,
    val height: Int,
    val romOffset: Int,
    val uMask: Int,
    val vMask: Int,
    val widthShift: Int,
    val comment: String
)

/**
 * The composite power-of-two graphics buffer into which multiple [SourceTexture]s are positioned and merged.
 *
 * Encoded as unpacked 1-byte-per-texel (values 0..15) in row-major order.
 * Width and height are independent powers of two within {16, 32, 64, 128, 256}.
 */
data class TextureAtlas(
    val width: Int = 128,
    val height: Int = 128,
    val textures: List<SourceTexture> = emptyList(),
    val slices: List<VirtualSlice> = emptyList(),
    val aliases: List<DescriptorAlias> = emptyList(),
    val descriptorOrder: List<String>? = null
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
     * Resolves all descriptors (base textures, virtual slices, and aliases) in deterministic order.
     */
    fun resolvedDescriptors(): List<TextureDescriptorInfo> {
        val map = mutableMapOf<String, TextureDescriptorInfo>()

        // 1. Base textures
        for (tex in textures) {
            val romOffset = tex.y * width + tex.x
            map[tex.name] = TextureDescriptorInfo(
                name = tex.name,
                x = tex.x,
                y = tex.y,
                width = tex.width,
                height = tex.height,
                romOffset = romOffset,
                uMask = tex.uMask,
                vMask = tex.vMask,
                widthShift = tex.widthShift,
                comment = "${tex.name} (${tex.width}x${tex.height})"
            )
        }

        // 2. Virtual slices
        for (slice in slices) {
            val parent = textures.find { it.name == slice.sourceTexture }
                ?: error("Virtual slice '${slice.name}' references non-existent source texture '${slice.sourceTexture}'")
            val sliceX = parent.x + slice.x
            val sliceY = parent.y + slice.y
            require(slice.x >= 0 && slice.y >= 0 && slice.x + slice.width <= parent.width && slice.y + slice.height <= parent.height) {
                "Virtual slice '${slice.name}' is out of bounds of parent texture '${parent.name}'"
            }
            val romOffset = sliceY * width + sliceX
            map[slice.name] = TextureDescriptorInfo(
                name = slice.name,
                x = sliceX,
                y = sliceY,
                width = slice.width,
                height = slice.height,
                romOffset = romOffset,
                uMask = slice.uMask,
                vMask = slice.vMask,
                widthShift = slice.widthShift,
                comment = "${slice.name} (${slice.width}x${slice.height})"
            )
        }

        // 3. Aliases
        for (alias in aliases) {
            val target = map[alias.target]
                ?: error("Descriptor alias '${alias.name}' references unknown target '${alias.target}'")
            map[alias.name] = target.copy(
                name = alias.name,
                comment = "${alias.name} (${target.width}x${target.height})"
            )
        }

        // Determine ordering
        return if (descriptorOrder != null && descriptorOrder.isNotEmpty()) {
            descriptorOrder.map { name ->
                map[name] ?: error("Descriptor '$name' in descriptorOrder is not defined in textures, slices, or aliases")
            }
        } else {
            textures.map { map[it.name]!! } +
            aliases.map { map[it.name]!! } +
            slices.map { map[it.name]!! }
        }
    }

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

    fun withSlice(slice: VirtualSlice): TextureAtlas {
        return copy(slices = slices + slice)
    }

    fun withAlias(alias: DescriptorAlias): TextureAtlas {
        return copy(aliases = aliases + alias)
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
