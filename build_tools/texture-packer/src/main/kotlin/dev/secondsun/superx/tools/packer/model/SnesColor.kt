package dev.secondsun.superx.tools.packer.model

/**
 * Represents a 15-bit SNES BGR555 color.
 *
 * Bit layout (16-bit word, little endian in binary):
 *  0 b b b b b g g g g g r r r r r
 *
 * Note: Index 0 ($0000) represents transparency. Opaque black is clamped to $0001 (r=1, g=0, b=0)
 * so it is never confused with transparency.
 */
data class SnesColor(
    val r: Int, // 0..31
    val g: Int, // 0..31
    val b: Int  // 0..31
) {
    init {
        require(r in 0..31) { "Red component must be 0..31, got $r" }
        require(g in 0..31) { "Green component must be 0..31, got $g" }
        require(b in 0..31) { "Blue component must be 0..31, got $b" }
    }

    /**
     * Encodes this color to a 15-bit BGR555 integer (0..0x7FFF).
     * If r=0, g=0, b=0 (pure black), it is encoded as 0x0001 so it remains distinct from transparent ($0000).
     */
    val bgr555: Int
        get() {
            val effR = if (r == 0 && g == 0 && b == 0) 1 else r
            return (effR and 0x1F) or ((g and 0x1F) shl 5) or ((b and 0x1F) shl 10)
        }

    /**
     * Converts to 24-bit RGB (0xRRGGBB) expanding 5 bits to 8 bits.
     */
    val rgb888: Int
        get() {
            val r8 = (r shl 3) or (r shr 2)
            val g8 = (g shl 3) or (g shr 2)
            val b8 = (b shl 3) or (b shr 2)
            return (r8 shl 16) or (g8 shl 8) or b8
        }

    /**
     * Converts to 32-bit ARGB with alpha = 255.
     */
    val argb: Int
        get() = (0xFF shl 24) or rgb888

    /**
     * Hex string representation: e.g. "$0001"
     */
    val hexString: String
        get() = String.format("$%04X", bgr555)

    /**
     * Calculates weighted perceptual Euclidean distance to another SnesColor.
     */
    fun distanceSquared(other: SnesColor): Int {
        val dr = this.r - other.r
        val dg = this.g - other.g
        val db = this.b - other.b
        return 2 * dr * dr + 4 * dg * dg + 3 * db * db
    }

    companion object {
        /**
         * Transparent color representation (0x0000).
         */
        val TRANSPARENT = SnesColor(0, 0, 0)

        /**
         * Clamped opaque black representation ($0001, r=1, g=0, b=0).
         */
        val OPAQUE_BLACK = SnesColor(1, 0, 0)

        /**
         * Creates an SnesColor from standard 8-bit RGB components (0..255).
         * For opaque black (r8=0, g8=0, b8=0), clamps r to 1 ($0001).
         */
        fun fromRgb888(r8: Int, g8: Int, b8: Int, clampBlack: Boolean = true): SnesColor {
            var r5 = (r8 and 0xFF) shr 3
            val g5 = (g8 and 0xFF) shr 3
            val b5 = (b8 and 0xFF) shr 3
            if (clampBlack && r5 == 0 && g5 == 0 && b5 == 0) {
                r5 = 1
            }
            return SnesColor(r5, g5, b5)
        }

        /**
         * Decodes a 15-bit BGR555 word into SnesColor.
         */
        fun fromBgr555(word: Int): SnesColor {
            val r = word and 0x1F
            val g = (word shr 5) and 0x1F
            val b = (word shr 10) and 0x1F
            return SnesColor(r, g, b)
        }
    }
}

