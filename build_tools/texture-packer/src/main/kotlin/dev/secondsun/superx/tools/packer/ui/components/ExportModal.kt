package dev.secondsun.superx.tools.packer.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import dev.secondsun.superx.tools.packer.model.SourceTexture
import dev.secondsun.superx.tools.packer.ui.PackerState
import java.io.File
import javax.swing.JFileChooser

@Composable
fun ExportModal(state: PackerState) {
    if (!state.showExportModal) return

    val defaultDir = remember {
        state.lastExportDirectory
            ?: state.currentProjectFile?.parentFile?.absolutePath
            ?: state.lastImportDirectory
            ?: File(".").absolutePath
    }

    var exportDir by remember { mutableStateOf(defaultDir) }
    var baseName by remember { mutableStateOf(state.projectName) }

    var incGraphics by remember { mutableStateOf(true) }
    var incPalette by remember { mutableStateOf(true) }
    var incIndex by remember { mutableStateOf(true) }
    var incPng by remember { mutableStateOf(true) }

    val cleanBase = remember(baseName) {
        SourceTexture.sanitizeToIdentifier(baseName.trim().ifEmpty { "TEXTURES" })
    }

    Dialog(onDismissRequest = { state.showExportModal = false }) {
        Surface(
            modifier = Modifier.width(620.dp).wrapContentHeight(),
            shape = RoundedCornerShape(8.dp),
            color = Color(0xFF22242B)
        ) {
            Column(modifier = Modifier.padding(20.dp)) {
                Text(
                    text = "Export Texture Assets",
                    style = MaterialTheme.typography.h6,
                    color = Color.White
                )
                Text(
                    text = "Export production binaries, ca65 assembly descriptor index, and layout PNG",
                    color = Color(0xFF94A3B8),
                    fontSize = 12.sp
                )

                Spacer(modifier = Modifier.height(16.dp))

                // Directory Selection
                Text("Export Directory:", color = Color.White, fontSize = 12.sp)
                Spacer(modifier = Modifier.height(4.dp))
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    OutlinedTextField(
                        value = exportDir,
                        onValueChange = { exportDir = it },
                        singleLine = true,
                        colors = TextFieldDefaults.outlinedTextFieldColors(
                            textColor = Color.White,
                            cursorColor = Color.White,
                            focusedBorderColor = Color(0xFF3B82F6),
                            unfocusedBorderColor = Color(0xFF4B5563)
                        ),
                        modifier = Modifier.weight(1f).height(48.dp)
                    )

                    Button(
                        onClick = {
                            val chooser = JFileChooser().apply {
                                fileSelectionMode = JFileChooser.DIRECTORIES_ONLY
                                dialogTitle = "Select Export Directory"
                                val cur = File(exportDir)
                                if (cur.isDirectory) currentDirectory = cur
                            }
                            val res = chooser.showOpenDialog(null)
                            if (res == JFileChooser.APPROVE_OPTION && chooser.selectedFile != null) {
                                exportDir = chooser.selectedFile.absolutePath
                            }
                        },
                        colors = ButtonDefaults.buttonColors(backgroundColor = Color(0xFF3B82F6)),
                        modifier = Modifier.height(48.dp)
                    ) {
                        Text("Browse...", color = Color.White, fontSize = 12.sp)
                    }
                }

                Spacer(modifier = Modifier.height(12.dp))

                // Base Identifier
                Text("Base Name:", color = Color.White, fontSize = 12.sp)
                Spacer(modifier = Modifier.height(4.dp))
                OutlinedTextField(
                    value = baseName,
                    onValueChange = { baseName = it },
                    singleLine = true,
                    colors = TextFieldDefaults.outlinedTextFieldColors(
                        textColor = Color.White,
                        cursorColor = Color.White,
                        focusedBorderColor = Color(0xFF3B82F6),
                        unfocusedBorderColor = Color(0xFF4B5563)
                    ),
                    modifier = Modifier.fillMaxWidth().height(48.dp)
                )

                Spacer(modifier = Modifier.height(16.dp))

                // Files to Export List
                Text("Files to Generate:", color = Color.White, fontSize = 12.sp)
                Spacer(modifier = Modifier.height(6.dp))

                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .background(Color(0xFF1E2026), RoundedCornerShape(6.dp))
                        .border(1.dp, Color(0xFF33363D), RoundedCornerShape(6.dp))
                        .padding(8.dp),
                    verticalArrangement = Arrangement.spacedBy(6.dp)
                ) {
                    // Graphics Binary
                    ExportFileRow(
                        checked = incGraphics,
                        onCheckedChange = { incGraphics = it },
                        fileName = "${cleanBase}_graphics.bin",
                        description = "Packed texture atlas binary (${state.atlas.sizeBytes} bytes, 1 byte/texel)"
                    )

                    Divider(color = Color(0xFF2A2D34))

                    // Palette Binary
                    ExportFileRow(
                        checked = incPalette,
                        onCheckedChange = { incPalette = it },
                        fileName = "${cleanBase}_palette.bin",
                        description = "SNES BGR555 palette binary (32 bytes, 16 words)"
                    )

                    Divider(color = Color(0xFF2A2D34))

                    // ca65 Index File
                    ExportFileRow(
                        checked = incIndex,
                        onCheckedChange = { incIndex = it },
                        fileName = "${cleanBase}.i",
                        description = "ca65 assembly header with dimensions, bitmasks, and TEXTURE_TABLE"
                    )

                    Divider(color = Color(0xFF2A2D34))

                    // Layout PNG
                    ExportFileRow(
                        checked = incPng,
                        onCheckedChange = { incPng = it },
                        fileName = "${cleanBase}_atlas.png",
                        description = "Laid out atlas image (${state.atlas.width}x${state.atlas.height} ARGB PNG with transparent slot 0)"
                    )
                }

                Spacer(modifier = Modifier.height(20.dp))

                // Action Buttons
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.End,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    TextButton(onClick = { state.showExportModal = false }) {
                        Text("Cancel", color = Color(0xFF94A3B8))
                    }

                    Spacer(modifier = Modifier.width(8.dp))

                    val canExport = (incGraphics || incPalette || incIndex || incPng) && exportDir.isNotBlank()
                    Button(
                        onClick = {
                            val targetDir = File(exportDir)
                            val ok = state.exportAllAssets(
                                destinationDir = targetDir,
                                baseName = cleanBase,
                                graphicsBinFileName = "${cleanBase}_graphics.bin",
                                paletteBinFileName = "${cleanBase}_palette.bin",
                                indexFileName = "${cleanBase}.i",
                                pngFileName = "${cleanBase}_atlas.png",
                                includeGraphicsBin = incGraphics,
                                includePaletteBin = incPalette,
                                includeIndexFile = incIndex,
                                includePng = incPng
                            )
                            if (ok) {
                                state.showExportModal = false
                            }
                        },
                        enabled = canExport,
                        colors = ButtonDefaults.buttonColors(backgroundColor = Color(0xFF059669)) // Emerald Green
                    ) {
                        Text("Export Selected", color = Color.White)
                    }
                }
            }
        }
    }
}

@Composable
private fun ExportFileRow(
    checked: Boolean,
    onCheckedChange: (Boolean) -> Unit,
    fileName: String,
    description: String
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(4.dp))
            .clickable { onCheckedChange(!checked) }
            .padding(horizontal = 6.dp, vertical = 4.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Checkbox(
            checked = checked,
            onCheckedChange = onCheckedChange,
            colors = CheckboxDefaults.colors(
                checkedColor = Color(0xFF3B82F6),
                uncheckedColor = Color(0xFF64748B),
                checkmarkColor = Color.White
            )
        )

        Spacer(modifier = Modifier.width(6.dp))

        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = fileName,
                color = if (checked) Color(0xFF67E8F9) else Color(0xFF64748B),
                fontFamily = FontFamily.Monospace,
                fontSize = 12.sp
            )
            Text(
                text = description,
                color = if (checked) Color(0xFF94A3B8) else Color(0xFF475569),
                fontSize = 11.sp
            )
        }
    }
}

