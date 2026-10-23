package dev.secondsun.superx.tools.packer.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.*
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import dev.secondsun.superx.tools.packer.model.AtlasIndexGenerator
import dev.secondsun.superx.tools.packer.ui.PackerState
import java.awt.Toolkit
import java.awt.datatransfer.StringSelection

@Composable
fun IndexPreviewTab(state: PackerState, modifier: Modifier = Modifier) {
    val indexContent = remember(state.atlas, state.projectName) {
        AtlasIndexGenerator.generate(state.atlas, state.projectName)
    }

    Column(
        modifier = modifier
            .fillMaxSize()
            .background(Color(0xFF181A1F))
            .padding(12.dp)
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                text = "ca65 Atlas Index (${state.projectName}.i)",
                style = MaterialTheme.typography.subtitle1,
                color = Color.White
            )

            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Button(
                    onClick = { state.promptExportIndexFile() },
                    colors = ButtonDefaults.buttonColors(backgroundColor = Color(0xFF059669)),
                    modifier = Modifier.height(32.dp),
                    contentPadding = PaddingValues(horizontal = 8.dp)
                ) {
                    Text("Export .i File...", color = Color.White, fontSize = 12.sp)
                }

                Button(
                    onClick = {
                        val selection = StringSelection(indexContent)
                        Toolkit.getDefaultToolkit().systemClipboard.setContents(selection, selection)
                        state.statusMessage = "Copied ca65 .i index to clipboard"
                    },
                    colors = ButtonDefaults.buttonColors(backgroundColor = Color(0xFF3B82F6)),
                    modifier = Modifier.height(32.dp),
                    contentPadding = PaddingValues(horizontal = 8.dp)
                ) {
                    Text("Copy to Clipboard", color = Color.White, fontSize = 12.sp)
                }
            }
        }

        Spacer(modifier = Modifier.height(8.dp))

        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(Color(0xFF1E2026), RoundedCornerShape(4.dp))
                .border(1.dp, Color(0xFF33363D), RoundedCornerShape(4.dp))
                .padding(12.dp)
                .verticalScroll(rememberScrollState())
        ) {
            Text(
                text = indexContent,
                color = Color(0xFFE2E8F0),
                fontFamily = FontFamily.Monospace,
                fontSize = 12.sp,
                lineHeight = 18.sp
            )
        }
    }
}

