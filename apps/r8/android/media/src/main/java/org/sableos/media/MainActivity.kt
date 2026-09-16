package org.sableos.media

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import org.sableos.design.SableTheme

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            SableTheme {
                var stationUrl by remember { mutableStateOf("") }
                var status by remember { mutableStateOf("Ready") }
                val picker = rememberLauncherForActivityResult(
                    ActivityResultContracts.OpenDocument(),
                ) { uri ->
                    if (uri != null) {
                        try {
                            contentResolver.takePersistableUriPermission(
                                uri,
                                Intent.FLAG_GRANT_READ_URI_PERMISSION,
                            )
                        } catch (_: SecurityException) {
                            // Some providers grant only transient access; playback still gets this URI.
                        }
                        playUri(uri)
                        status = "Playing local audio"
                    }
                }

                Surface(modifier = Modifier.fillMaxSize()) {
                    Column(
                        modifier = Modifier.padding(24.dp),
                        verticalArrangement = Arrangement.spacedBy(14.dp),
                    ) {
                        Text("Sable Media", style = MaterialTheme.typography.headlineLarge)
                        Text("Music")
                        Button(onClick = { picker.launch(arrayOf("audio/*")) }) {
                            Text("Choose local audio")
                        }
                        Text("Internet Radio")
                        OutlinedTextField(
                            value = stationUrl,
                            onValueChange = { stationUrl = it },
                            modifier = Modifier.fillMaxWidth(),
                            singleLine = true,
                            label = { Text("HTTP(S) stream URL") },
                        )
                        Button(
                            onClick = {
                                val candidate = stationUrl.trim()
                                if (candidate.startsWith("http://") || candidate.startsWith("https://")) {
                                    playUri(Uri.parse(candidate))
                                    status = "Playing radio stream"
                                } else {
                                    status = "Enter an HTTP or HTTPS station URL"
                                }
                            },
                        ) { Text("Play station") }
                        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            Button(onClick = { sendPlaybackAction(PlaybackService.ACTION_PAUSE) }) { Text("Pause") }
                            Button(onClick = { sendPlaybackAction(PlaybackService.ACTION_RESUME) }) { Text("Resume") }
                            Button(onClick = { sendPlaybackAction(PlaybackService.ACTION_STOP) }) { Text("Stop") }
                        }
                        Text(status, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        Text(
                            "Android Media3 owns decode, audio routing, focus and MediaSession lifecycle. " +
                                "The Rust media domain owns station-list parsing and file-header probing only.",
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                }
            }
        }
    }

    private fun playUri(uri: Uri) {
        startService(
            Intent(this, PlaybackService::class.java)
                .setAction(PlaybackService.ACTION_PLAY_URI)
                .setData(uri),
        )
    }

    private fun sendPlaybackAction(action: String) {
        startService(Intent(this, PlaybackService::class.java).setAction(action))
    }
}
