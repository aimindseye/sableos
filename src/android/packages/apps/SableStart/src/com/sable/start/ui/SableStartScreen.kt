package org.sableos.start.ui

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
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
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.delay
import org.sableos.design.AccentPreset
import org.sableos.design.AppearanceMode
import org.sableos.design.SableAppearance
import org.sableos.design.SableTheme
import org.sableos.start.live.LiveAvailability
import org.sableos.start.live.LiveDatum
import org.sableos.start.live.LiveSurfaceSnapshot
import org.sableos.start.model.AppEntry
import org.sableos.start.model.stableKey
import org.sableos.start.platform.LiveSurfaceRepository
import java.util.Calendar

private enum class SableStartDestination(val title: String) {
    Start("start"),
    Apps("apps"),
    Search("search"),
    Pinned("pinned"),
    Live("live"),
    Appearance("appearance"),
    Context("app"),
}

private data class HomeTile(
    val title: String,
    val mark: String,
    val color: Color,
    val onClick: () -> Unit,
)

private val SableBlue = Color(0xFF4D9CFF)
private val SableGreen = Color(0xFF35C66B)
private val SablePurple = Color(0xFF7A42E8)
private val SableSlate = Color(0xFF45515F)
private val SableOrange = Color(0xFFF28C45)
private val SablePanel = Color(0xFF17191D)
private val SablePanelRaised = Color(0xFF22252A)
private val SableMuted = Color(0xFFB8BBC3)

private val SableTilePalette =
    listOf(
        SableBlue,
        SableGreen,
        SablePurple,
        SableOrange,
        SableSlate,
    )

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

/**
 * Production Sable Start UI.
 *
 * The same composable is used by the HOME activity and the Android Studio
 * preview application. Development navigation is chrome only; the screens and
 * state below are production-capable and consume real launcher/live data.
 */
