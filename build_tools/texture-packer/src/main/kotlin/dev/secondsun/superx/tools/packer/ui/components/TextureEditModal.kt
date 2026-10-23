package dev.secondsun.superx.tools.packer.ui.components

import androidx.compose.foundation.*
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import dev.secondsun.superx.tools.packer.model.SourceTexture
import dev.secondsun.superx.tools.packer.ui.PackerState
import java.util.ArrayDeque

private enum class EditTool {
    PENCIL,
    FLOOD_FILL,
    EYEDROPPER
}

@Composable
fun TextureEditModal(state: PackerState) {
    val editIdx = state.editingTextureIndex ?: return
    val originalTex = state.atlas.textures.getOrNull(editIdx) ?: run {
        state.editingTextureIndex = null
        return
    }

    var textureName by remember { mutableStateOf(originalTex.name) }
    var pixels by remember { mutableStateOf(originalTex.indexedPixels.copyOf()) }
    var activeSlot by remember { mutableStateOf(state.selectedPaletteSlot) }
    var activeTool by remember { mutableStateOf(EditTool.PENCIL) }
    var nameError by remember { mutableStateOf<String?>(null) }

    // Undo / Redo history
    val undoStack = remember { ArrayDeque<ByteArray>() }
    val redoStack = remember { ArrayDeque<ByteArray>() }

    fun pushUndo(current: ByteArray) {
        undoStack.push(current.copyOf())
        redoStack.clear()
    }

    fun floodFill(startX: Int, startY: Int, targetSlot: Int, fillSlot: Int) {
        if (targetSlot == fillSlot) return
        val w = originalTex.width
        val h = originalTex.height
        val queue = ArrayDeque<Pair<Int, Int>>()
        queue.add(Pair(startX, startY))

        val workingPixels = pixels.copyOf()
        while (queue.isNotEmpty()) {
            val (cx, cy) = queue.removeFirst()
            val idx = cy * w + cx
            if ((workingPixels[idx].toInt() and 0x0F) == targetSlot) {
                workingPixels[idx] = (fillSlot and 0x0F).toByte()
                if (cx > 0) queue.add(Pair(cx - 1, cy))
                if (cx < w - 1) queue.add(Pair(cx + 1, cy))
                if (cy > 0) queue.add(Pair(cx, cy - 1))
                if (cy < h - 1) queue.add(Pair(cx, cy + 1))
            }
        }
        pushUndo(pixels)
        pixels = workingPixels
    }

    Dialog(onDismissRequest = { state.editingTextureIndex = null }) {
        Surface(
            modifier = Modifier.width(680.dp).height(620.dp),
            shape = RoundedCornerShape(8.dp),
            color = Color(0xFF22242B)
        ) {
            Column(modifier = Modifier.fillMaxSize().padding(16.dp)) {
                // Header
                Text(
                    text = "Edit Source Texture: ${originalTex.name} (${originalTex.width}x${originalTex.height})",
                    style = MaterialTheme.typography.h6,
                    color = Color.White
                )

                Spacer(modifier = Modifier.height(12.dp))

                // Name TextField
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text("Symbol Name:", color = Color.White, fontSize = 12.sp, modifier = Modifier.width(100.dp))
                    OutlinedTextField(
                        value = textureName,
                        onValueChange = { input ->
                            textureName = input
                            nameError = if (!SourceTexture.isValidCa65Identifier(input)) {
                                "Must be a valid ca65 identifier ([A-Za-z_][A-Za-z0-9_]*)"
                            } else {
                                null
                            }
                        },
                        isError = nameError != null,
                        singleLine = true,
                        colors = TextFieldDefaults.outlinedTextFieldColors(
                            textColor = Color.White,
                            cursorColor = Color.White,
                            focusedBorderColor = Color(0xFF3B82F6),
                            unfocusedBorderColor = Color(0xFF4B5563)
                        ),
                        modifier = Modifier.weight(1f).height(50.dp)
                    )
                }
                if (nameError != null) {
                    Text(nameError!!, color = Color(0xFFEF4444), fontSize = 11.sp, modifier = Modifier.padding(start = 100.dp))
                }

                Spacer(modifier = Modifier.height(10.dp))

                // Tools & Color Bar
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    // Tool buttons
                    listOf(
                        EditTool.PENCIL to "Pencil",
                        EditTool.FLOOD_FILL to "Fill",
                        EditTool.EYEDROPPER to "Eyedrop"
                    ).forEach { (tool, label) ->
                        val isSelected = activeTool == tool
                        Button(
                            onClick = { activeTool = tool },
                            colors = ButtonDefaults.buttonColors(
                                backgroundColor = if (isSelected) Color(0xFF2563EB) else Color(0xFF374151)
                            ),
                            modifier = Modifier.height(30.dp),
                            contentPadding = PaddingValues(horizontal = 8.dp)
                        ) {
                            Text(label, color = Color.White, fontSize = 11.sp)
                        }
                    }

                    Spacer(modifier = Modifier.width(8.dp))

                    // Undo / Redo
                    Button(
                        onClick = {
                            if (undoStack.isNotEmpty()) {
                                redoStack.push(pixels.copyOf())
                                pixels = undoStack.pop()
                            }
                        },
                        enabled = undoStack.isNotEmpty(),
                        colors = ButtonDefaults.buttonColors(backgroundColor = Color(0xFF4B5563)),
                        modifier = Modifier.height(30.dp),
                        contentPadding = PaddingValues(horizontal = 8.dp)
                    ) {
                        Text("Undo", color = Color.White, fontSize = 11.sp)
                    }

                    Button(
                        onClick = {
                            if (redoStack.isNotEmpty()) {
                                undoStack.push(pixels.copyOf())
                                pixels = redoStack.pop()
                            }
                        },
                        enabled = redoStack.isNotEmpty(),
                        colors = ButtonDefaults.buttonColors(backgroundColor = Color(0xFF4B5563)),
                        modifier = Modifier.height(30.dp),
                        contentPadding = PaddingValues(horizontal = 8.dp)
                    ) {
                        Text("Redo", color = Color.White, fontSize = 11.sp)
                    }
                }

                Spacer(modifier = Modifier.height(8.dp))

                // Palette Swatches Selector
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(4.dp)
                ) {
                    for (slot in 0..15) {
                        val isSelected = activeSlot == slot
                        val color = state.palette[slot]
                        Box(
                            modifier = Modifier
                                .weight(1f)
                                .height(24.dp)
                                .clip(RoundedCornerShape(2.dp))
                                .background(
                                    if (slot == 0) Color.Transparent else Color(color.rgb888 or (0xFF shl 24))
                                )
                                .border(
                                    width = if (isSelected) 2.dp else 1.dp,
                                    color = if (isSelected) Color.Yellow else Color(0xFF6B7280),
                                    shape = RoundedCornerShape(2.dp)
                                )
                                .clickable { activeSlot = slot },
                            contentAlignment = Alignment.Center
                        ) {
                            if (slot == 0) Text("T", color = Color.Gray, fontSize = 9.sp)
                        }
                    }
                }

                Spacer(modifier = Modifier.height(10.dp))

                // Pixel Canvas
                Box(
                    modifier = Modifier
                        .weight(1f)
                        .fillMaxWidth()
                        .background(Color(0xFF16181D), RoundedCornerShape(4.dp))
                        .border(1.dp, Color(0xFF33363D), RoundedCornerShape(4.dp)),
                    contentAlignment = Alignment.Center
                ) {
                    val w = originalTex.width
                    val h = originalTex.height
                    val pixelSize = minOf(400 / maxOf(w, h), 24)

                    Box(
                        modifier = Modifier
                            .size((w * pixelSize).dp, (h * pixelSize).dp)
                            .border(1.dp, Color.Gray)
                            .pointerInput(w, h, activeTool, activeSlot) {
                                detectDragGestures(
                                    onDragStart = { offset ->
                                        val px = (offset.x / (pixelSize * density)).toInt().coerceIn(0, w - 1)
                                        val py = (offset.y / (pixelSize * density)).toInt().coerceIn(0, h - 1)
                                        val idx = py * w + px
                                        when (activeTool) {
                                            EditTool.PENCIL -> {
                                                pushUndo(pixels)
                                                val copy = pixels.copyOf()
                                                copy[idx] = (activeSlot and 0x0F).toByte()
                                                pixels = copy
                                            }
                                            EditTool.FLOOD_FILL -> {
                                                val target = pixels[idx].toInt() and 0x0F
                                                floodFill(px, py, target, activeSlot)
                                            }
                                            EditTool.EYEDROPPER -> {
                                                activeSlot = pixels[idx].toInt() and 0x0F
                                            }
                                        }
                                    },
                                    onDrag = { change, _ ->
                                        change.consume()
                                        if (activeTool == EditTool.PENCIL) {
                                            val px = (change.position.x / (pixelSize * density)).toInt().coerceIn(0, w - 1)
                                            val py = (change.position.y / (pixelSize * density)).toInt().coerceIn(0, h - 1)
                                            val idx = py * w + px
                                            if ((pixels[idx].toInt() and 0x0F) != activeSlot) {
                                                val copy = pixels.copyOf()
                                                copy[idx] = (activeSlot and 0x0F).toByte()
                                                pixels = copy
                                            }
                                        }
                                    }
                                )
                            }
                    ) {
                        Canvas(modifier = Modifier.fillMaxSize()) {
                            for (y in 0 until h) {
                                for (x in 0 until w) {
                                    val slot = pixels[y * w + x].toInt() and 0x0F
                                    val color = if (slot == 0) {
                                        // Checkerboard pattern for transparent
                                        if ((x + y) % 2 == 0) Color(0xFF2A2D35) else Color(0xFF1E2026)
                                    } else {
                                        Color(state.palette[slot].argb)
                                    }
                                    drawRect(
                                        color = color,
                                        topLeft = androidx.compose.ui.geometry.Offset(x * pixelSize.toFloat() * density, y * pixelSize.toFloat() * density),
                                        size = androidx.compose.ui.geometry.Size(pixelSize.toFloat() * density, pixelSize.toFloat() * density)
                                    )
                                }
                            }
                        }
                    }
                }

                Spacer(modifier = Modifier.height(12.dp))

                // Footer Actions
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.End,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    TextButton(onClick = { state.editingTextureIndex = null }) {
                        Text("Cancel", color = Color.LightGray)
                    }

                    Spacer(modifier = Modifier.width(8.dp))

                    Button(
                        onClick = {
                            if (nameError == null) {
                                val updated = originalTex.copy(
                                    name = textureName,
                                    indexedPixels = pixels
                                )
                                state.applyTextureEdit(editIdx, updated)
                            }
                        },
                        enabled = nameError == null,
                        colors = ButtonDefaults.buttonColors(backgroundColor = Color(0xFF2563EB))
                    ) {
                        Text("Apply Changes", color = Color.White)
                    }
                }
            }
        }
    }
}

