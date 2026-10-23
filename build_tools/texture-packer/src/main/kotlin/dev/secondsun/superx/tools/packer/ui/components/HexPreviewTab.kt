package dev.secondsun.superx.tools.packer.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.Button
import androidx.compose.material.ButtonDefaults
import androidx.compose.material.Divider
import androidx.compose.material.MaterialTheme
import androidx.compose.material.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import dev.secondsun.superx.tools.packer.ui.PackerState

@Composable
fun HexPreviewTab(state: PackerState, modifier: Modifier = Modifier) {
    val binBytes = remember(state.atlas) { state.atlas.generateBinary() }
    val palBytes = remember(state.palette) { state.palette.toBgr555Binary() }

    // Precalculate byte offset ranges belonging to selected texture
    val selectedOffsets = remember(state.atlas, state.selectedTextureIndex) {
        val set = mutableSetOf<Int>()
        val tex = state.selectedTexture
        if (tex != null) {
            for (v in 0 until tex.height) {
                val rowStart = (tex.y + v) * state.atlas.width + tex.x
                for (u in 0 until tex.width) {
                    set.add(rowStart + u)
                }
            }
        }
        set
    }

    Column(
        modifier = modifier
            .fillMaxSize()
            .background(Color(0xFF181A1F))
            .padding(12.dp)
    ) {
        // --- Palette Binary Header ---
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                text = "SNES BGR555 Palette Binary (${palBytes.size} bytes / 16 words)",
                style = MaterialTheme.typography.subtitle2,
                color = Color.White
            )

            Button(
                onClick = { state.promptExportPaletteBin() },
                colors = ButtonDefaults.buttonColors(backgroundColor = Color(0xFF059669)),
                modifier = Modifier.height(26.dp),
                contentPadding = PaddingValues(horizontal = 8.dp)
            ) {
                Text("Export Palette (.bin)...", color = Color.White, fontSize = 11.sp)
            }
        }
        Spacer(modifier = Modifier.height(4.dp))
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .background(Color(0xFF22242B), RoundedCornerShape(4.dp))
                .border(1.dp, Color(0xFF33363D), RoundedCornerShape(4.dp))
                .padding(8.dp),
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            for (slot in 0..15) {
                val low = palBytes[slot * 2].toInt() and 0xFF
                val high = palBytes[slot * 2 + 1].toInt() and 0xFF
                val word = (high shl 8) or low
                val isSelected = state.selectedPaletteSlot == slot

                Text(
                    text = String.format("%04X", word),
                    color = if (isSelected) Color.Yellow else Color(0xFF93C5FD),
                    fontFamily = FontFamily.Monospace,
                    fontSize = 11.sp
                )
            }
        }

        Spacer(modifier = Modifier.height(12.dp))
        Divider(color = Color(0xFF33363D))
        Spacer(modifier = Modifier.height(8.dp))

        // --- Atlas Binary Dump ---
        val selectedTexName = state.selectedTexture?.name
        val highlightInfo = if (selectedTexName != null) " (Highlighting '$selectedTexName')" else ""
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                text = "Texture Atlas Binary (${binBytes.size} bytes)$highlightInfo",
                style = MaterialTheme.typography.subtitle2,
                color = Color.White
            )

            Button(
                onClick = { state.promptExportGraphicsBin() },
                colors = ButtonDefaults.buttonColors(backgroundColor = Color(0xFF059669)),
                modifier = Modifier.height(26.dp),
                contentPadding = PaddingValues(horizontal = 8.dp)
            ) {
                Text("Export Graphics (.bin)...", color = Color.White, fontSize = 11.sp)
            }
        }
        Spacer(modifier = Modifier.height(4.dp))

        val rowCount = (binBytes.size + 15) / 16
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .background(Color(0xFF1E2026), RoundedCornerShape(4.dp))
                .border(1.dp, Color(0xFF33363D), RoundedCornerShape(4.dp))
                .padding(8.dp)
        ) {
            items(rowCount) { rowIndex ->
                val startOffset = rowIndex * 16

                Row(
                    modifier = Modifier.fillMaxWidth(),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    // Offset: 00000000:
                    Text(
                        text = String.format("%08X:  ", startOffset),
                        color = Color(0xFF6B7280),
                        fontFamily = FontFamily.Monospace,
                        fontSize = 12.sp
                    )

                    // 16 Hex bytes
                    for (col in 0..15) {
                        val offset = startOffset + col
                        if (offset < binBytes.size) {
                            val byteVal = binBytes[offset].toInt() and 0x0F
                            val isHighlighted = selectedOffsets.contains(offset)
                            val byteColor = when {
                                isHighlighted -> Color(0xFF38BDF8)
                                byteVal == 0 -> Color(0xFF4B5563) // transparent / 0
                                else -> Color(0xFFE2E8F0)
                            }
                            val bg = if (isHighlighted) Color(0x3338BDF8) else Color.Transparent

                            Box(
                                modifier = Modifier
                                    .background(bg, RoundedCornerShape(2.dp))
                                    .padding(horizontal = 2.dp)
                            ) {
                                Text(
                                    text = String.format("%02X", byteVal),
                                    color = byteColor,
                                    fontFamily = FontFamily.Monospace,
                                    fontSize = 12.sp
                                )
                            }
                        } else {
                            Text(
                                text = "  ",
                                fontFamily = FontFamily.Monospace,
                                fontSize = 12.sp,
                                modifier = Modifier.padding(horizontal = 2.dp)
                            )
                        }
                        if (col == 7) {
                            Text(" ", fontSize = 12.sp)
                        }
                    }

                    Spacer(modifier = Modifier.width(16.dp))

                    // ASCII preview
                    Text(
                        text = "|",
                        color = Color(0xFF4B5563),
                        fontFamily = FontFamily.Monospace,
                        fontSize = 12.sp
                    )
                    for (col in 0..15) {
                        val offset = startOffset + col
                        if (offset < binBytes.size) {
                            val byteVal = binBytes[offset].toInt() and 0x0F
                            val char = if (byteVal == 0) '.' else byteVal.toString(16)[0]
                            val isHighlighted = selectedOffsets.contains(offset)
                            Text(
                                text = char.toString(),
                                color = if (isHighlighted) Color(0xFF38BDF8) else Color(0xFF94A3B8),
                                fontFamily = FontFamily.Monospace,
                                fontSize = 12.sp
                            )
                        }
                    }
                    Text(
                        text = "|",
                        color = Color(0xFF4B5563),
                        fontFamily = FontFamily.Monospace,
                        fontSize = 12.sp
                    )
                }
            }
        }
    }
}

