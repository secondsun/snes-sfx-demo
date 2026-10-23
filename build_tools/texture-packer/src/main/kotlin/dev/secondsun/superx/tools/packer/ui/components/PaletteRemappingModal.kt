package dev.secondsun.superx.tools.packer.ui.components

import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import dev.secondsun.superx.tools.packer.model.SnesColor
import dev.secondsun.superx.tools.packer.model.TextureImporter
import dev.secondsun.superx.tools.packer.ui.PackerState
import dev.secondsun.superx.tools.packer.ui.TextureRenderer

@Composable
fun PaletteRemappingModal(state: PackerState) {
    val pending = state.pendingImport ?: return

    // Manual slot mapping per incoming color
    val manualMapping = remember {
        mutableStateMapOf<SnesColor, Int>().apply {
            for (color in pending.uniqueColors) {
                val existing = pending.currentPalette.findExactIndex(color)
                this[color] = existing ?: pending.currentPalette.findNearestAssignedIndex(color)
            }
        }
    }

    Dialog(onDismissRequest = { state.pendingImport = null }) {
        Surface(
            modifier = Modifier.width(720.dp).height(580.dp),
            shape = RoundedCornerShape(8.dp),
            color = Color(0xFF22242B)
        ) {
            Column(modifier = Modifier.fillMaxSize().padding(16.dp)) {
                Text(
                    text = "Palette Conflict & Color Remapping",
                    style = MaterialTheme.typography.h6,
                    color = Color.White
                )

                Text(
                    text = if (pending.unmappedColors.isNotEmpty()) {
                        "Importing '${pending.suggestedName}' requires ${pending.unmappedColors.size} more colors than available in the 16-color palette."
                    } else {
                        "Review color palette mapping across all textures."
                    },
                    color = Color(0xFFFBBF24),
                    fontSize = 12.sp
                )

                Spacer(modifier = Modifier.height(12.dp))

                // Gallery of all current textures
                Text(
                    text = "All Imported Textures Preview:",
                    style = MaterialTheme.typography.subtitle2,
                    color = Color.White
                )
                Spacer(modifier = Modifier.height(4.dp))
                LazyRow(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(90.dp)
                        .background(Color(0xFF16181D), RoundedCornerShape(4.dp))
                        .padding(8.dp),
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    items(state.atlas.textures) { tex ->
                        Column(horizontalAlignment = Alignment.CenterHorizontally) {
                            val bitmap = TextureRenderer.renderToImageBitmap(tex, state.palette)
                            Image(
                                bitmap = bitmap,
                                contentDescription = tex.name,
                                modifier = Modifier
                                    .size(56.dp)
                                    .border(1.dp, Color.Gray, RoundedCornerShape(2.dp))
                            )
                            Text(tex.name, color = Color.White, fontSize = 10.sp)
                        }
                    }
                }

                Spacer(modifier = Modifier.height(12.dp))

                // Automation Row
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Button(
                        onClick = { state.autoSnapImport(pending) },
                        colors = ButtonDefaults.buttonColors(backgroundColor = Color(0xFF2563EB))
                    ) {
                        Text("Auto-Snap to Existing Palette", color = Color.White, fontSize = 12.sp)
                    }

                    Button(
                        onClick = { state.globalQuantizeImport(pending) },
                        colors = ButtonDefaults.buttonColors(backgroundColor = Color(0xFF7C3AED))
                    ) {
                        Text("Global 15-Color Auto-Quantize", color = Color.White, fontSize = 12.sp)
                    }
                }

                Spacer(modifier = Modifier.height(12.dp))

                // Manual Color Mapping Table
                Text(
                    text = "Manual Incoming Color Mapping:",
                    style = MaterialTheme.typography.subtitle2,
                    color = Color.White
                )
                Spacer(modifier = Modifier.height(4.dp))

                Column(
                    modifier = Modifier
                        .weight(1f)
                        .fillMaxWidth()
                        .background(Color(0xFF1E2026), RoundedCornerShape(4.dp))
                        .padding(8.dp)
                        .verticalScroll(rememberScrollState()),
                    verticalArrangement = Arrangement.spacedBy(4.dp)
                ) {
                    pending.uniqueColors.forEach { color ->
                        val targetSlot = manualMapping[color] ?: 1

                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .background(Color(0xFF2A2D34), RoundedCornerShape(4.dp))
                                .padding(horizontal = 8.dp, vertical = 4.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            // Source color swatch
                            Box(
                                modifier = Modifier
                                    .size(24.dp)
                                    .clip(RoundedCornerShape(2.dp))
                                    .background(Color(color.rgb888 or (0xFF shl 24)))
                                    .border(1.dp, Color.White, RoundedCornerShape(2.dp))
                            )

                            Spacer(modifier = Modifier.width(8.dp))

                            Text(
                                text = "Color ${color.hexString}",
                                color = Color.White,
                                fontSize = 12.sp,
                                modifier = Modifier.width(120.dp)
                            )

                            Text("→ Map to Slot:", color = Color.LightGray, fontSize = 12.sp)

                            Spacer(modifier = Modifier.width(8.dp))

                            // Target Slot Dropdown
                            var dropdownExpanded by remember { mutableStateOf(false) }
                            Box {
                                Button(
                                    onClick = { dropdownExpanded = true },
                                    colors = ButtonDefaults.buttonColors(backgroundColor = Color(0xFF374151)),
                                    modifier = Modifier.height(26.dp),
                                    contentPadding = PaddingValues(horizontal = 6.dp)
                                ) {
                                    Text("Slot $targetSlot", color = Color.White, fontSize = 11.sp)
                                }

                                DropdownMenu(
                                    expanded = dropdownExpanded,
                                    onDismissRequest = { dropdownExpanded = false },
                                    modifier = Modifier.background(Color(0xFF2A2D34))
                                ) {
                                    for (slot in 0..15) {
                                        DropdownMenuItem(
                                            onClick = {
                                                manualMapping[color] = slot
                                                dropdownExpanded = false
                                            }
                                        ) {
                                            Row(verticalAlignment = Alignment.CenterVertically) {
                                                Box(
                                                    modifier = Modifier
                                                        .size(16.dp)
                                                        .background(
                                                            if (slot == 0) Color.Transparent else Color(state.palette[slot].argb)
                                                        )
                                                        .border(1.dp, Color.Gray)
                                                )
                                                Spacer(modifier = Modifier.width(6.dp))
                                                Text(
                                                    if (slot == 0) "Slot 0 (Transparent)" else "Slot $slot (${state.palette[slot].hexString})",
                                                    color = Color.White,
                                                    fontSize = 11.sp
                                                )
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Spacer(modifier = Modifier.height(12.dp))

                // Footer
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.End,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    TextButton(onClick = { state.pendingImport = null }) {
                        Text("Cancel", color = Color.LightGray)
                    }

                    Spacer(modifier = Modifier.width(8.dp))

                    Button(
                        onClick = {
                            if (pending.suggestedName != "ALL") {
                                val tex = TextureImporter.createTextureFromImage(
                                    image = pending.rawImage,
                                    name = pending.suggestedName,
                                    colorMapping = manualMapping,
                                    fallbackPalette = state.palette
                                )
                                // Place texture
                                val p = state.atlas.findPlacement(tex, state.gridSnap)
                                if (p != null) {
                                    state.atlas = state.atlas.withTexture(tex.copy(x = p.first, y = p.second))
                                    state.selectedTextureIndex = state.atlas.textures.size - 1
                                } else {
                                    state.atlas = state.atlas.withTexture(tex)
                                }
                            }
                            state.pendingImport = null
                        },
                        colors = ButtonDefaults.buttonColors(backgroundColor = Color(0xFF10B981))
                    ) {
                        Text("Apply Mapping", color = Color.White)
                    }
                }
            }
        }
    }
}

