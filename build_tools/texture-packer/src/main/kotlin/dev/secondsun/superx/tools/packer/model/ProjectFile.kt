package dev.secondsun.superx.tools.packer.model

import com.google.gson.Gson
import com.google.gson.GsonBuilder
import java.io.File

data class ProjectColorDto(
    val index: Int,
    val r: Int,
    val g: Int,
    val b: Int,
    val assigned: Boolean
)

data class ProjectSliceDto(
    val name: String,
    val sourceTexture: String,
    val x: Int = 0,
    val y: Int = 0,
    val width: Int,
    val height: Int
)

data class ProjectAliasDto(
    val name: String,
    val target: String
)

data class ProjectTextureDto(
    val name: String,
    val width: Int,
    val height: Int,
    val x: Int,
    val y: Int,
    val pixelsHex: String = "",
    val pixelsAscii: String? = null
)

data class ProjectDto(
    val name: String,
    val atlasWidth: Int,
    val atlasHeight: Int,
    val gridSnap: Int,
    val palette: List<ProjectColorDto>,
    val textures: List<ProjectTextureDto>,
    val slices: List<ProjectSliceDto>? = null,
    val aliases: List<ProjectAliasDto>? = null,
    val descriptorOrder: List<String>? = null
)

data class ExportedAssets(
    val graphicsBinFile: File,
    val paletteBinFile: File,
    val indexFile: File,
    val pngFile: File
)

object ProjectService {
    private val gson: Gson = GsonBuilder().setPrettyPrinting().create()

    fun pixelsToHex(pixels: ByteArray): String {
        val sb = StringBuilder(pixels.size * 2)
        for (b in pixels) {
            sb.append(String.format("%02X", b.toInt() and 0x0F))
        }
        return sb.toString()
    }

    fun hexToPixels(hex: String, width: Int, height: Int): ByteArray {
        val pixels = ByteArray(width * height)
        for (i in pixels.indices) {
            val hexByte = if (i * 2 + 1 < hex.length) {
                hex.substring(i * 2, i * 2 + 2).toIntOrNull(16) ?: 0
            } else {
                0
            }
            pixels[i] = (hexByte and 0x0F).toByte()
        }
        return pixels
    }

    fun pixelsToAscii(pixels: ByteArray, width: Int, height: Int): String {
        val sb = StringBuilder()
        for (y in 0 until height) {
            for (x in 0 until width) {
                val p = pixels[y * width + x].toInt() and 0x0F
                val c = when {
                    p == 0 -> '.'
                    p < 10 -> ('0' + p)
                    else -> ('A' + (p - 10))
                }
                sb.append(c)
            }
            sb.append("\n")
        }
        return sb.toString().trimEnd()
    }

    fun asciiToPixels(ascii: String, width: Int, height: Int): ByteArray {
        val clean = ascii.filter { !it.isWhitespace() }
        require(clean.length == width * height) {
            "ASCII pixel length must be ${width * height}, got ${clean.length}"
        }
        val pixels = ByteArray(clean.length)
        for (i in clean.indices) {
            val c = clean[i]
            pixels[i] = when (c) {
                '.' -> 0.toByte()
                in '0'..'9' -> (c - '0').toByte()
                in 'a'..'f' -> (c - 'a' + 10).toByte()
                in 'A'..'F' -> (c - 'A' + 10).toByte()
                else -> throw IllegalArgumentException("Invalid ASCII pixel character '$c' at index $i")
            }
        }
        return pixels
    }

    fun exportAssets(
        destinationDir: File,
        baseName: String,
        atlas: TextureAtlas,
        palette: SnesPalette,
        graphicsBinFileName: String = "${baseName}.bin",
        paletteBinFileName: String = "${baseName}.pal",
        indexFileName: String = "${baseName}.i",
        pngFileName: String = "${baseName}_atlas.png",
        includeGraphicsBin: Boolean = true,
        includePaletteBin: Boolean = true,
        includeIndexFile: Boolean = true,
        includePng: Boolean = true
    ): ExportedAssets {
        destinationDir.mkdirs()

        val gBin = File(destinationDir, graphicsBinFileName)
        if (includeGraphicsBin) {
            gBin.writeBytes(atlas.generateBinary())
        }

        val pBin = File(destinationDir, paletteBinFileName)
        if (includePaletteBin) {
            pBin.writeBytes(palette.toBgr555Binary())
        }

        val idx = File(destinationDir, indexFileName)
        if (includeIndexFile) {
            idx.writeText(AtlasIndexGenerator.generate(atlas, baseName))
        }

        val png = File(destinationDir, pngFileName)
        if (includePng) {
            dev.secondsun.superx.tools.packer.ui.TextureRenderer.writeAtlasPng(atlas, palette, png)
        }

        return ExportedAssets(gBin, pBin, idx, png)
    }

