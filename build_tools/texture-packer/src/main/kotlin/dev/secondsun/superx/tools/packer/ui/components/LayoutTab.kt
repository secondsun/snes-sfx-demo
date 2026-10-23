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
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import dev.secondsun.superx.tools.packer.ui.PackerState
import dev.secondsun.superx.tools.packer.ui.TextureRenderer

@Composable
fun LayoutTab(state: PackerState, modifier: Modifier = Modifier) {
    Column(modifier = modifier.fillMaxSize().background(Color(0xFF1E1E24))) {
        // --- Toolbar ---
        LayoutToolbar(state)

        Divider(color = Color(0xFF33363D))

        // --- Interactive Canvas Area ---
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(16.dp),
            contentAlignment = Alignment.Center
        ) {
            AtlasCanvas(state)
        }
    }
}

@Composable
private fun LayoutToolbar(state: PackerState) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .background(Color(0xFF282A30))
            .padding(horizontal = 12.dp, vertical = 6.dp),
        horizontalArrangement = Arrangement.spacedBy(16.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        // Atlas Dimensions
        Text("Atlas Size:", color = Color.White, fontSize = 12.sp)

        DimensionDropdown("W", state.atlas.width) { newW ->
            state.setAtlasDimensions(newW, state.atlas.height)
        }

        Text("x", color = Color.Gray, fontSize = 12.sp)

        DimensionDropdown("H", state.atlas.height) { newH ->
            state.setAtlasDimensions(state.atlas.width, newH)
        }

        Button(
            onClick = { state.autoFit() },
            colors = ButtonDefaults.buttonColors(backgroundColor = Color(0xFF374151)),
            modifier = Modifier.height(28.dp),
            contentPadding = PaddingValues(horizontal = 8.dp)
        ) {
            Text("Auto-Fit", color = Color.White, fontSize = 11.sp)
        }

        Button(
            onClick = { state.autoPack() },
            colors = ButtonDefaults.buttonColors(backgroundColor = Color(0xFF374151)),
            modifier = Modifier.height(28.dp),
            contentPadding = PaddingValues(horizontal = 8.dp)
        ) {
            Text("Auto-Pack", color = Color.White, fontSize = 11.sp)
        }

        Spacer(modifier = Modifier.width(8.dp))

        // Grid Snap Slider / Controls
        Text("Grid Snap: ${state.gridSnap}px", color = Color.White, fontSize = 12.sp)
        Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
            listOf(4, 8, 16).forEach { snap ->
                val isSelected = state.gridSnap == snap
                Button(
                    onClick = { state.gridSnap = snap },
                    colors = ButtonDefaults.buttonColors(
                        backgroundColor = if (isSelected) Color(0xFF2563EB) else Color(0xFF374151)
                    ),
                    modifier = Modifier.height(26.dp),
                    contentPadding = PaddingValues(horizontal = 6.dp)
                ) {
                    Text("${snap}px", color = Color.White, fontSize = 10.sp)
                }
            }
        }

        Spacer(modifier = Modifier.weight(1f))

        // Zoom Control
        Text("Zoom: ${state.zoom.toInt()}x", color = Color.White, fontSize = 12.sp)
        Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
            listOf(1f, 2f, 3f, 4f).forEach { z ->
                val isSelected = state.zoom == z
                Button(
                    onClick = { state.zoom = z },
                    colors = ButtonDefaults.buttonColors(
                        backgroundColor = if (isSelected) Color(0xFF2563EB) else Color(0xFF374151)
                    ),
                    modifier = Modifier.height(26.dp),
                    contentPadding = PaddingValues(horizontal = 6.dp)
                ) {
                    Text("${z.toInt()}x", color = Color.White, fontSize = 10.sp)
                }
            }
        }

        Spacer(modifier = Modifier.width(8.dp))

        Button(
            onClick = { state.promptExportPng() },
            colors = ButtonDefaults.buttonColors(backgroundColor = Color(0xFF059669)),
            modifier = Modifier.height(26.dp),
            contentPadding = PaddingValues(horizontal = 8.dp)
        ) {
            Text("Export PNG...", color = Color.White, fontSize = 11.sp)
        }
    }
}

@Composable
private fun DimensionDropdown(label: String, currentValue: Int, onSelected: (Int) -> Unit) {
    var expanded by remember { mutableStateOf(false) }
    val dimensions = listOf(16, 32, 64, 128, 256)

    Box {
        Button(
            onClick = { expanded = true },
            colors = ButtonDefaults.buttonColors(backgroundColor = Color(0xFF374151)),
            modifier = Modifier.height(28.dp),
            contentPadding = PaddingValues(horizontal = 6.dp)
        ) {
            Text("$label: $currentValue", color = Color.White, fontSize = 11.sp)
        }

        DropdownMenu(
            expanded = expanded,
            onDismissRequest = { expanded = false },
            modifier = Modifier.background(Color(0xFF2D3139))
        ) {
            dimensions.forEach { dim ->
                DropdownMenuItem(
                    onClick = {
                        expanded = false
                        onSelected(dim)
                    }
                ) {
                    Text("$dim", color = Color.White, fontSize = 12.sp)
                }
            }
        }
    }
}