@Composable
fun SableStartScreen(
    apps: List<AppEntry>,
    liveSurfaceRepository: LiveSurfaceRepository,
    appearance: SableAppearance = SableAppearance(),
    refreshGeneration: Int = 0,
    showDevelopmentNavigator: Boolean = false,
    initialPinnedKeys: Set<String> = emptySet(),
    onPinnedKeysChanged: (Set<String>) -> Unit = {},
    onAppearanceChanged: (SableAppearance) -> Unit = {},
    onResetAppearance: () -> Unit = {},
    onLaunchApp: (AppEntry) -> Boolean,
    onOpenSettings: () -> Unit,
    onOpenAppInfo: (AppEntry) -> Unit,
    onRequestLivePermissions: () -> Unit,
) {
    var destination by remember { mutableStateOf(SableStartDestination.Start) }
    var contextReturnDestination by remember {
        mutableStateOf(SableStartDestination.Apps)
    }
    var selectedApp by remember { mutableStateOf<AppEntry?>(null) }
    var pinnedKeys by remember(initialPinnedKeys) {
        mutableStateOf(initialPinnedKeys.toList())
    }
    var recentKeys by remember { mutableStateOf<List<String>>(emptyList()) }
    var liveSnapshot by remember {
        mutableStateOf(liveSurfaceRepository.initialSnapshot())
    }

    LaunchedEffect(refreshGeneration) {
        while (true) {
            liveSnapshot = liveSurfaceRepository.snapshot()
            delay(60_000L)
        }
    }

    val appByKey = apps.associateBy { it.stableKey() }
    val pinnedApps = pinnedKeys.mapNotNull(appByKey::get)
    val recentApps = recentKeys.mapNotNull(appByKey::get)

    fun launchApp(entry: AppEntry) {
        if (onLaunchApp(entry)) {
            val key = entry.stableKey()
            recentKeys =
                (listOf(key) + recentKeys.filterNot { it == key })
                    .take(MAX_RECENT_APPS)
        }
    }

    fun openContext(
        entry: AppEntry,
        returnDestination: SableStartDestination,
    ) {
        selectedApp = entry
        contextReturnDestination = returnDestination
        destination = SableStartDestination.Context
    }

    fun navigateBack() {
        destination =
            when (destination) {
                SableStartDestination.Start -> SableStartDestination.Start
                SableStartDestination.Search -> SableStartDestination.Apps
                SableStartDestination.Context -> contextReturnDestination
                SableStartDestination.Apps,
                SableStartDestination.Pinned,
                SableStartDestination.Live,
                SableStartDestination.Appearance,
                -> SableStartDestination.Start
            }
    }

    BackHandler(enabled = true) {
        navigateBack()
    }

    SableTheme(
        appearance = appearance,
    ) {
        Surface(
            modifier = Modifier.fillMaxSize(),
            color = MaterialTheme.colorScheme.background,
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
                            .padding(
                                bottom =
                                    if (showDevelopmentNavigator) {
                                        DEVELOPMENT_NAV_HEIGHT
                                    } else {
                                        0.dp
                                    },
                            ),
                ) {
                    when (destination) {
                        SableStartDestination.Start ->
                            StartScreen(
                                dateText = liveSnapshot.dateText,
                                greeting = greetingFor(liveSnapshot.observedAtEpochMs),
                                featuredApps = chooseFeaturedApps(apps, pinnedApps),
                                appearance = appearance,
                                onLaunchApp = ::launchApp,
                                onOpenSettings = onOpenSettings,
                                onAllApps = {
                                    destination = SableStartDestination.Apps
                                },
                                onPinned = {
                                    destination = SableStartDestination.Pinned
                                },
                                onLive = {
                                    destination = SableStartDestination.Live
                                },
                                onAppearance = {
                                    destination = SableStartDestination.Appearance
                                },
                            )

                        SableStartDestination.Apps ->
                            AppsScreen(
                                apps = apps,
                                onBack = ::navigateBack,
                                onSearch = {
                                    destination = SableStartDestination.Search
                                },
                                onLaunchApp = ::launchApp,
                                onOpenContext = { entry ->
                                    openContext(
                                        entry = entry,
                                        returnDestination = SableStartDestination.Apps,
                                    )
                                },
                            )

                        SableStartDestination.Search ->
                            SearchScreen(
                                apps = apps,
                                onBack = ::navigateBack,
                                onLaunchApp = ::launchApp,
                                onOpenContext = { entry ->
                                    openContext(
                                        entry = entry,
                                        returnDestination = SableStartDestination.Search,
                                    )
                                },
                            )

                        SableStartDestination.Pinned ->
                            PinnedRecentScreen(
                                pinnedApps = pinnedApps,
                                recentApps = recentApps,
                                onBack = ::navigateBack,
                                onLaunchApp = ::launchApp,
                                onOpenContext = { entry ->
                                    openContext(
                                        entry = entry,
                                        returnDestination = SableStartDestination.Pinned,
                                    )
                                },
                            )

                        SableStartDestination.Live ->
                            LiveSurfaceScreen(
                                snapshot = liveSnapshot,
                                onBack = ::navigateBack,
                                onRequestPermissions = onRequestLivePermissions,
                            )

                        SableStartDestination.Appearance ->
                            AppearanceScreen(
                                appearance = appearance,
                                onBack = ::navigateBack,
                                onAppearanceChanged = onAppearanceChanged,
                                onReset = onResetAppearance,
                            )

                        SableStartDestination.Context -> {
                            val app = selectedApp
                            if (app == null) {
                                destination = contextReturnDestination
                            } else {
                                val key = app.stableKey()
                                AppContextScreen(
                                    app = app,
                                    isPinned = key in pinnedKeys,
                                    onBack = ::navigateBack,
                                    onOpen = { launchApp(app) },
                                    onOpenAppInfo = { onOpenAppInfo(app) },
                                    onTogglePinned = {
                                        pinnedKeys =
                                            if (key in pinnedKeys) {
                                                pinnedKeys.filterNot { it == key }
                                            } else {
                                                (pinnedKeys + key).distinct()
                                            }
                                        onPinnedKeysChanged(pinnedKeys.toSet())
                                    },
                                )
                            }
                        }
                    }
                }

                if (showDevelopmentNavigator) {
                    DevelopmentNavigator(
                        current = destination,
                        onChange = { next ->
                            if (next != SableStartDestination.Context) {
                                destination = next
                            }
                        },
                        modifier = Modifier.align(Alignment.BottomCenter),
                    )
                }
            }
        }
    }
}

