package dev.secondsun.superx.tools.packer.model

/**
 * A single slot in the 16-color SNES palette.
 */
data class PaletteSlot(
    val color: SnesColor,
    val isAssigned: Boolean = false
)

/**
 * Represents a 16-color SNES palette.
 * Slot 0 is permanently locked as Transparent ($0000).
 * Slots 1..15 are usable for opaque colors ($0001..$7FFF).
 */
data class SnesPalette(
    val slots: List<PaletteSlot> = defaultSlots()
) {
    init {
        require(slots.size == 16) { "Palette must contain exactly 16 slots, got ${slots.size}" }
    }

    /**
     * Returns the color at the given palette index.
     * Index 0 always returns TRANSPARENT ($0000).
     */
    operator fun get(index: Int): SnesColor {
        require(index in 0..15) { "Palette index must be 0..15, got $index" }
        return if (index == 0) SnesColor.TRANSPARENT else slots[index].color
    }

    /**
     * Checks if slot is assigned. Slot 0 is always considered assigned (transparent).
     */
    fun isAssigned(index: Int): Boolean {
        require(index in 0..15) { "Palette index must be 0..15, got $index" }
        return if (index == 0) true else slots[index].isAssigned
    }

    /**
     * Returns a new SnesPalette with the specified slot updated.
     * Slot 0 cannot be modified (always transparent).
     */
    fun withSlot(index: Int, color: SnesColor, assigned: Boolean = true): SnesPalette {
        require(index in 1..15) { "Cannot modify slot 0 (permanently transparent)" }
        val newSlots = slots.toMutableList()
        newSlots[index] = PaletteSlot(color, assigned)
        return copy(slots = newSlots)
    }

    /**
     * Unassigns a slot in 1..15.
     */
    fun unassignSlot(index: Int): SnesPalette {
        require(index in 1..15) { "Cannot unassign slot 0 (permanently transparent)" }
        val newSlots = slots.toMutableList()
        newSlots[index] = newSlots[index].copy(isAssigned = false)
        return copy(slots = newSlots)
    }

    /**
     * Finds the first unassigned slot index in 1..15, or null if all are assigned.
     */
    fun findFirstUnassignedSlot(): Int? {
        for (i in 1..15) {
            if (!slots[i].isAssigned) return i
        }
        return null
    }

    /**
     * Counts how many slots in 1..15 are currently assigned.
     */
    val assignedCount: Int
        get() = (1..15).count { slots[it].isAssigned }

    /**
     * Finds an assigned slot in 1..15 that exactly matches the given color's BGR555 value.
     */
    fun findExactIndex(color: SnesColor): Int? {
        for (i in 1..15) {
            if (slots[i].isAssigned && slots[i].color.bgr555 == color.bgr555) {
                return i
            }
        }
        return null
    }

    /**
     * Finds the nearest assigned slot in 1..15 based on perceptual distance.
     * If no slots in 1..15 are assigned, defaults to slot 1.
     */
    fun findNearestAssignedIndex(color: SnesColor): Int {
        var bestIndex = 1
        var bestDist = Int.MAX_VALUE
        for (i in 1..15) {
            if (slots[i].isAssigned) {
                val dist = slots[i].color.distanceSquared(color)
                if (dist < bestDist) {
                    bestDist = dist
                    bestIndex = i
                }
            }
        }
        return bestIndex
    }

    /**
     * Exports the palette as 32 binary bytes (16 x 16-bit little endian words).
     * Slot 0 is always emitted as 0x00, 0x00 ($0000).
     */
    fun toBgr555Binary(): ByteArray {
        val bytes = ByteArray(32)
        // Slot 0 is transparent ($0000)
        bytes[0] = 0
        bytes[1] = 0

        for (i in 1..15) {
            val word = slots[i].color.bgr555
            bytes[i * 2] = (word and 0xFF).toByte()
            bytes[i * 2 + 1] = ((word shr 8) and 0xFF).toByte()
        }
        return bytes
    }

    companion object {
        fun defaultSlots(): List<PaletteSlot> {
            val list = ArrayList<PaletteSlot>(16)
            // Slot 0: Transparent
            list.add(PaletteSlot(SnesColor.TRANSPARENT, isAssigned = true))
            // Slot 1: Opaque black ($0001)
            list.add(PaletteSlot(SnesColor.OPAQUE_BLACK, isAssigned = true))
            // Slots 2..15: unassigned initial placeholders
            val defaults = listOf(
                SnesColor(31, 31, 31), // White
                SnesColor(31, 0, 0),   // Red
                SnesColor(0, 31, 0),   // Green
                SnesColor(0, 0, 31),   // Blue
                SnesColor(31, 31, 0),  // Yellow
                SnesColor(0, 31, 31),  // Cyan
                SnesColor(31, 0, 31),  // Magenta
                SnesColor(16, 16, 16), // Gray
                SnesColor(24, 16, 8),  // Brown
                SnesColor(31, 16, 0),  // Orange
                SnesColor(16, 0, 24),  // Purple
                SnesColor(16, 24, 8),  // Olive
                SnesColor(8, 16, 24),  // Slate
                SnesColor(24, 24, 16)  // Cream
            )
            for (color in defaults) {
                list.add(PaletteSlot(color, isAssigned = false))
            }
            return list
        }
    }
}

