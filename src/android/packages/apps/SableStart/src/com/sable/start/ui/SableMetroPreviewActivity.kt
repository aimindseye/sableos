package org.sableos.start.ui

import android.Manifest
import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawing
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.Typography
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import kotlinx.coroutines.delay
import org.sableos.start.live.LiveAvailability
import org.sableos.start.live.LiveDatum
import org.sableos.start.live.LiveSurfaceSnapshot
import org.sableos.start.model.AppEntry
import org.sableos.start.platform.LauncherAppsRepository
import org.sableos.start.platform.LiveSurfaceRepository
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

/**
 * M1-R4A visual-only Sable Metro foundation.
 *
 * This Activity is intentionally additive and does not participate in HOME
 * intent resolution. It exists to render and physically qualify the approved
 * Sable Start design language before adopting it as the production HOME UI.
 */
class SableMetroPreviewActivity : ComponentActivity() {
    private var liveRefreshGeneration by mutableStateOf(0)

    private val launcherAppsRepository by lazy {
        LauncherAppsRepository(this)
    }

    private val liveSurfaceRepository by lazy {
        LiveSurfaceRepository(this)
    }

    private val filesEntry: AppEntry? by lazy {
        launcherAppsRepository
            .loadApps()
            .firstOrNull { entry -> entry.label.equals("Files", ignoreCase = true) }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            SableMetroPreviewApp(
                liveSurfaceRepository = liveSurfaceRepository,
                refreshGeneration = liveRefreshGeneration,
                onOpenFiles = ::openFiles,
                onOpenFilesAppInfo = ::openFilesAppInfo,
                onRequestLivePermissions = ::requestLivePermissions,
            )
        }
    }

    private fun openFiles() {
        val entry = filesEntry
        if (entry != null) {
            launcherAppsRepository.launch(entry)
            return
        }

        try {
            startActivity(
                Intent(Intent.ACTION_OPEN_DOCUMENT)
                    .addCategory(Intent.CATEGORY_OPENABLE)
                    .setType("*/*"),
            )
        } catch (_: ActivityNotFoundException) {
            // The live UI reports the missing route through the functional gate.
        }
    }

    private fun openFilesAppInfo() {
        val targetPackage = filesEntry?.component?.packageName ?: return
        try {
            startActivity(
                Intent(
                    Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                    Uri.parse("package:$targetPackage"),
                ),
            )
        } catch (_: ActivityNotFoundException) {
            // The device capability gate independently proves the Settings handler.
        }
    }

    private fun requestLivePermissions() {
        val permissions =
            buildList {
                add(Manifest.permission.READ_CALENDAR)
                if (Build.VERSION.SDK_INT >= 33) {
                    add(Manifest.permission.READ_MEDIA_IMAGES)
                    add(Manifest.permission.READ_MEDIA_AUDIO)
                } else {
                    add(Manifest.permission.READ_EXTERNAL_STORAGE)
                }
            }
        requestPermissions(permissions.toTypedArray(), LIVE_PERMISSION_REQUEST_CODE)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == LIVE_PERMISSION_REQUEST_CODE) {
            liveRefreshGeneration += 1
        }
    }

    private companion object {
        const val LIVE_PERMISSION_REQUEST_CODE = 0x534D
    }
}

private enum class PreviewScreen(val title: String) {
    Start("start"),
    Apps("apps"),
    Context("files"),
    Search("search"),
    Pinned("pinned"),
    Settings("settings"),
    Live("live"),
    Lock("lock"),
}

private data class DemoApp(
    val name: String,
    val mark: String,
    val color: Color,
)

private val SableBlue = Color(0xFF4D9CFF)
private val SableGreen = Color(0xFF35C66B)
private val SablePurple = Color(0xFF7A42E8)
private val SableSlate = Color(0xFF45515F)
private val SableOrange = Color(0xFFF28C45)
private val SablePanel = Color(0xFF17191D)
private val SablePanelRaised = Color(0xFF22252A)
private val SableMuted = Color(0xFFB8BBC3)

