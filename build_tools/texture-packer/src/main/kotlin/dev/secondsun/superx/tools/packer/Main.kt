package dev.secondsun.superx.tools.packer

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.key.Key
import androidx.compose.ui.input.key.KeyShortcut
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.DpSize
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.*
import dev.secondsun.superx.tools.packer.ui.*
import dev.secondsun.superx.tools.packer.ui.components.*
import java.awt.FileDialog
import java.awt.Frame
import java.io.File
import kotlin.system.exitProcess

fun main() {
    PlatformDpi.init()

    application {
        val state = remember { PackerState() }

        val windowState = rememberWindowState(
            width = 1200.dp,
            height = 800.dp,
            position = WindowPosition(Alignment.Center)
        )

        // Fallback: If AWT failed to apply high-DPI scaling natively on Linux/X11,
        // automatically scale the initial window size and Compose UI density.
        LaunchedEffect(Unit) {
            val detected = PlatformDpi.detectedPlatformScale.toFloat()
            if (detected > 1.2f) {
                val awtScale = try {
                    java.awt.GraphicsEnvironment.getLocalGraphicsEnvironment()
                        .defaultScreenDevice.defaultConfiguration.defaultTransform.scaleX.toFloat()
                } catch (_: Throwable) { 1.0f }

                if (awtScale <= 1.01f) {
                    windowState.size = DpSize(
                        (1200 * detected).dp,
                        (800 * detected).dp
                    )
                    state.uiScaleMultiplier = detected
                }
            }
        }

        Window(
            onCloseRequest = {
                if (state.hasUnsavedChanges) {
                    state.showExitConfirmationModal = true
                } else {
                    exitApplication()
                }
            },
            title = "SuperFX Texture Atlas Packer — ${state.projectName}${if (state.hasUnsavedChanges) " *" else ""}",
            state = windowState
        ) {
            val systemDensity = LocalDensity.current
            val effectiveDensity = remember(systemDensity, state.uiScaleMultiplier) {
                Density(
                    density = systemDensity.density * state.uiScaleMultiplier,
                    fontScale = systemDensity.fontScale * state.uiScaleMultiplier
                )
            }
        // --- Native Menu Bar ---
        MenuBar {
            Menu("File", mnemonic = 'F') {
                Item("New Project", shortcut = KeyShortcut(Key.N, ctrl = true)) {
                    state.newProject()
                }

                Item("Open Project...", shortcut = KeyShortcut(Key.O, ctrl = true)) {
                    val dialog = FileDialog(null as Frame?, "Open Texture Project", FileDialog.LOAD)
                    dialog.setFilenameFilter { _, name -> name.endsWith(".sfxproj", ignoreCase = true) }
                    dialog.isVisible = true
                    val file = dialog.file?.let { File(dialog.directory, it) }
                    if (file != null) {
                        state.openProject(file)
                    }
                }

                Item("Save Project", shortcut = KeyShortcut(Key.S, ctrl = true)) {
                    if (state.currentProjectFile != null) {
                        state.saveProject()
                    } else {
                        val dialog = FileDialog(null as Frame?, "Save Texture Project", FileDialog.SAVE)
                        dialog.file = "${state.projectName}.sfxproj"
                        dialog.isVisible = true
                        val file = dialog.file?.let { File(dialog.directory, it) }
                        if (file != null) {
                            state.saveProject(file)
                        }
                    }
                }

                Item("Save Project As...") {
                    val dialog = FileDialog(null as Frame?, "Save Texture Project As", FileDialog.SAVE)
                    dialog.file = "${state.projectName}.sfxproj"
                    dialog.isVisible = true
                    val file = dialog.file?.let { File(dialog.directory, it) }
                    if (file != null) {
                        state.saveProject(file)
                    }
                }

                Separator()

                Item("Export Assets...", shortcut = KeyShortcut(Key.E, ctrl = true)) {
                    state.showExportModal = true
                }

                Separator()

                Item("Import Bitmap...", shortcut = KeyShortcut(Key.I, ctrl = true)) {
                    state.promptImportFile()
                }

                Separator()

                Item("About") {
                    state.showAboutModal = true
                }

                Separator()

                Item("Exit", shortcut = KeyShortcut(Key.Q, ctrl = true)) {
                    if (state.hasUnsavedChanges) {
                        state.showExitConfirmationModal = true
                    } else {
                        exitProcess(0)
                    }
                }
            }

            Menu("View", mnemonic = 'V') {
                Item("Zoom In (UI)", shortcut = KeyShortcut(Key.Equals, ctrl = true)) {
                    state.zoomInUi()
                }

                Item("Zoom Out (UI)", shortcut = KeyShortcut(Key.Minus, ctrl = true)) {
                    state.zoomOutUi()
                }

                Item("Reset UI Scale (100%)", shortcut = KeyShortcut(Key.Zero, ctrl = true)) {
                    state.resetUiScale()
                }

                Separator()

                Item("UI Scale: 100%") { state.setUiScale(1.0f) }
                Item("UI Scale: 125%") { state.setUiScale(1.25f) }
                Item("UI Scale: 150%") { state.setUiScale(1.5f) }
                Item("UI Scale: 175%") { state.setUiScale(1.75f) }
                Item("UI Scale: 200%") { state.setUiScale(2.0f) }
                Item("UI Scale: 250%") { state.setUiScale(2.5f) }
            }
        }

        // --- Dark Material Theme Application ---
        CompositionLocalProvider(LocalDensity provides effectiveDensity) {
            MaterialTheme(
                colors = darkColors(
                    primary = Color(0xFF3B82F6),
                    primaryVariant = Color(0xFF1D4ED8),
                    secondary = Color(0xFF10B981),
                    background = Color(0xFF181A1F),
                    surface = Color(0xFF22242B),
                    onPrimary = Color.White,
                    onSecondary = Color.White,
                    onBackground = Color.White,
                    onSurface = Color.White
                )
            ) {
                Column(modifier = Modifier.fillMaxSize().background(Color(0xFF181A1F))) {
                    // Main split pane: Left (Textures + Palette), Right (3 Tabs)
                    Row(modifier = Modifier.weight(1f).fillMaxWidth()) {
                        LeftPane(state = state)

                        Column(modifier = Modifier.weight(1f).fillMaxHeight()) {
                            // Right Tab Selector & Export Button
                            Row(
                                modifier = Modifier.fillMaxWidth().background(Color(0xFF22242B)),
                                horizontalArrangement = Arrangement.SpaceBetween,
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                TabRow(
                                    selectedTabIndex = state.activeTab.ordinal,
                                    modifier = Modifier.weight(1f),
                                    backgroundColor = Color(0xFF22242B),
                                    contentColor = Color(0xFF60A5FA)
                                ) {
                                    Tab(
                                        selected = state.activeTab == PackerTab.LAYOUT,
                                        onClick = { state.activeTab = PackerTab.LAYOUT },
                                        text = { Text("Layout Editor") }
                                    )
                                    Tab(
                                        selected = state.activeTab == PackerTab.HEX_PREVIEW,
                                        onClick = { state.activeTab = PackerTab.HEX_PREVIEW },
                                        text = { Text("Hex Preview") }
                                    )
                                    Tab(
                                        selected = state.activeTab == PackerTab.INDEX_PREVIEW,
                                        onClick = { state.activeTab = PackerTab.INDEX_PREVIEW },
                                        text = { Text("Index File Preview (.i)") }
                                    )
                                }

                                Button(
                                    onClick = { state.showExportModal = true },
                                    colors = ButtonDefaults.buttonColors(backgroundColor = Color(0xFF059669)),
                                    modifier = Modifier.padding(end = 12.dp).height(32.dp),
                                    contentPadding = PaddingValues(horizontal = 10.dp)
                                ) {
                                    Text("Export Assets...", color = Color.White, fontSize = 12.sp)
                                }
                            }

                            // Tab Content
                            Box(modifier = Modifier.weight(1f).fillMaxWidth()) {
                                when (state.activeTab) {
                                    PackerTab.LAYOUT -> LayoutTab(state)
                                    PackerTab.HEX_PREVIEW -> HexPreviewTab(state)
                                    PackerTab.INDEX_PREVIEW -> IndexPreviewTab(state)
                                }
                            }
                        }
                    }

                    // --- Status Bar ---
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(26.dp)
                            .background(Color(0xFF111215))
                            .border(1.dp, Color(0xFF222428))
                            .padding(horizontal = 8.dp),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text(
                            text = state.statusMessage,
                            color = Color(0xFF94A3B8),
                            fontSize = 11.sp
                        )

                        Row(
                            horizontalArrangement = Arrangement.spacedBy(12.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            val pct = Math.round(effectiveDensity.density * 100)
                            Text(
                                text = "DPI Scale: ${pct}%",
                                color = Color(0xFF38BDF8),
                                fontSize = 11.sp
                            )

                            Text(
                                text = "Atlas: ${state.atlas.width}x${state.atlas.height} | Textures: ${state.atlas.textures.size} | Palette: ${state.palette.assignedCount}/15 assigned",
                                color = Color(0xFF64748B),
                                fontSize = 11.sp
                            )
                        }
                    }
                }

                // --- Dialog Modals ---
                TextureEditModal(state)
                PaletteRemappingModal(state)
                UnassignPromptModal(state)
                AboutModal(state)
                ExportModal(state)
                ExitConfirmationModal(state, onConfirmExit = ::exitApplication)

                // Error Dialog
                state.errorMessage?.let { errorText ->
                    AlertDialog(
                        onDismissRequest = { state.errorMessage = null },
                        title = { Text("Notice", color = Color.White) },
                        text = { Text(errorText, color = Color(0xFFEF4444)) },
                        confirmButton = {
                            Button(
                                onClick = { state.errorMessage = null },
                                colors = ButtonDefaults.buttonColors(backgroundColor = Color(0xFF3B82F6))
                            ) {
                                Text("OK", color = Color.White)
                            }
                        },
                        backgroundColor = Color(0xFF22242B),
                        shape = RoundedCornerShape(8.dp)
                    )
                }
            }
        }
    }
}
}