    fun saveProject(
        projectFile: File,
        projectName: String,
        atlas: TextureAtlas,
        palette: SnesPalette,
        gridSnap: Int
    ) {
        val paletteDtos = palette.slots.mapIndexed { idx, slot ->
            ProjectColorDto(
                index = idx,
                r = slot.color.r,
                g = slot.color.g,
                b = slot.color.b,
                assigned = slot.isAssigned
            )
        }

        val textureDtos = atlas.textures.map { tex ->
            ProjectTextureDto(
                name = tex.name,
                width = tex.width,
                height = tex.height,
                x = tex.x,
                y = tex.y,
                pixelsHex = pixelsToHex(tex.indexedPixels),
                pixelsAscii = pixelsToAscii(tex.indexedPixels, tex.width, tex.height)
            )
        }

        val sliceDtos = atlas.slices.map {
            ProjectSliceDto(
                name = it.name,
                sourceTexture = it.sourceTexture,
                x = it.x,
                y = it.y,
                width = it.width,
                height = it.height
            )
        }

        val aliasDtos = atlas.aliases.map {
            ProjectAliasDto(
                name = it.name,
                target = it.target
            )
        }

        val dto = ProjectDto(
            name = projectName,
            atlasWidth = atlas.width,
            atlasHeight = atlas.height,
            gridSnap = gridSnap,
            palette = paletteDtos,
            textures = textureDtos,
            slices = if (sliceDtos.isNotEmpty()) sliceDtos else null,
            aliases = if (aliasDtos.isNotEmpty()) aliasDtos else null,
            descriptorOrder = atlas.descriptorOrder
        )

        // Write .sfxproj JSON
        projectFile.parentFile?.mkdirs()
        projectFile.writeText(gson.toJson(dto))

        // Write companion files
        val parentDir = projectFile.parentFile ?: File(".")
        val baseName = projectFile.nameWithoutExtension

        // Graphics binary
        val binBytes = atlas.generateBinary()
        File(parentDir, "$baseName.bin").writeBytes(binBytes)

        // Palette binary
        val palBytes = palette.toBgr555Binary()
        File(parentDir, "$baseName.pal").writeBytes(palBytes)

        // ca65 assembly index
        val indexText = AtlasIndexGenerator.generate(atlas, baseName)
        File(parentDir, "$baseName.i").writeText(indexText)

        // Layout PNG
        val pngFile = File(parentDir, "${baseName}_atlas.png")
        dev.secondsun.superx.tools.packer.ui.TextureRenderer.writeAtlasPng(atlas, palette, pngFile)
    }

    fun loadProject(projectFile: File): Triple<TextureAtlas, SnesPalette, Int> {
        val json = projectFile.readText()
        val dto = gson.fromJson(json, ProjectDto::class.java)

        // Reconstruct palette
        var palette = SnesPalette()
        for (colorDto in dto.palette) {
            if (colorDto.index in 1..15) {
                palette = palette.withSlot(
                    colorDto.index,
                    SnesColor(colorDto.r, colorDto.g, colorDto.b),
                    assigned = colorDto.assigned
                )
            }
        }

        // Reconstruct textures (prefer pixelsAscii when present so hand-authored ASCII edits take precedence)
        val textures = dto.textures.map { texDto ->
            val pixels = if (texDto.pixelsAscii != null && texDto.pixelsAscii.isNotBlank()) {
                asciiToPixels(texDto.pixelsAscii, texDto.width, texDto.height)
            } else {
                hexToPixels(texDto.pixelsHex, texDto.width, texDto.height)
            }

            SourceTexture(
                name = texDto.name,
                width = texDto.width,
                height = texDto.height,
                x = texDto.x,
                y = texDto.y,
                indexedPixels = pixels
            )
        }

        val slices = dto.slices?.map {
            VirtualSlice(
                name = it.name,
                sourceTexture = it.sourceTexture,
                x = it.x,
                y = it.y,
                width = it.width,
                height = it.height
            )
        } ?: emptyList()

        val aliases = dto.aliases?.map {
            DescriptorAlias(
                name = it.name,
                target = it.target
            )
        } ?: emptyList()

        val atlas = TextureAtlas(
            width = dto.atlasWidth,
            height = dto.atlasHeight,
            textures = textures,
            slices = slices,
            aliases = aliases,
            descriptorOrder = dto.descriptorOrder
        )

        return Triple(atlas, palette, dto.gridSnap)
    }
}