@Composable
private fun StartScreen(
    dateText: String,
    greeting: String,
    featuredApps: List<AppEntry>,
    appearance: SableAppearance,
    onLaunchApp: (AppEntry) -> Unit,
    onOpenSettings: () -> Unit,
    onAllApps: () -> Unit,
    onPinned: () -> Unit,
    onLive: () -> Unit,
    onAppearance: () -> Unit,
) {
    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(bottom = 28.dp),
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
                                    appearance.accent.color.copy(alpha = 0.76f),
                                    MaterialTheme.colorScheme.surfaceVariant,
                                    MaterialTheme.colorScheme.background,
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
                        text = greeting,
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
                val tilePalette =
                    listOf(appearance.accent.color) +
                        SableTilePalette.filterNot { it == appearance.accent.color }
                val appTiles =
                    featuredApps.mapIndexed { index, app ->
                        HomeTile(
                            title = app.label,
                            mark = appMark(app),
                            color = tilePalette[index % tilePalette.size],
                            onClick = { onLaunchApp(app) },
                        )
                    }
                val tiles =
                    (appTiles +
                        HomeTile(
                            title = "Settings",
                            mark = "⚙",
                            color = SableSlate,
                            onClick = onOpenSettings,
                        ))
                        .take(MAX_HOME_TILES)

                TileGrid(tiles)

                Spacer(Modifier.height(20.dp))
                MetroLink("all apps  →", onAllApps)
                MetroLink("pinned & recent  →", onPinned)
                MetroLink("live local data  →", onLive)
                MetroLink("appearance  →", onAppearance)
            }
        }
    }
}

@Composable
private fun TileGrid(tiles: List<HomeTile>) {
    Column(
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        tiles.chunked(2).forEach { rowTiles ->
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(10.dp),
            ) {
                rowTiles.forEach { tile ->
                    MetroTile(
                        title = tile.title,
                        mark = tile.mark,
                        color = tile.color,
                        modifier = Modifier.weight(1f),
                        onClick = tile.onClick,
                    )
                }
                if (rowTiles.size == 1) {
                    Spacer(Modifier.weight(1f))
                }
            }
        }
    }
}

@Composable
private fun MetroTile(
    title: String,
    mark: String,
    color: Color,
    modifier: Modifier = Modifier,
    onClick: () -> Unit,
) {
    val tileContentColor =
        if (
            (0.2126f * color.red) +
                (0.7152f * color.green) +
                (0.0722f * color.blue) >
            0.52f
        ) {
            Color(0xFF06111F)
        } else {
            Color.White
        }

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
            color = tileContentColor,
        )
        Text(
            text = title,
            style = MaterialTheme.typography.bodyLarge,
            fontWeight = FontWeight.Medium,
            color = tileContentColor,
            maxLines = 2,
        )
    }
}

@Composable
private fun MetroLink(
    text: String,
    onClick: () -> Unit,
) {
    Text(
        text = text,
        modifier =
            Modifier
                .fillMaxWidth()
                .heightIn(min = 48.dp)
                .clickable(onClick = onClick)
                .padding(vertical = 12.dp),
        style = MaterialTheme.typography.titleLarge,
    )
}