private val SableColors =
    darkColorScheme(
        primary = SableBlue,
        onPrimary = Color.Black,
        background = Color.Black,
        onBackground = Color.White,
        surface = SablePanel,
        onSurface = Color.White,
        surfaceVariant = SablePanelRaised,
        onSurfaceVariant = SableMuted,
    )

private val SableTypography =
    Typography(
        displayLarge =
            TextStyle(
                fontSize = 58.sp,
                lineHeight = 60.sp,
                fontWeight = FontWeight.Light,
                letterSpacing = (-1.2).sp,
            ),
        displayMedium =
            TextStyle(
                fontSize = 42.sp,
                lineHeight = 46.sp,
                fontWeight = FontWeight.Light,
                letterSpacing = (-0.6).sp,
            ),
        headlineLarge =
            TextStyle(
                fontSize = 34.sp,
                lineHeight = 40.sp,
                fontWeight = FontWeight.Light,
            ),
        headlineMedium =
            TextStyle(
                fontSize = 27.sp,
                lineHeight = 32.sp,
                fontWeight = FontWeight.Normal,
            ),
        titleLarge =
            TextStyle(
                fontSize = 21.sp,
                lineHeight = 27.sp,
                fontWeight = FontWeight.Medium,
            ),
        bodyLarge =
            TextStyle(
                fontSize = 17.sp,
                lineHeight = 24.sp,
                fontWeight = FontWeight.Normal,
            ),
        bodyMedium =
            TextStyle(
                fontSize = 15.sp,
                lineHeight = 21.sp,
                fontWeight = FontWeight.Normal,
            ),
        labelLarge =
            TextStyle(
                fontSize = 14.sp,
                lineHeight = 20.sp,
                fontWeight = FontWeight.Medium,
            ),
    )

private val DemoApps =
    listOf(
        DemoApp("Authenticator", "A", Color(0xFF565E6D)),
        DemoApp("Calculator", "÷", Color(0xFF536B8F)),
        DemoApp("Calendar", "17", Color(0xFF3468C0)),
        DemoApp("Camera", "●", Color(0xFF3F4752)),
        DemoApp("Chrome", "C", Color(0xFF4C82C8)),
        DemoApp("Clock", "◷", Color(0xFF4056A8)),
        DemoApp("Contacts", "P", Color(0xFF2B78D0)),
        DemoApp("Drive", "D", Color(0xFF3D7F68)),
        DemoApp("Files", "F", SableBlue),
        DemoApp("Messages", "M", Color(0xFF2E8DE3)),
        DemoApp("Phone", "P", SableGreen),
        DemoApp("Photos", "P", Color(0xFF58A75D)),
        DemoApp("Play Store", "▶", SablePurple),
        DemoApp("Settings", "⚙", SableSlate),
    )

