package dev.secondsun.superx.tools.packer.model

/**
 * An individual power-of-two bitmap graphic imported into a texture project.
 *
 * Dimensions must be independent powers of two within {16, 32, 64, 128, 256}.
 * [indexedPixels] contains width * height bytes, each holding a 4-bit palette index (0..15).
 */
data class SourceTexture(
    val name: String,
    val width: Int,
    val height: Int,
    val x: Int = 0,
    val y: Int = 0,
    val indexedPixels: ByteArray
) {
    init {
        require(isValidCa65Identifier(name)) {
            "Texture name '$name' is not a valid ca65 identifier (must match [A-Za-z_][A-Za-z0-9_]*)"
        }
        require(width in VALID_DIMENSIONS && isPowerOfTwo(width)) {
            "Width must be a power of two in $VALID_DIMENSIONS, got $width"
        }
        require(height in VALID_DIMENSIONS && isPowerOfTwo(height)) {
            "Height must be a power of two in $VALID_DIMENSIONS, got $height"
        }
        require(indexedPixels.size == width * height) {
            "Pixel array length must be ${width * height}, got ${indexedPixels.size}"
        }
    }

    val uMask: Int
        get() = width - 1

    val vMask: Int
        get() = height - 1

    val widthShift: Int
        get() = Integer.numberOfTrailingZeros(width)

    val heightShift: Int
        get() = Integer.numberOfTrailingZeros(height)

    fun getPixel(u: Int, v: Int): Int {
        require(u in 0 until width && v in 0 until height) { "Pixel coords out of bounds: ($u, $v)" }
        return indexedPixels[v * width + u].toInt() and 0x0F
    }

    fun setPixel(u: Int, v: Int, paletteIndex: Int): SourceTexture {
        require(u in 0 until width && v in 0 until height) { "Pixel coords out of bounds: ($u, $v)" }
        require(paletteIndex in 0..15) { "Palette index must be 0..15, got $paletteIndex" }
        val newPixels = indexedPixels.copyOf()
        newPixels[v * width + u] = paletteIndex.toByte()
        return copy(indexedPixels = newPixels)
    }

    /**
     * Remaps pixel indices according to the provided map. Any index not in the map remains unchanged.
     */
    fun remapPixels(mapping: Map<Int, Int>): SourceTexture {
        val newPixels = ByteArray(indexedPixels.size)
        for (i in indexedPixels.indices) {
            val oldIdx = indexedPixels[i].toInt() and 0x0F
            val newIdx = mapping[oldIdx] ?: oldIdx
            newPixels[i] = (newIdx and 0x0F).toByte()
        }
        return copy(indexedPixels = newPixels)
    }

    /**
     * Returns the set of all palette indices (0..15) used in this texture.
     */
    fun usedPaletteIndices(): Set<Int> {
        val set = mutableSetOf<Int>()
        for (b in indexedPixels) {
            set.add(b.toInt() and 0x0F)
        }
        return set
    }

    /**
     * Checks if this texture's bounding box intersects with another texture.
     */
    fun intersects(other: SourceTexture): Boolean {
        return this.x < other.x + other.width &&
               this.x + this.width > other.x &&
               this.y < other.y + other.height &&
               this.y + this.height > other.y
    }

    /**
     * Checks if this texture fits within the specified atlas dimensions.
     */
    fun isWithinBounds(atlasWidth: Int, atlasHeight: Int): Boolean {
        return x >= 0 && y >= 0 && x + width <= atlasWidth && y + height <= atlasHeight
    }

    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (javaClass != other?.javaClass) return false

        other as SourceTexture
        if (name != other.name) return false
        if (width != other.width) return false
        if (height != other.height) return false
        if (x != other.x) return false
        if (y != other.y) return false
        if (!indexedPixels.contentEquals(other.indexedPixels)) return false

        return true
    }

    override fun hashCode(): Int {
        var result = name.hashCode()
        result = 31 * result + width
        result = 31 * result + height
        result = 31 * result + x
        result = 31 * result + y
        result = 31 * result + indexedPixels.contentHashCode()
        return result
    }

    companion object {
        val VALID_DIMENSIONS = setOf(16, 32, 64, 128, 256)

        fun isPowerOfTwo(value: Int): Boolean = value > 0 && (value and (value - 1)) == 0

        fun isValidCa65Identifier(identifier: String): Boolean {
            if (identifier.isEmpty()) return false
            if (!identifier[0].isLetter() && identifier[0] != '_') return false
            return identifier.all { it.isLetterOrDigit() || it == '_' }
        }

        fun sanitizeToIdentifier(input: String): String {
            val base = input.replace("[^A-Za-z0-9_]".toRegex(), "_")
            return if (base.isEmpty() || (!base[0].isLetter() && base[0] != '_')) "_$base" else base
        }
    }
}