@Composable
private fun AppearanceScreen(
    appearance: SableAppearance,
    onBack: () -> Unit,
    onAppearanceChanged: (SableAppearance) -> Unit,
    onReset: () -> Unit,
) {
    LazyColumn(
        modifier =
            Modifier
                .fillMaxSize()
                .padding(horizontal = 22.dp, vertical = 20.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        item {
            MetroHeader(
                title = "appearance",
                onBack = onBack,
            )
            Spacer(Modifier.height(8.dp))
            Text(
                text = "Theme",
                style = MaterialTheme.typography.titleLarge,
            )
        }

        items(AppearanceMode.entries) { mode ->
            val selected = appearance.mode == mode
            Button(
                onClick = {
                    onAppearanceChanged(
                        appearance.copy(mode = mode),
                    )
                },
                modifier =
                    Modifier
                        .fillMaxWidth()
                        .heightIn(min = 48.dp),
                shape = RoundedCornerShape(5.dp),
                colors =
                    ButtonDefaults.buttonColors(
                        containerColor =
                            if (selected) {
                                MaterialTheme.colorScheme.primary
                            } else {
                                MaterialTheme.colorScheme.surfaceVariant
                            },
                        contentColor =
                            if (selected) {
                                MaterialTheme.colorScheme.onPrimary
                            } else {
                                MaterialTheme.colorScheme.onSurfaceVariant
                            },
                    ),
            ) {
                Text(
                    when (mode) {
                        AppearanceMode.FollowSystem -> "Follow system"
                        AppearanceMode.Light -> "Light"
                        AppearanceMode.Dark -> "Dark"
                    },
                )
            }
        }

        item {
            Spacer(Modifier.height(4.dp))
            Text(
                text = "Accent",
                style = MaterialTheme.typography.titleLarge,
            )
        }

        items(AccentPreset.entries) { accent ->
            val selected = appearance.accent == accent
            Button(
                onClick = {
                    onAppearanceChanged(
                        appearance.copy(accent = accent),
                    )
                },
                modifier =
                    Modifier
                        .fillMaxWidth()
                        .heightIn(min = 48.dp),
                shape = RoundedCornerShape(5.dp),
                colors =
                    ButtonDefaults.buttonColors(
                        containerColor = accent.color,
                        contentColor = accent.onColor,
                    ),
            ) {
                Text(
                    text =
                        if (selected) {
                            "✓  ${accent.displayName}"
                        } else {
                            accent.displayName
                        },
                )
            }
        }

        item {
            Spacer(Modifier.height(6.dp))
            TextButton(
                onClick = onReset,
                modifier =
                    Modifier
                        .fillMaxWidth()
                        .heightIn(min = 48.dp),
            ) {
                Text("Reset to Follow system · Sable Blue")
            }
        }
    }
}

@Composable
private fun AppsScreen(
    apps: List<AppEntry>,
    onBack: () -> Unit,
    onSearch: () -> Unit,
    onLaunchApp: (AppEntry) -> Unit,
    onOpenContext: (AppEntry) -> Unit,
) {
    Column(
        modifier =
            Modifier
                .fillMaxSize()
                .padding(horizontal = 22.dp, vertical = 20.dp),
    ) {
        MetroHeader(
            title = "apps",
            onBack = onBack,
        )
        Spacer(Modifier.height(12.dp))

        Box(
            modifier =
                Modifier
                    .fillMaxWidth()
                    .heightIn(min = 52.dp)
                    .clip(RoundedCornerShape(6.dp))
                    .background(MaterialTheme.colorScheme.surfaceVariant)
                    .clickable(onClick = onSearch)
                    .padding(horizontal = 18.dp, vertical = 15.dp),
        ) {
            Text(
                text = "⌕   Search apps…",
                style = MaterialTheme.typography.bodyLarge,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }

        Spacer(Modifier.height(14.dp))

        if (apps.isEmpty()) {
            EmptyState("No launchable apps are available.")
        } else {
            LazyColumn(
                modifier = Modifier.fillMaxSize(),
            ) {
                items(
                    items = apps,
                    key = { it.stableKey() },
                ) { app ->
                    AppRow(
                        app = app,
                        onClick = { onLaunchApp(app) },
                        onContext = { onOpenContext(app) },
                    )
                }
            }
        }
    }
}

@Composable
private fun SearchScreen(
    apps: List<AppEntry>,
    onBack: () -> Unit,
    onLaunchApp: (AppEntry) -> Unit,
    onOpenContext: (AppEntry) -> Unit,
) {
    var query by remember { mutableStateOf("") }
    val normalizedQuery = query.trim()
    val filteredApps =
        if (normalizedQuery.isEmpty()) {
            apps
        } else {
            apps.filter { app ->
                app.label.contains(normalizedQuery, ignoreCase = true)
            }
        }

    Column(
        modifier =
            Modifier
                .fillMaxSize()
                .padding(horizontal = 22.dp, vertical = 20.dp),
    ) {
        MetroHeader(
            title = "search",
            onBack = onBack,
        )
        Spacer(Modifier.height(14.dp))

        OutlinedTextField(
            value = query,
            onValueChange = { query = it },
            modifier = Modifier.fillMaxWidth(),
            singleLine = true,
            shape = RoundedCornerShape(6.dp),
            label = { Text("Search apps") },
        )

        Spacer(Modifier.height(18.dp))

        if (filteredApps.isEmpty()) {
            EmptyState(
                if (normalizedQuery.isEmpty()) {
                    "No launchable apps are available."
                } else {
                    "No apps match “$normalizedQuery”."
                },
            )
        } else {
            LazyColumn(
                modifier = Modifier.fillMaxSize(),
            ) {
                items(
                    items = filteredApps,
                    key = { it.stableKey() },
                ) { app ->
                    AppRow(
                        app = app,
                        onClick = { onLaunchApp(app) },
                        onContext = { onOpenContext(app) },
                    )
                }
            }
        }
    }
}

@Composable
private fun AppRow(
    app: AppEntry,
    onClick: () -> Unit,
    onContext: () -> Unit,
) {
    Row(
        modifier =
            Modifier
                .fillMaxWidth()
                .heightIn(min = 58.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Row(
            modifier =
                Modifier
                    .weight(1f)
                    .heightIn(min = 58.dp)
                    .clickable(onClick = onClick)
                    .padding(vertical = 6.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Box(
                modifier =
                    Modifier
                        .size(42.dp)
                        .clip(RoundedCornerShape(6.dp))
                        .background(appColor(app)),
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    text = appMark(app),
                    fontWeight = FontWeight.Bold,
                )
            }
            Spacer(Modifier.width(14.dp))
            Text(
                text = app.label,
                modifier = Modifier.weight(1f),
                style = MaterialTheme.typography.bodyLarge,
                maxLines = 2,
            )
        }

        TextButton(
            onClick = onContext,
            modifier = Modifier.heightIn(min = 48.dp),
        ) {
            Text(
                text = "⋯",
                fontSize = 24.sp,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    }
}

@Composable
private fun AppContextScreen(
    app: AppEntry,
    isPinned: Boolean,
    onBack: () -> Unit,
    onOpen: () -> Unit,
    onOpenAppInfo: () -> Unit,
    onTogglePinned: () -> Unit,
) {
    Column(
        modifier =
            Modifier
                .fillMaxSize()
                .padding(horizontal = 24.dp, vertical = 20.dp),
    ) {
        MetroHeader(
            title = "app",
            onBack = onBack,
        )
        Spacer(Modifier.height(22.dp))

        Box(
            modifier =
                Modifier
                    .size(78.dp)
                    .clip(RoundedCornerShape(6.dp))
                    .background(appColor(app)),
            contentAlignment = Alignment.Center,
        ) {
            Text(
                text = appMark(app),
                fontSize = 36.sp,
                fontWeight = FontWeight.Bold,
            )
        }

        Spacer(Modifier.height(18.dp))
        Text(
            text = app.label,
            style = MaterialTheme.typography.headlineLarge,
        )
        Text(
            text = "Installed application",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
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
            shape = RoundedCornerShape(6.dp),
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
        ContextAction(
            mark = if (isPinned) "−" else "+",
            label = if (isPinned) "Unpin from Start" else "Pin to Start",
            onClick = onTogglePinned,
        )
        ContextAction(
            mark = "ⓘ",
            label = "Permissions & app info",
            onClick = onOpenAppInfo,
        )
    }
}

@Composable
private fun PinnedRecentScreen(
    pinnedApps: List<AppEntry>,
    recentApps: List<AppEntry>,
    onBack: () -> Unit,
    onLaunchApp: (AppEntry) -> Unit,
    onOpenContext: (AppEntry) -> Unit,
) {
    LazyColumn(
        modifier =
            Modifier
                .fillMaxSize()
                .padding(horizontal = 22.dp, vertical = 20.dp),
    ) {
        item {
            MetroHeader(
                title = "pinned & recent",
                onBack = onBack,
            )
            Spacer(Modifier.height(22.dp))
            SectionLabel("pinned")
        }

        if (pinnedApps.isEmpty()) {
            item {
                EmptyState("Pin apps from the app menu to keep them on Start.")
            }
        } else {
            items(
                items = pinnedApps,
                key = { it.stableKey() },
            ) { app ->
                AppRow(
                    app = app,
                    onClick = { onLaunchApp(app) },
                    onContext = { onOpenContext(app) },
                )
            }
        }

        item {
            Spacer(Modifier.height(24.dp))
            SectionLabel("recent this session")
        }

        if (recentApps.isEmpty()) {
            item {
                EmptyState("Apps you open from Sable Start will appear here.")
            }
        } else {
            items(
                items = recentApps,
                key = { it.stableKey() },
            ) { app ->
                AppRow(
                    app = app,
                    onClick = { onLaunchApp(app) },
                    onContext = { onOpenContext(app) },
                )
            }
        }
    }
}

@Composable
private fun LiveSurfaceScreen(
    snapshot: LiveSurfaceSnapshot,
    onBack: () -> Unit,
    onRequestPermissions: () -> Unit,
) {
    Box(
        modifier =
            Modifier
                .fillMaxSize()
                .background(
                    Brush.verticalGradient(
                        listOf(
                            Color(0xFF704836),
                            Color(0xFF273A34),
                            MaterialTheme.colorScheme.background,
                        ),
                    ),
                ),
    ) {
        LazyColumn(
            modifier = Modifier.fillMaxSize(),
            contentPadding = PaddingValues(
                start = 22.dp,
                end = 22.dp,
                top = 20.dp,
                bottom = 28.dp,
            ),
        ) {
            item {
                MetroHeader(
                    title = "live",
                    onBack = onBack,
                )
                Spacer(Modifier.height(18.dp))
                Text(
                    text = snapshot.dateText,
                    style = MaterialTheme.typography.bodyLarge,
                )
                Text(
                    text = snapshot.timeText,
                    style = MaterialTheme.typography.displayLarge,
                )
                Text(
                    text = "local device data",
                    style = MaterialTheme.typography.bodyLarge,
                )
                Spacer(Modifier.height(20.dp))
            }

            item {
                LiveCard("▣", snapshot.photos)
                Spacer(Modifier.height(10.dp))
                LiveCard("♪", snapshot.music)
                Spacer(Modifier.height(10.dp))
                LiveCard("17", snapshot.calendar)
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
                        shape = RoundedCornerShape(6.dp),
                    ) {
                        Text("Enable local live data")
                    }
                    Spacer(Modifier.height(16.dp))
                }
            }

            item {
                Text(
                    text = "Weather and tasks stay unavailable until explicit providers are configured.",
                    style = MaterialTheme.typography.bodyMedium,
                    color = Color.White.copy(alpha = 0.72f),
                )
                Spacer(Modifier.height(8.dp))
                Text(
                    text = "Sable Start reads these counts locally on the device.",
                    style = MaterialTheme.typography.bodyMedium,
                    color = Color.White.copy(alpha = 0.72f),
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
                .clip(RoundedCornerShape(6.dp))
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
            if (!datum.detail.equals(status, ignoreCase = true)) {
                Text(
                    status,
                    style = MaterialTheme.typography.labelLarge,
                    color = Color.White.copy(alpha = 0.58f),
                )
            }
        }
    }
}

@Composable
private fun MetroHeader(
    title: String,
    onBack: () -> Unit,
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        TextButton(
            onClick = onBack,
            modifier =
                Modifier
                    .heightIn(min = 48.dp)
                    .width(48.dp),
        ) {
            Text(
                text = "‹",
                fontSize = 32.sp,
                fontWeight = FontWeight.Light,
            )
        }
        Spacer(Modifier.width(6.dp))
        Text(
            text = title,
            style = MaterialTheme.typography.displayMedium,
            modifier = Modifier.semantics { heading() },
        )
    }
}

@Composable
private fun ContextAction(
    mark: String,
    label: String,
    onClick: () -> Unit,
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
private fun SectionLabel(text: String) {
    Text(
        text = text,
        style = MaterialTheme.typography.titleLarge,
        color = Color.White,
    )
    Spacer(Modifier.height(10.dp))
}

@Composable
private fun EmptyState(text: String) {
    Text(
        text = text,
        modifier = Modifier.padding(vertical = 18.dp),
        style = MaterialTheme.typography.bodyLarge,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
    )
}

@Composable
private fun DevelopmentNavigator(
    current: SableStartDestination,
    onChange: (SableStartDestination) -> Unit,
    modifier: Modifier = Modifier,
) {
    val screens =
        listOf(
            SableStartDestination.Start,
            SableStartDestination.Apps,
            SableStartDestination.Search,
            SableStartDestination.Pinned,
            SableStartDestination.Live,
            SableStartDestination.Appearance,
        )
    val normalizedCurrent =
        if (current in screens) {
            current
        } else {
            SableStartDestination.Apps
        }
    val index = screens.indexOf(normalizedCurrent)

    Surface(
        modifier =
            modifier
                .fillMaxWidth()
                .height(DEVELOPMENT_NAV_HEIGHT),
        color = MaterialTheme.colorScheme.surface.copy(alpha = 0.95f),
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
                    text =
                        if (current == SableStartDestination.Context) {
                            "context"
                        } else {
                            "${index + 1} / ${screens.size}"
                        },
                    style = MaterialTheme.typography.labelLarge,
                )
                Text(
                    text =
                        if (current == SableStartDestination.Context) {
                            "app"
                        } else {
                            normalizedCurrent.title
                        },
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
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

private fun chooseFeaturedApps(
    apps: List<AppEntry>,
    pinnedApps: List<AppEntry>,
): List<AppEntry> {
    val candidates =
        apps.filterNot { app ->
            app.label.equals("Settings", ignoreCase = true) ||
                app.component.packageName == "com.android.settings"
        }
    val candidateKeys = candidates.mapTo(mutableSetOf()) { it.stableKey() }
    val selected = linkedMapOf<String, AppEntry>()

    pinnedApps
        .filter { it.stableKey() in candidateKeys }
        .forEach { app ->
            selected.putIfAbsent(app.stableKey(), app)
        }

    FEATURED_APP_LABELS.forEach { preferred ->
        candidates.firstOrNull { app ->
            app.label.equals(preferred, ignoreCase = true)
        }?.let { app ->
            selected.putIfAbsent(app.stableKey(), app)
        }
    }

    candidates.forEach { app ->
        selected.putIfAbsent(app.stableKey(), app)
    }

    return selected.values.take(MAX_FEATURED_APPS)
}

private fun greetingFor(epochMs: Long): String {
    val hour =
        Calendar.getInstance().apply {
            timeInMillis = epochMs
        }.get(Calendar.HOUR_OF_DAY)

    return when (hour) {
        in 5..11 -> "good\nmorning"
        in 12..16 -> "good\nafternoon"
        in 17..21 -> "good\nevening"
        else -> "good\nnight"
    }
}

private fun appMark(app: AppEntry): String =
    app.label
        .trim()
        .take(1)
        .uppercase()
        .ifEmpty { "•" }

private fun appColor(app: AppEntry): Color {
    val index = Math.floorMod(app.stableKey().hashCode(), SableTilePalette.size)
    return SableTilePalette[index]
}

private val FEATURED_APP_LABELS =
    listOf(
        "Messages",
        "Photos",
        "Camera",
        "Phone",
        "Vanadium",
        "Chrome",
        "Browser",
        "Files",
        "Calculator",
        "Play Store",
    )

private const val MAX_FEATURED_APPS = 3
private const val MAX_HOME_TILES = 4
private const val MAX_RECENT_APPS = 8
private val DEVELOPMENT_NAV_HEIGHT = 60.dp