@Composable
private fun SableMetroPreviewApp(
    liveSurfaceRepository: LiveSurfaceRepository,
    refreshGeneration: Int,
    onOpenFiles: () -> Unit,
    onOpenFilesAppInfo: () -> Unit,
    onRequestLivePermissions: () -> Unit,
) {
    var screen by remember { mutableStateOf(PreviewScreen.Start) }
    var liveSnapshot by remember {
        mutableStateOf(liveSurfaceRepository.initialSnapshot())
    }

    LaunchedEffect(refreshGeneration) {
        while (true) {
            liveSnapshot = liveSurfaceRepository.snapshot()
            delay(60_000L)
        }
    }

    MaterialTheme(
        colorScheme = SableColors,
        typography = SableTypography,
    ) {
        Surface(
            modifier = Modifier.fillMaxSize(),
            color = Color.Black,
        ) {
            Box(
                modifier =
                    Modifier
                        .fillMaxSize()
                        .windowInsetsPadding(WindowInsets.safeDrawing),
            ) {
                Box(
                    modifier =
                        Modifier
                            .fillMaxSize()
                            .padding(bottom = 66.dp),
                ) {
                    when (screen) {
                        PreviewScreen.Start ->
                            StartScreen(
                                dateText = liveSnapshot.dateText,
                                onAllApps = { screen = PreviewScreen.Apps },
                                onPinned = { screen = PreviewScreen.Pinned },
                                onSettings = { screen = PreviewScreen.Settings },
                            )
                        PreviewScreen.Apps ->
                            AppsScreen(
                                onFiles = { screen = PreviewScreen.Context },
                                onSearch = { screen = PreviewScreen.Search },
                            )
                        PreviewScreen.Context ->
                            AppContextScreen(
                                onOpen = onOpenFiles,
                                onAppInfo = onOpenFilesAppInfo,
                            )
                        PreviewScreen.Search ->
                            SearchScreen(
                                onSettings = { screen = PreviewScreen.Settings },
                            )
                        PreviewScreen.Pinned ->
                            PinnedRecentScreen()
                        PreviewScreen.Settings ->
                            SettingsScreen()
                        PreviewScreen.Live ->
                            LiveSurfaceScreen(
                                snapshot = liveSnapshot,
                                onRequestPermissions = onRequestLivePermissions,
                            )
                        PreviewScreen.Lock ->
                            LockPreviewScreen(
                                timeText = liveSnapshot.timeText,
                                dateText = liveSnapshot.dateText,
                            )
                    }
                }

                PreviewNavigator(
                    current = screen,
                    onChange = { screen = it },
                    modifier = Modifier.align(Alignment.BottomCenter),
                )
            }
        }
    }
}

@Composable
private fun StartScreen(
    dateText: String,
    onAllApps: () -> Unit,
    onPinned: () -> Unit,
    onSettings: () -> Unit,
) {
    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = androidx.compose.foundation.layout.PaddingValues(bottom = 28.dp),
    ) {
        item {
            Box(
                modifier =
                    Modifier
                        .fillMaxWidth()
                        .height(292.dp)
                        .background(
                            Brush.verticalGradient(
                                listOf(
                                    Color(0xFF6676A8),
                                    Color(0xFF3D536D),
                                    Color.Black,
                                ),
                            ),
                        )
                        .padding(horizontal = 24.dp, vertical = 26.dp),
            ) {
                Column(
                    modifier = Modifier.align(Alignment.BottomStart),
                ) {
                    Text(
                        text = dateText,
                        style = MaterialTheme.typography.bodyMedium,
                        color = Color.White.copy(alpha = 0.88f),
                    )
                    Spacer(Modifier.height(10.dp))
                    Text(
                        text = "good\nevening",
                        style = MaterialTheme.typography.displayLarge,
                    )
                    Spacer(Modifier.height(12.dp))
                    Text(
                        text = "A calmer device\nfor a more intentional day.",
                        style = MaterialTheme.typography.bodyMedium,
                        color = Color.White.copy(alpha = 0.82f),
                    )
                }
            }
        }

        item {
            Column(
                modifier = Modifier.padding(horizontal = 20.dp, vertical = 14.dp),
            ) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(10.dp),
                ) {
                    MetroTile(
                        title = "Messages",
                        subtitle = "2 new",
                        mark = "M",
                        color = SableBlue,
                        modifier = Modifier.weight(1f),
                    )
                    MetroTile(
                        title = "Photos",
                        subtitle = "Recent",
                        mark = "P",
                        color = SableGreen,
                        modifier = Modifier.weight(1f),
                    )
                }
                Spacer(Modifier.height(10.dp))
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(10.dp),
                ) {
                    MetroTile(
                        title = "Play Store",
                        subtitle = null,
                        mark = "▶",
                        color = SablePurple,
                        modifier = Modifier.weight(1f),
                    )
                    MetroTile(
                        title = "Settings",
                        subtitle = null,
                        mark = "⚙",
                        color = SableSlate,
                        modifier = Modifier.weight(1f),
                        onClick = onSettings,
                    )
                }

                Spacer(Modifier.height(20.dp))
                Text(
                    text = "pinned & recent  →",
                    modifier =
                        Modifier
                            .heightIn(min = 48.dp)
                            .clickable(onClick = onPinned)
                            .padding(vertical = 12.dp),
                    style = MaterialTheme.typography.titleLarge,
                )
                Text(
                    text = "all apps  →",
                    modifier =
                        Modifier
                            .heightIn(min = 48.dp)
                            .clickable(onClick = onAllApps)
                            .padding(vertical = 12.dp),
                    style = MaterialTheme.typography.titleLarge,
                )
            }
        }
    }
}

