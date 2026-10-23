package dev.secondsun.superx.tools.packer.model

/**
 * Implements median-cut color quantization to generate an optimal 15-color SNES BGR555 palette.
 * Slot 0 is always reserved for transparency. Opaque black is clamped to $0001.
 */
object MedianCutQuantizer {

    private data class ColorBox(
        val colors: List<SnesColor>
    ) {
        val minR: Int = colors.minOfOrNull { it.r } ?: 0
        val maxR: Int = colors.maxOfOrNull { it.r } ?: 0
        val minG: Int = colors.minOfOrNull { it.g } ?: 0
        val maxG: Int = colors.maxOfOrNull { it.g } ?: 0
        val minB: Int = colors.minOfOrNull { it.b } ?: 0
        val maxB: Int = colors.maxOfOrNull { it.b } ?: 0

        val rangeR: Int = maxR - minR
        val rangeG: Int = maxG - minG
        val rangeB: Int = maxB - minB

        val largestRange: Int = maxOf(rangeR, rangeG, rangeB)

        fun split(): Pair<ColorBox, ColorBox> {
            if (colors.size <= 1) return Pair(this, ColorBox(emptyList()))

            val sorted = when {
                rangeR >= rangeG && rangeR >= rangeB -> colors.sortedBy { it.r }
                rangeG >= rangeR && rangeG >= rangeB -> colors.sortedBy { it.g }
                else -> colors.sortedBy { it.b }
            }

            val median = sorted.size / 2
            return Pair(
                ColorBox(sorted.subList(0, median)),
                ColorBox(sorted.subList(median, sorted.size))
            )
        }

        fun averageColor(): SnesColor {
            if (colors.isEmpty()) return SnesColor.OPAQUE_BLACK
            val avgR = colors.sumOf { it.r } / colors.size
            val avgG = colors.sumOf { it.g } / colors.size
            val avgB = colors.sumOf { it.b } / colors.size
            return if (avgR == 0 && avgG == 0 && avgB == 0) {
                SnesColor.OPAQUE_BLACK
            } else {
                SnesColor(avgR, avgG, avgB)
            }
        }
    }

    /**
     * Quantizes a collection of opaque SnesColors into up to 15 palette colors.
     * Returns an updated SnesPalette with slots 1..N filled and assigned.
     */
    fun quantize(colors: List<SnesColor>): SnesPalette {
        val uniqueOpaque = colors.distinct()

        if (uniqueOpaque.isEmpty()) {
            return SnesPalette()
        }

        if (uniqueOpaque.size <= 15) {
            var pal = SnesPalette()
            // Clear existing default slots
            for (i in 1..15) {
                pal = pal.unassignSlot(i)
            }
            for ((idx, color) in uniqueOpaque.withIndex()) {
                pal = pal.withSlot(idx + 1, color, assigned = true)
            }
            return pal
        }

        // Run median cut
        val boxes = mutableListOf(ColorBox(colors))
        while (boxes.size < 15) {
            val splittable = boxes.filter { it.colors.size > 1 }.maxByOrNull { it.largestRange } ?: break
            boxes.remove(splittable)
            val (box1, box2) = splittable.split()
            boxes.add(box1)
            if (box2.colors.isNotEmpty()) {
                boxes.add(box2)
            }
        }

        var pal = SnesPalette()
        for (i in 1..15) {
            pal = pal.unassignSlot(i)
        }
        for ((idx, box) in boxes.withIndex()) {
            pal = pal.withSlot(idx + 1, box.averageColor(), assigned = true)
        }

        return pal
    }
}