@Composable
private fun AtlasCanvas(state: PackerState) {
    val zoom = state.zoom
    val canvasWidthDp = (state.atlas.width * zoom).dp
    val canvasHeightDp = (state.atlas.height * zoom).dp
    val density = LocalDensity.current
    val pixelsPerTexel = zoom * density.density

    // Drag tracking state
    var draggingTextureIndex by remember { mutableStateOf<Int?>(null) }
    var dragPixelOffset by remember { mutableStateOf(Offset.Zero) }

    Box(
        modifier = Modifier
            .size(canvasWidthDp, canvasHeightDp)
            .border(2.dp, Color(0xFF4F46E5), RoundedCornerShape(2.dp))
            .background(Color(0xFF111215))
            .pointerInput(state.atlas, zoom, state.gridSnap, density) {
                detectDragGestures(
                    onDragStart = { offset ->
                        val texX = (offset.x / pixelsPerTexel).toInt()
                        val texY = (offset.y / pixelsPerTexel).toInt()
                        // Find clicked texture (in reverse order, top of stack first)
                        for (i in state.atlas.textures.indices.reversed()) {
                            val tex = state.atlas.textures[i]
                            if (texX in tex.x until (tex.x + tex.width) &&
                                texY in tex.y until (tex.y + tex.height)
                            ) {
                                draggingTextureIndex = i
                                state.selectedTextureIndex = i
                                dragPixelOffset = Offset.Zero
                                break
                            }
                        }
                    },
                    onDrag = { change, dragAmount ->
                        change.consume()
                        if (draggingTextureIndex != null) {
                            dragPixelOffset += dragAmount
                        }
                    },
                    onDragEnd = {
                        val dragIdx = draggingTextureIndex
                        if (dragIdx != null && dragIdx in state.atlas.textures.indices) {
                            val tex = state.atlas.textures[dragIdx]
                            val rawTargetX = tex.x + (dragPixelOffset.x / pixelsPerTexel).toInt()
                            val rawTargetY = tex.y + (dragPixelOffset.y / pixelsPerTexel).toInt()
                            // Try moving (snap to grid, bounds check, collision check)
                            state.moveTexture(dragIdx, rawTargetX, rawTargetY)
                        }
                        draggingTextureIndex = null
                        dragPixelOffset = Offset.Zero
                    },
                    onDragCancel = {
                        draggingTextureIndex = null
                        dragPixelOffset = Offset.Zero
                    }
                )
            }
    ) {
        // Draw grid and placed textures
        Canvas(modifier = Modifier.fillMaxSize()) {
            val gridPx = (state.gridSnap * zoom).dp.toPx()
            val numCols = (size.width / gridPx).toInt()
            val numRows = (size.height / gridPx).toInt()

            // Subtle grid lines
            for (col in 1..numCols) {
                val x = col * gridPx
                drawLine(
                    color = Color(0x22FFFFFF),
                    start = Offset(x, 0f),
                    end = Offset(x, size.height),
                    strokeWidth = 1f
                )
            }
            for (row in 1..numRows) {
                val y = row * gridPx
                drawLine(
                    color = Color(0x22FFFFFF),
                    start = Offset(0f, y),
                    end = Offset(size.width, y),
                    strokeWidth = 1f
                )
            }
        }

        // Render placed textures as Compose sub-views
        state.atlas.textures.forEachIndexed { index, tex ->
            val isBeingDragged = draggingTextureIndex == index
            val isSelected = state.selectedTextureIndex == index

            val currentX = if (isBeingDragged) {
                val rawX = tex.x + (dragPixelOffset.x / pixelsPerTexel).toInt()
                val snappedX = (rawX / state.gridSnap) * state.gridSnap
                snappedX
            } else {
                tex.x
            }

            val currentY = if (isBeingDragged) {
                val rawY = tex.y + (dragPixelOffset.y / pixelsPerTexel).toInt()
                val snappedY = (rawY / state.gridSnap) * state.gridSnap
                snappedY
            } else {
                tex.y
            }

            val isValidCandidate = if (isBeingDragged) {
                state.atlas.canPlace(tex, currentX, currentY, excludeTextureIndex = index)
            } else {
                true
            }

            val borderColor = when {
                isBeingDragged && !isValidCandidate -> Color(0xFFEF4444) // Bright red on collision
                isBeingDragged -> Color(0xFF10B981) // Green while dragging validly
                isSelected -> Color(0xFF38BDF8) // Light blue when selected
                else -> Color(0x66FFFFFF)
            }

            Box(
                modifier = Modifier
                    .offset(x = (currentX * zoom).dp, y = (currentY * zoom).dp)
                    .size((tex.width * zoom).dp, (tex.height * zoom).dp)
                    .border(width = if (isSelected || isBeingDragged) 2.dp else 1.dp, color = borderColor)
            ) {
                val bitmap = TextureRenderer.renderToImageBitmap(tex, state.palette)
                Image(
                    bitmap = bitmap,
                    contentDescription = tex.name,
                    modifier = Modifier.fillMaxSize()
                )

                // Texture name tag
                Text(
                    text = tex.name,
                    color = Color.White,
                    fontSize = 9.sp,
                    modifier = Modifier
                        .background(Color(0xAA000000), RoundedCornerShape(2.dp))
                        .padding(horizontal = 2.dp)
                )
            }
        }
    }
}