@Composable
private fun MetroTile(
    title: String,
    subtitle: String?,
    mark: String,
    color: Color,
    modifier: Modifier = Modifier,
    onClick: () -> Unit = {},
) {
    Column(
        modifier =
            modifier
                .height(142.dp)
                .clip(RoundedCornerShape(5.dp))
                .background(color)
                .clickable(onClick = onClick)
                .padding(14.dp),
        verticalArrangement = Arrangement.SpaceBetween,
    ) {
        Text(
            text = mark,
            fontSize = 28.sp,
            fontWeight = FontWeight.Medium,
        )
        Column {
            Text(
                text = title,
                style = MaterialTheme.typography.bodyLarge,
                fontWeight = FontWeight.Medium,
            )
            if (subtitle != null) {
                Text(
                    text = subtitle,
                    style = MaterialTheme.typography.bodyMedium,
                    color = Color.White.copy(alpha = 0.86f),
                )
            }
        }
    }
}

@Composable
private fun AppsScreen(
    onFiles: () -> Unit,
    onSearch: () -> Unit,
) {
    Column(
        modifier =
            Modifier
                .fillMaxSize()
                .padding(horizontal = 22.dp, vertical = 20.dp),
    ) {
        MetroHeading("apps")
        Spacer(Modifier.height(12.dp))

        Box(
            modifier =
                Modifier
                    .fillMaxWidth()
                    .heightIn(min = 52.dp)
                    .clip(RoundedCornerShape(28.dp))
                    .background(SablePanelRaised)
                    .clickable(onClick = onSearch)
                    .padding(horizontal = 18.dp, vertical = 15.dp),
        ) {
            Text(
                text = "⌕   Search apps…",
                style = MaterialTheme.typography.bodyLarge,
                color = SableMuted,
            )
        }

        Spacer(Modifier.height(14.dp))

        Box(modifier = Modifier.fillMaxSize()) {
            LazyColumn(
                modifier =
                    Modifier
                        .fillMaxSize()
                        .padding(end = 22.dp),
            ) {
                items(
                    items = DemoApps,
                    key = { it.name },
                ) { app ->
                    AppRow(
                        app = app,
                        onClick =
                            if (app.name == "Files") {
                                onFiles
                            } else {
                                {}
                            },
                    )
                }
            }

            Text(
                text = "A\nB\nC\nD\nE\nF\nG\nH\nI\nJ\nK\nL\nM\nN\nO\nP\nQ\nR\nS\nT\nU\nV\nW\nX\nY\nZ",
                modifier = Modifier.align(Alignment.CenterEnd),
                fontSize = 9.sp,
                lineHeight = 13.sp,
                color = SableMuted,
            )
        }
    }
}

