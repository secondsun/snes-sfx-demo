package dev.secondsun.superx.tools.packer.ui

import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.toComposeImageBitmap
import dev.secondsun.superx.tools.packer.model.SnesPalette
import dev.secondsun.superx.tools.packer.model.SourceTexture
import dev.secondsun.superx.tools.packer.model.TextureAtlas
import java.awt.image.BufferedImage

object TextureRenderer {

    /**
     * Renders a SourceTexture into a BufferedImage using the specified palette.
     * Slot 0 is rendered as ARGB transparent (0x00000000).
     */
    fun renderToBufferedImage(texture: SourceTexture, palette: SnesPalette): BufferedImage {
        val image = BufferedImage(texture.width, texture.height, BufferedImage.TYPE_INT_ARGB)
        for (v in 0 until texture.height) {
            for (u in 0 until texture.width) {
                val slot = texture.getPixel(u, v)
                val argb = if (slot == 0) {
                    0x00000000 // Transparent
                } else {
                    palette[slot].argb
                }
                image.setRGB(u, v, argb)
            }
        }
        return image
    }

    /**
     * Converts a SourceTexture to Compose ImageBitmap.
     */
    fun renderToImageBitmap(texture: SourceTexture, palette: SnesPalette): ImageBitmap {
        return renderToBufferedImage(texture, palette).toComposeImageBitmap()
    }

    /**
     * Renders the entire TextureAtlas to a BufferedImage.
     */
    fun renderAtlasToBufferedImage(atlas: TextureAtlas, palette: SnesPalette): BufferedImage {
        val image = BufferedImage(atlas.width, atlas.height, BufferedImage.TYPE_INT_ARGB)
        val binary = atlas.generateBinary()
        for (y in 0 until atlas.height) {
            val rowOffset = y * atlas.width
            for (x in 0 until atlas.width) {
                val slot = binary[rowOffset + x].toInt() and 0x0F
                val argb = if (slot == 0) {
                    0x00000000 // Transparent
                } else {
                    palette[slot].argb
                }
                image.setRGB(x, y, argb)
            }
        }
        return image
    }

    /**
     * Converts the entire TextureAtlas to Compose ImageBitmap.
     */
    fun renderAtlasToImageBitmap(atlas: TextureAtlas, palette: SnesPalette): ImageBitmap {
        return renderAtlasToBufferedImage(atlas, palette).toComposeImageBitmap()
    }
}

