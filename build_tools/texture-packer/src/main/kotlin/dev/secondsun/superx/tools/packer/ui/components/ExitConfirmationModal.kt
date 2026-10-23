package dev.secondsun.superx.tools.packer.ui.components

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import dev.secondsun.superx.tools.packer.ui.PackerState
import java.awt.FileDialog
import java.awt.Frame
import java.io.File

@Composable
fun ExitConfirmationModal(state: PackerState, onConfirmExit: () -> Unit) {
    if (!state.showExitConfirmationModal) return

    Dialog(onDismissRequest = { state.showExitConfirmationModal = false }) {
        Surface(
            modifier = Modifier.width(460.dp).wrapContentHeight(),
            shape = RoundedCornerShape(8.dp),
            color = Color(0xFF22242B)
        ) {
            Column(modifier = Modifier.padding(20.dp)) {
                Text(
                    text = "Unsaved Changes",
                    style = MaterialTheme.typography.h6,
                    color = Color.White
                )

                Spacer(modifier = Modifier.height(10.dp))

                Text(
                    text = "You have unsaved changes in '${state.projectName}'. Do you want to save your changes before exiting?",
                    color = Color(0xFFCBD5E1),
                    fontSize = 13.sp,
                    lineHeight = 18.sp
                )

                Spacer(modifier = Modifier.height(20.dp))

                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.End,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    // Cancel
                    TextButton(
                        onClick = { state.showExitConfirmationModal = false }
                    ) {
                        Text("Cancel", color = Color(0xFF94A3B8))
                    }

                    Spacer(modifier = Modifier.width(8.dp))

                    // Discard and Exit
                    OutlinedButton(
                        onClick = {
                            state.showExitConfirmationModal = false
                            onConfirmExit()
                        },
                        colors = ButtonDefaults.outlinedButtonColors(
                            contentColor = Color(0xFFEF4444)
                        )
                    ) {
                        Text("Discard & Exit", color = Color(0xFFEF4444))
                    }

                    Spacer(modifier = Modifier.width(8.dp))

                    // Save and Exit
                    Button(
                        onClick = {
                            val saved = if (state.currentProjectFile != null) {
                                state.saveProject()
                            } else {
                                val dialog = FileDialog(null as Frame?, "Save Texture Project", FileDialog.SAVE)
                                dialog.file = "${state.projectName}.sfxproj"
                                dialog.isVisible = true
                                val file = dialog.file?.let { File(dialog.directory, it) }
                                if (file != null) {
                                    state.saveProject(file)
                                } else {
                                    false
                                }
                            }
                            if (saved) {
                                state.showExitConfirmationModal = false
                                onConfirmExit()
                            }
                        },
                        colors = ButtonDefaults.buttonColors(
                            backgroundColor = Color(0xFF3B82F6)
                        )
                    ) {
                        Text("Save & Exit", color = Color.White)
                    }
                }
            }
        }
    }
}