@Composable
private fun AppRow(
    app: DemoApp,
    onClick: () -> Unit,
) {
    Row(
        modifier =
            Modifier
                .fillMaxWidth()
                .heightIn(min = 58.dp)
                .clickable(onClick = onClick)
                .padding(vertical = 6.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(
            modifier =
                Modifier
                    .size(42.dp)
                    .clip(RoundedCornerShape(10.dp))
                    .background(app.color),
            contentAlignment = Alignment.Center,
        ) {
            Text(
                text = app.mark,
                fontWeight = FontWeight.Bold,
            )
        }
        Spacer(Modifier.width(14.dp))
        Text(
            text = app.name,
            style = MaterialTheme.typography.bodyLarge,
        )
    }
}

@Composable
private fun AppContextScreen(
    onOpen: () -> Unit,
    onAppInfo: () -> Unit,
) {
    Column(
        modifier =
            Modifier
                .fillMaxSize()
                .padding(horizontal = 24.dp, vertical = 20.dp),
    ) {
        Text(
            text = "‹",
            fontSize = 38.sp,
            fontWeight = FontWeight.Light,
        )
        Spacer(Modifier.height(18.dp))
        MetroHeading("files")
        Spacer(Modifier.height(22.dp))

        Box(
            modifier =
                Modifier
                    .size(78.dp)
                    .clip(RoundedCornerShape(12.dp))
                    .background(SableBlue),
            contentAlignment = Alignment.Center,
        ) {
            Text(
                text = "F",
                fontSize = 36.sp,
                fontWeight = FontWeight.Bold,
            )
        }

        Spacer(Modifier.height(20.dp))
        Text(
            text = "Browse, manage, and share\nyour files securely.",
            style = MaterialTheme.typography.bodyLarge,
            color = SableMuted,
        )
        Spacer(Modifier.height(22.dp))

        Button(
            onClick = onOpen,
            modifier =
                Modifier
                    .fillMaxWidth()
                    .height(56.dp),
            colors =
                ButtonDefaults.buttonColors(
                    containerColor = Color(0xFF9BCBFF),
                    contentColor = Color.Black,
                ),
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
            ) {
                Text("Open", style = MaterialTheme.typography.bodyLarge)
                Text("→", style = MaterialTheme.typography.bodyLarge)
            }
        }

        Spacer(Modifier.height(24.dp))
        ContextAction("ⓘ", "App info", onClick = onAppInfo)
        ContextAction("⌖", "Pin to Start")
        ContextAction("□", "Uninstall")
        ContextAction("⚙", "App settings")
    }
}

