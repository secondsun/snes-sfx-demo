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

data class ProjectTextureDto(
    val name: String,
    val width: Int,
    val height: Int,
    val x: Int,
    val y: Int,
    val pixelsHex: String
)

data class ProjectDto(
    val name: String,
    val atlasWidth: Int,
    val atlasHeight: Int,
    val gridSnap: Int,
    val palette: List<ProjectColorDto>,
    val textures: List<ProjectTextureDto>
)

data class ExportedAssets(
    val graphicsBinFile: File,
    val paletteBinFile: File,
    val indexFile: File,
    val pngFile: File
)

object ProjectService {
    private val gson: Gson = GsonBuilder().setPrettyPrinting().create()

    fun exportAssets(
        destinationDir: File,
        baseName: String,
        atlas: TextureAtlas,
        palette: SnesPalette,
        graphicsBinFileName: String = "${baseName}_graphics.bin",
        paletteBinFileName: String = "${baseName}_palette.bin",
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
            val hexSb = StringBuilder(tex.indexedPixels.size * 2)
            for (b in tex.indexedPixels) {
                hexSb.append(String.format("%02X", b.toInt() and 0x0F))
            }
            ProjectTextureDto(
                name = tex.name,
                width = tex.width,
                height = tex.height,
                x = tex.x,
                y = tex.y,
                pixelsHex = hexSb.toString()
            )
        }

        val dto = ProjectDto(
            name = projectName,
            atlasWidth = atlas.width,
            atlasHeight = atlas.height,
            gridSnap = gridSnap,
            palette = paletteDtos,
            textures = textureDtos
        )

        // Write .sfxproj JSON
        projectFile.parentFile?.mkdirs()
        projectFile.writeText(gson.toJson(dto))

        // Write companion files:
        val parentDir = projectFile.parentFile ?: File(".")
        val baseName = projectFile.nameWithoutExtension

        // Graphics binaries
        val binFile = File(parentDir, "$baseName.bin")
        binFile.writeBytes(atlas.generateBinary())
        val graphicsBinFile = File(parentDir, "${baseName}_graphics.bin")
        graphicsBinFile.writeBytes(atlas.generateBinary())

        // Palette binaries
        val palFile = File(parentDir, "$baseName.pal")
        palFile.writeBytes(palette.toBgr555Binary())
        val paletteBinFile = File(parentDir, "${baseName}_palette.bin")
        paletteBinFile.writeBytes(palette.toBgr555Binary())

        // ca65 assembly index
        val indexFile = File(parentDir, "$baseName.i")
        indexFile.writeText(AtlasIndexGenerator.generate(atlas, baseName))

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

        // Reconstruct textures
        val textures = dto.textures.map { texDto ->
            val pixels = ByteArray(texDto.width * texDto.height)
            val hex = texDto.pixelsHex
            for (i in pixels.indices) {
                val hexByte = if (i * 2 + 1 < hex.length) {
                    hex.substring(i * 2, i * 2 + 2).toIntOrNull(16) ?: 0
                } else {
                    0
                }
                pixels[i] = (hexByte and 0x0F).toByte()
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

        val atlas = TextureAtlas(
            width = dto.atlasWidth,
            height = dto.atlasHeight,
            textures = textures
        )

        return Triple(atlas, palette, dto.gridSnap)
    }
}

