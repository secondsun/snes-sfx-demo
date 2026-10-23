package dev.secondsun.superx.tools.packer.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import dev.secondsun.superx.tools.packer.ui.PackerState

@Composable
fun AboutModal(state: PackerState) {
    if (!state.showAboutModal) return

    Dialog(onDismissRequest = { state.showAboutModal = false }) {
        Surface(
            modifier = Modifier.width(520.dp).height(440.dp),
            shape = RoundedCornerShape(8.dp),
            color = Color(0xFF22242B)
        ) {
            Column(modifier = Modifier.fillMaxSize().padding(20.dp)) {
                Text(
                    text = "SuperFX Texture Atlas Packer",
                    style = MaterialTheme.typography.h5,
                    color = Color.White
                )

                Text(
                    text = "Version 1.0 — Graphical Atlas & BGR555 Tool for SuperFX / IsoEngine",
                    color = Color(0xFF93C5FD),
                    fontSize = 12.sp
                )

                Spacer(modifier = Modifier.height(12.dp))

                Column(
                    modifier = Modifier
                        .weight(1f)
                        .background(Color(0xFF16181D), RoundedCornerShape(4.dp))
                        .padding(12.dp)
                        .verticalScroll(rememberScrollState()),
                    verticalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    Text(
                        text = "About This Program",
                        style = MaterialTheme.typography.subtitle2,
                        color = Color.White
                    )
                    Text(
                        text = "Converts, layouts, and packs power-of-two source bitmap graphics into an unpacked 1-byte-per-texel Texture Atlas (.bin), a 32-byte SNES BGR555 palette (.pal with $0001 black), and ca65 assembly include file (.i) with texture_descriptor tables for SuperFX polygon rasterization.",
                        color = Color.LightGray,
                        fontSize = 12.sp
                    )

                    Spacer(modifier = Modifier.height(8.dp))

                    Text(
                        text = "Open Source License",
                        style = MaterialTheme.typography.subtitle2,
                        color = Color.White
                    )
                    Text(
                        text = """
                            Licensed under the Apache License, Version 2.0 (the "License");
                            you may not use this file except in compliance with the License.
                            You may obtain a copy of the License at

                                http://www.apache.org/licenses/LICENSE-2.0

                            Unless required by applicable law or agreed to in writing, software
                            distributed under the License is distributed on an "AS IS" BASIS,
                            WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
                            See the License for the specific language governing permissions and
                            limitations under the License.
                        """.trimIndent(),
                        color = Color(0xFF94A3B8),
                        fontSize = 11.sp
                    )

                    Spacer(modifier = Modifier.height(8.dp))

                    Text(
                        text = "Third-Party Components",
                        style = MaterialTheme.typography.subtitle2,
                        color = Color.White
                    )
                    Text(
                        text = "• JetBrains Compose Multiplatform Desktop (Apache 2.0)\n• JetBrains Skiko Graphics Engine (Apache 2.0)\n• Kotlin Standard Library (Apache 2.0)\n• Google Gson (Apache 2.0)\n• JUnit Jupiter (EPL 2.0)",
                        color = Color(0xFF94A3B8),
                        fontSize = 11.sp
                    )
                }

                Spacer(modifier = Modifier.height(12.dp))

                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.End
                ) {
                    Button(
                        onClick = { state.showAboutModal = false },
                        colors = ButtonDefaults.buttonColors(backgroundColor = Color(0xFF3B82F6))
                    ) {
                        Text("Close", color = Color.White)
                    }
                }
            }
        }
    }
}