@Composable
private fun ContextAction(
    mark: String,
    label: String,
    onClick: () -> Unit = {},
) {
    Row(
        modifier =
            Modifier
                .fillMaxWidth()
                .heightIn(min = 52.dp)
                .clickable(onClick = onClick)
                .padding(vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(mark, fontSize = 22.sp)
        Spacer(Modifier.width(16.dp))
        Text(label, style = MaterialTheme.typography.bodyLarge)
    }
}

@Composable
private fun SearchScreen(
    onSettings: () -> Unit,
) {
    var query by remember { mutableStateOf("set") }

    Column(
        modifier =
            Modifier
                .fillMaxSize()
                .padding(horizontal = 22.dp, vertical = 20.dp),
    ) {
        MetroHeading("search")
        Spacer(Modifier.height(14.dp))

        OutlinedTextField(
            value = query,
            onValueChange = { query = it },
            modifier = Modifier.fillMaxWidth(),
            singleLine = true,
            shape = RoundedCornerShape(28.dp),
            label = { Text("Search apps and settings") },
        )

        Spacer(Modifier.height(18.dp))
        SearchResult("⚙", "Settings", onClick = onSettings)
        SearchResult("▶", "Play Store")
        SearchResult("S", "Security")
        SearchResult("▣", "Set up device")

        Spacer(Modifier.height(26.dp))
        Text(
            text = "results update as you type",
            style = MaterialTheme.typography.bodyMedium,
            color = SableMuted,
        )
    }
}

@Composable
private fun SearchResult(
    mark: String,
    title: String,
    onClick: () -> Unit = {},
) {
    Row(
        modifier =
            Modifier
                .fillMaxWidth()
                .heightIn(min = 58.dp)
                .clickable(onClick = onClick)
                .padding(vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(
            modifier =
                Modifier
                    .size(40.dp)
                    .clip(RoundedCornerShape(10.dp))
                    .background(SablePanelRaised),
            contentAlignment = Alignment.Center,
        ) {
            Text(mark, fontWeight = FontWeight.Bold)
        }
        Spacer(Modifier.width(14.dp))
        Text(title, style = MaterialTheme.typography.bodyLarge)
    }
}

@Composable
private fun PinnedRecentScreen() {
    LazyColumn(
        modifier =
            Modifier
                .fillMaxSize()
                .padding(horizontal = 22.dp, vertical = 20.dp),
    ) {
        item {
            MetroHeading("pinned")
            Spacer(Modifier.height(18.dp))
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(10.dp),
            ) {
                CompactPinned("Phone", "P", SableGreen, Modifier.weight(1f))
                CompactPinned("Messages", "M", SableBlue, Modifier.weight(1f))
            }
            Spacer(Modifier.height(10.dp))
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(10.dp),
            ) {
                CompactPinned("Chrome", "C", Color(0xFF497FC2), Modifier.weight(1f))
                CompactPinned("Camera", "●", SableSlate, Modifier.weight(1f))
            }

            Spacer(Modifier.height(30.dp))
            MetroHeading("recent")
            Spacer(Modifier.height(12.dp))
        }

        items(
            listOf(
                "Files" to "2m ago",
                "Photos" to "12m ago",
                "Settings" to "1h ago",
                "Play Store" to "3h ago",
            ),
        ) { (name, age) ->
            Row(
                modifier =
                    Modifier
                        .fillMaxWidth()
                        .heightIn(min = 58.dp)
                        .clickable { }
                        .padding(vertical = 8.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Box(
                    modifier =
                        Modifier
                            .size(38.dp)
                            .clip(RoundedCornerShape(9.dp))
                            .background(SablePanelRaised),
                    contentAlignment = Alignment.Center,
                ) {
                    Text(name.take(1))
                }
                Spacer(Modifier.width(14.dp))
                Text(
                    text = name,
                    modifier = Modifier.weight(1f),
                    style = MaterialTheme.typography.bodyLarge,
                )
                Text(
                    text = age,
                    style = MaterialTheme.typography.bodyMedium,
                    color = SableMuted,
                )
            }
        }
    }
}

@Composable
private fun CompactPinned(
    name: String,
    mark: String,
    color: Color,
    modifier: Modifier,
) {
    Column(
        modifier =
            modifier
                .height(112.dp)
                .clip(RoundedCornerShape(6.dp))
                .background(SablePanel)
                .clickable { }
                .padding(13.dp),
        verticalArrangement = Arrangement.SpaceBetween,
    ) {
        Box(
            modifier =
                Modifier
                    .size(38.dp)
                    .clip(RoundedCornerShape(9.dp))
                    .background(color),
            contentAlignment = Alignment.Center,
        ) {
            Text(mark, fontWeight = FontWeight.Bold)
        }
        Text(name, style = MaterialTheme.typography.bodyLarge)
    }
}

@Composable
private fun SettingsScreen() {
    val settings =
        listOf(
            Triple("⌁", "Network & internet", "Wi‑Fi, mobile, hotspot"),
            Triple("ᛒ", "Connected devices", "Bluetooth, pairing"),
            Triple("▦", "Apps", "Recent apps, default apps"),
            Triple("●", "Notifications", "Notification history"),
            Triple("▮", "Battery", "82% · About 1 day left"),
            Triple("≡", "Storage", "42% used · 74 GB free"),
            Triple("◆", "Security & privacy", "Screen lock, permissions"),
            Triple("⚙", "System", "Languages, gestures, updates"),
        )

    LazyColumn(
        modifier =
            Modifier
                .fillMaxSize()
                .padding(horizontal = 22.dp, vertical = 20.dp),
    ) {
        item {
            MetroHeading("settings")
            Spacer(Modifier.height(18.dp))
        }

        items(settings) { (mark, title, detail) ->
            Row(
                modifier =
                    Modifier
                        .fillMaxWidth()
                        .heightIn(min = 68.dp)
                        .clip(RoundedCornerShape(6.dp))
                        .clickable { }
                        .padding(horizontal = 8.dp, vertical = 8.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(mark, fontSize = 24.sp, color = SableBlue)
                Spacer(Modifier.width(14.dp))
                Column(modifier = Modifier.weight(1f)) {
                    Text(title, style = MaterialTheme.typography.bodyLarge)
                    Text(
                        detail,
                        style = MaterialTheme.typography.bodyMedium,
                        color = SableMuted,
                    )
                }
                Text("›", color = SableMuted, fontSize = 24.sp)
            }
        }
    }
}

@Composable
private fun LiveSurfaceScreen(
    snapshot: LiveSurfaceSnapshot,
    onRequestPermissions: () -> Unit,
) {
    Box(
        modifier =
            Modifier
                .fillMaxSize()
                .background(
                    Brush.verticalGradient(
                        listOf(
                            Color(0xFF8C4E34),
                            Color(0xFF314238),
                            Color(0xFF121413),
                        ),
                    ),
                ),
    ) {
        LazyColumn(
            modifier =
                Modifier
                    .fillMaxSize()
                    .padding(horizontal = 22.dp, vertical = 28.dp),
        ) {
            item {
                Text(
                    text = snapshot.dateText,
                    style = MaterialTheme.typography.bodyLarge,
                )
                Text(
                    text = snapshot.timeText,
                    style = MaterialTheme.typography.displayLarge,
                )
                Text(
                    text = "live local data",
                    style = MaterialTheme.typography.bodyLarge,
                )
                Text(
                    text = "updated ${snapshot.timeText}",
                    style = MaterialTheme.typography.bodyMedium,
                    color = Color.White.copy(alpha = 0.82f),
                )
                Spacer(Modifier.height(20.dp))
            }

            item {
                LiveCard("▣", snapshot.photos)
                Spacer(Modifier.height(10.dp))
                LiveCard("♪", snapshot.music)
                Spacer(Modifier.height(10.dp))
                LiveCard("17", snapshot.calendar)
                Spacer(Modifier.height(10.dp))
                LiveCard("☁", snapshot.weather)
                Spacer(Modifier.height(10.dp))
                LiveCard("✓", snapshot.tasks)
                Spacer(Modifier.height(16.dp))
            }

            if (
                snapshot.photos.availability == LiveAvailability.PERMISSION_REQUIRED ||
                    snapshot.music.availability == LiveAvailability.PERMISSION_REQUIRED ||
                    snapshot.calendar.availability == LiveAvailability.PERMISSION_REQUIRED
            ) {
                item {
                    Button(
                        onClick = onRequestPermissions,
                        modifier = Modifier.fillMaxWidth(),
                    ) {
                        Text("Enable local live data")
                    }
                    Spacer(Modifier.height(12.dp))
                }
            }

            item {
                Text(
                    text = "Weather and Tasks remain unavailable until explicit providers are configured.",
                    style = MaterialTheme.typography.bodyMedium,
                    color = Color.White.copy(alpha = 0.70f),
                )
            }
        }
    }
}

@Composable
private fun LiveCard(
    mark: String,
    datum: LiveDatum,
) {
    val status =
        when (datum.availability) {
            LiveAvailability.LOADING -> "loading"
            LiveAvailability.LIVE -> "live"
            LiveAvailability.EMPTY -> "empty"
            LiveAvailability.PERMISSION_REQUIRED -> "permission required"
            LiveAvailability.UNAVAILABLE -> "unavailable"
            LiveAvailability.ERROR -> "error"
        }

    Row(
        modifier =
            Modifier
                .fillMaxWidth()
                .heightIn(min = 72.dp)
                .clip(RoundedCornerShape(12.dp))
                .background(Color.Black.copy(alpha = 0.55f))
                .padding(horizontal = 14.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(mark, fontSize = 26.sp)
        Spacer(Modifier.width(14.dp))
        Column(modifier = Modifier.weight(1f)) {
            Text(datum.title, style = MaterialTheme.typography.bodyLarge)
            Text(
                datum.detail,
                style = MaterialTheme.typography.bodyMedium,
                color = Color.White.copy(alpha = 0.76f),
            )
            Text(
                status,
                style = MaterialTheme.typography.labelLarge,
                color = Color.White.copy(alpha = 0.58f),
            )
        }
    }
}

@Composable
private fun LockPreviewScreen(
    timeText: String,
    dateText: String,
) {
    Box(
        modifier =
            Modifier
                .fillMaxSize()
                .background(
                    Brush.verticalGradient(
                        listOf(
                            Color(0xFF46608F),
                            Color(0xFF9C7190),
                            Color(0xFF1B3045),
                        ),
                    ),
                ),
    ) {
        Canvas(modifier = Modifier.fillMaxSize()) {
            val ridge =
                Path().apply {
                    moveTo(0f, size.height * 0.74f)
                    lineTo(size.width * 0.17f, size.height * 0.66f)
                    lineTo(size.width * 0.31f, size.height * 0.70f)
                    lineTo(size.width * 0.53f, size.height * 0.54f)
                    lineTo(size.width * 0.68f, size.height * 0.68f)
                    lineTo(size.width, size.height * 0.60f)
                    lineTo(size.width, size.height)
                    lineTo(0f, size.height)
                    close()
                }
            drawPath(
                path = ridge,
                color = Color(0xCC102334),
            )
        }

        Column(
            modifier =
                Modifier
                    .align(Alignment.TopCenter)
                    .padding(top = 86.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Text(
                text = timeText,
                fontSize = 72.sp,
                lineHeight = 78.sp,
                fontWeight = FontWeight.Light,
            )
            Text(
                text = dateText,
                style = MaterialTheme.typography.titleLarge,
            )
        }

        Column(
            modifier =
                Modifier
                    .align(Alignment.BottomCenter)
                    .padding(bottom = 34.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Text("⌃", fontSize = 26.sp)
            Text(
                text = "Swipe up to start",
                style = MaterialTheme.typography.bodyMedium,
            )
            Spacer(Modifier.height(12.dp))
            Text(
                text = "visual concept only — not Android lock-screen integration",
                style = MaterialTheme.typography.bodyMedium,
                color = Color.White.copy(alpha = 0.62f),
            )
        }
    }
}

@Composable
private fun MetroHeading(text: String) {
    Text(
        text = text,
        style = MaterialTheme.typography.displayMedium,
        modifier = Modifier.semantics { heading() },
    )
}

@Composable
private fun PreviewNavigator(
    current: PreviewScreen,
    onChange: (PreviewScreen) -> Unit,
    modifier: Modifier = Modifier,
) {
    val screens = PreviewScreen.entries
    val index = screens.indexOf(current)

    Surface(
        modifier =
            modifier
                .fillMaxWidth()
                .height(60.dp),
        color = Color(0xF216171A),
    ) {
        Row(
            modifier =
                Modifier
                    .fillMaxSize()
                    .padding(horizontal = 12.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween,
        ) {
            TextButton(
                onClick = {
                    onChange(screens[(index - 1 + screens.size) % screens.size])
                },
                modifier = Modifier.heightIn(min = 48.dp),
            ) {
                Text("‹")
            }

            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Text(
                    text = "${index + 1} / ${screens.size}",
                    style = MaterialTheme.typography.labelLarge,
                )
                Text(
                    text = current.title,
                    style = MaterialTheme.typography.bodyMedium,
                    color = SableMuted,
                )
            }

            TextButton(
                onClick = {
                    onChange(screens[(index + 1) % screens.size])
                },
                modifier = Modifier.heightIn(min = 48.dp),
            ) {
                Text("›")
            }
        }
    }
}
