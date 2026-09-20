package org.sableos.start.ui

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxHeight
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
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
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
import java.util.Locale

private enum class SableStartDestination {
    Start,
    Apps,
    Search,
    Live,
    Appearance,
    Peek,
}

private data class HomeTile(
    val title: String,
    val mark: String,
    val color: Color,
    val onClick: () -> Unit,
)

private data class AppRailRow(
    val app: AppEntry,
    val section: String,
    val startsSection: Boolean,
)

private data class SearchCommand(
    val title: String,
    val subtitle: String,
    val mark: String,
    val onClick: () -> Unit,
)

private val SableBlue = Color(0xFF4D9CFF)
private val SableGreen = Color(0xFF35C66B)
private val SablePurple = Color(0xFF7A42E8)
private val SableSlate = Color(0xFF45515F)
private val SableOrange = Color(0xFFF28C45)
private val SableTilePalette =
    listOf(
        SableBlue,
        SableGreen,
        SablePurple,
        SableOrange,
        SableSlate,
    )

/**
 * Production Sable Start UI.
 *
 * R9 combines the Start, one-hand Favorites, alphabet rail, local Search /
 * Command, Sable Peek and contextual local-data work in one production path.
 * Recents/Overview remain owned by Android Quickstep.
 */
@Composable
fun SableStartScreen(
    apps: List<AppEntry>,
    liveSurfaceRepository: LiveSurfaceRepository,
    appearance: SableAppearance = SableAppearance(),
    refreshGeneration: Int = 0,
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
    var returnDestination by remember { mutableStateOf(SableStartDestination.Start) }
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
                    .take(MAX_SESSION_RECENTS)
        }
    }

    fun openPeek(
        entry: AppEntry,
        from: SableStartDestination,
    ) {
        selectedApp = entry
        returnDestination = from
        destination = SableStartDestination.Peek
    }

    fun openSearch(from: SableStartDestination) {
        returnDestination = from
        destination = SableStartDestination.Search
    }

    fun navigateBack() {
        destination =
            when (destination) {
                SableStartDestination.Start -> SableStartDestination.Start
                SableStartDestination.Search,
                SableStartDestination.Peek,
                -> returnDestination
                SableStartDestination.Apps,
                SableStartDestination.Live,
                SableStartDestination.Appearance,
                -> SableStartDestination.Start
            }
    }

    BackHandler(enabled = destination != SableStartDestination.Start) {
        navigateBack()
    }

    SableTheme(appearance = appearance) {
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
                when (destination) {
                    SableStartDestination.Start ->
                        StartScreen(
                            snapshot = liveSnapshot,
                            primaryApps = choosePrimaryApps(apps, pinnedApps),
                            favoriteApps = pinnedApps,
                            recentApps = recentApps,
                            appearance = appearance,
                            onLaunchApp = ::launchApp,
                            onOpenPeek = { app ->
                                openPeek(app, SableStartDestination.Start)
                            },
                            onOpenSettings = onOpenSettings,
                            onAllApps = {
                                destination = SableStartDestination.Apps
                            },
                            onSearch = {
                                openSearch(SableStartDestination.Start)
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
                                openSearch(SableStartDestination.Apps)
                            },
                            onLaunchApp = ::launchApp,
                            onOpenPeek = { app ->
                                openPeek(app, SableStartDestination.Apps)
                            },
                        )

                    SableStartDestination.Search ->
                        SearchScreen(
                            apps = apps,
                            onBack = ::navigateBack,
                            onLaunchApp = ::launchApp,
                            onOpenPeek = { app ->
                                openPeek(app, SableStartDestination.Search)
                            },
                            onAllApps = {
                                destination = SableStartDestination.Apps
                            },
                            onAppearance = {
                                destination = SableStartDestination.Appearance
                            },
                            onLive = {
                                destination = SableStartDestination.Live
                            },
                            onOpenSettings = onOpenSettings,
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

                    SableStartDestination.Peek -> {
                        val app = selectedApp
                        if (app == null) {
                            destination = returnDestination
                        } else {
                            val key = app.stableKey()
                            SablePeekScreen(
                                app = app,
                                isPinned = key in pinnedKeys,
                                onClose = ::navigateBack,
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
        }
    }
}

@Composable
private fun StartScreen(
    snapshot: LiveSurfaceSnapshot,
    primaryApps: List<AppEntry>,
    favoriteApps: List<AppEntry>,
    recentApps: List<AppEntry>,
    appearance: SableAppearance,
    onLaunchApp: (AppEntry) -> Unit,
    onOpenPeek: (AppEntry) -> Unit,
    onOpenSettings: () -> Unit,
    onAllApps: () -> Unit,
    onSearch: () -> Unit,
    onLive: () -> Unit,
    onAppearance: () -> Unit,
) {
    val contextDatum = chooseContextDatum(snapshot)
    val quickApps =
        if (favoriteApps.isNotEmpty()) {
            favoriteApps.take(MAX_FAVORITES_ON_START)
        } else {
            recentApps.take(MAX_FAVORITES_ON_START)
        }

    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding =
            PaddingValues(
                start = 20.dp,
                end = 20.dp,
                top = 18.dp,
                bottom = 36.dp,
            ),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        item {
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.Bottom,
                horizontalArrangement = Arrangement.SpaceBetween,
            ) {
                Column {
                    Text(
                        text = snapshot.timeText,
                        style = MaterialTheme.typography.displayLarge,
                        fontWeight = FontWeight.Light,
                    )
                    Text(
                        text = snapshot.dateText,
                        style = MaterialTheme.typography.bodyLarge,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
                TextButton(onClick = onAppearance) {
                    Text(
                        text = appearance.accent.displayName,
                        color = appearance.accent.color,
                    )
                }
            }
        }

        if (contextDatum != null) {
            item {
                ContextCard(
                    datum = contextDatum,
                    accent = appearance.accent.color,
                    onClick = onLive,
                )
            }
        }

        item {
            SectionLabel("start")
            Spacer(Modifier.height(8.dp))

            val tilePalette =
                listOf(appearance.accent.color) +
                    SableTilePalette.filterNot { it == appearance.accent.color }
            val appTiles =
                primaryApps.mapIndexed { index, app ->
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
                    .take(MAX_START_TILES)

            TileGrid(tiles)
        }

        item {
            SectionLabel("favorites")
            Spacer(Modifier.height(4.dp))

            if (quickApps.isEmpty()) {
                Text(
                    text = "Pin apps from All Apps to keep them in thumb reach.",
                    style = MaterialTheme.typography.bodyLarge,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.padding(vertical = 10.dp),
                )
            } else {
                quickApps.forEach { app ->
                    CompactAppRow(
                        app = app,
                        onClick = { onLaunchApp(app) },
                        onContext = { onOpenPeek(app) },
                    )
                }
            }
        }

        item {
            SearchLaunchButton(onClick = onSearch)
            Spacer(Modifier.height(6.dp))
            MetroLink("all apps  →", onAllApps)
            MetroLink("local context  →", onLive)
        }
    }
}

@Composable
private fun ContextCard(
    datum: LiveDatum,
    accent: Color,
    onClick: () -> Unit,
) {
    Row(
        modifier =
            Modifier
                .fillMaxWidth()
                .heightIn(min = 76.dp)
                .clip(RoundedCornerShape(6.dp))
                .background(MaterialTheme.colorScheme.surfaceVariant)
                .clickable(onClick = onClick)
                .padding(horizontal = 16.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(
            modifier =
                Modifier
                    .size(8.dp)
                    .clip(RoundedCornerShape(4.dp))
                    .background(accent),
        )
        Spacer(Modifier.width(12.dp))
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = datum.title.lowercase(Locale.getDefault()),
                style = MaterialTheme.typography.labelLarge,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            Text(
                text = datum.detail,
                style = MaterialTheme.typography.titleLarge,
            )
        }
        Text(
            text = "›",
            fontSize = 28.sp,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
}

@Composable
private fun TileGrid(tiles: List<HomeTile>) {
    Column(
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        tiles.chunked(2).forEach { rowTiles ->
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
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
                .height(118.dp)
                .clip(RoundedCornerShape(5.dp))
                .background(color)
                .clickable(onClick = onClick)
                .padding(13.dp),
        verticalArrangement = Arrangement.SpaceBetween,
    ) {
        Text(
            text = mark,
            fontSize = 25.sp,
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
private fun SearchLaunchButton(
    onClick: () -> Unit,
) {
    Row(
        modifier =
            Modifier
                .fillMaxWidth()
                .heightIn(min = 54.dp)
                .clip(RoundedCornerShape(6.dp))
                .background(MaterialTheme.colorScheme.surfaceVariant)
                .clickable(onClick = onClick)
                .padding(horizontal = 16.dp, vertical = 14.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            text = "⌕",
            fontSize = 24.sp,
        )
        Spacer(Modifier.width(12.dp))
        Column {
            Text(
                text = "Search / Command",
                style = MaterialTheme.typography.bodyLarge,
            )
            Text(
                text = "apps · settings · Sable actions",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    }
}

@Composable
private fun AppsScreen(
    apps: List<AppEntry>,
    onBack: () -> Unit,
    onSearch: () -> Unit,
    onLaunchApp: (AppEntry) -> Unit,
    onOpenPeek: (AppEntry) -> Unit,
) {
    val rows = remember(apps) { buildRailRows(apps) }
    val letters = remember(rows) { rows.map { it.section }.distinct() }
    val listState = rememberLazyListState()
    val scope = rememberCoroutineScope()
    var activeLetter by remember(letters) {
        mutableStateOf(letters.firstOrNull().orEmpty())
    }

    Box(
        modifier =
            Modifier
                .fillMaxSize()
                .padding(top = 18.dp, bottom = 18.dp),
    ) {
        Column(
            modifier =
                Modifier
                    .fillMaxSize()
                    .padding(start = 20.dp, end = 38.dp),
        ) {
            MetroHeader(
                title = "all apps",
                onBack = onBack,
            )
            Spacer(Modifier.height(8.dp))
            SearchLaunchButton(onClick = onSearch)
            Spacer(Modifier.height(12.dp))

            if (rows.isEmpty()) {
                EmptyState("No launchable apps are available.")
            } else {
                LazyColumn(
                    modifier = Modifier.fillMaxSize(),
                    state = listState,
                    contentPadding = PaddingValues(bottom = 24.dp),
                ) {
                    items(
                        items = rows,
                        key = { it.app.stableKey() },
                    ) { row ->
                        if (row.startsSection) {
                            Text(
                                text = row.section,
                                style = MaterialTheme.typography.headlineLarge,
                                color = MaterialTheme.colorScheme.primary,
                                modifier = Modifier.padding(top = 12.dp, bottom = 4.dp),
                            )
                        }
                        AppRow(
                            app = row.app,
                            onClick = { onLaunchApp(row.app) },
                            onContext = { onOpenPeek(row.app) },
                        )
                    }
                }
            }
        }

        if (letters.isNotEmpty()) {
            Box(
                modifier =
                    Modifier
                        .align(Alignment.CenterStart)
                        .fillMaxHeight()
                        .width(22.dp)
                        .pointerInput(letters, rows) {
                            fun jumpTo(y: Float) {
                                if (letters.isEmpty() || size.height <= 0) return
                                val slot =
                                    ((y / size.height) * letters.size)
                                        .toInt()
                                        .coerceIn(0, letters.lastIndex)
                                val letter = letters[slot]
                                val index = rows.indexOfFirst { it.section == letter }
                                if (index >= 0) {
                                    activeLetter = letter
                                    scope.launch {
                                        listState.scrollToItem(index)
                                    }
                                }
                            }

                            detectDragGestures(
                                onDragStart = { offset -> jumpTo(offset.y) },
                                onDrag = { change, _ ->
                                    jumpTo(change.position.y)
                                    change.consume()
                                },
                            )
                        },
            )

            Column(
                modifier =
                    Modifier
                        .align(Alignment.CenterEnd)
                        .width(38.dp)
                        .pointerInput(letters, rows) {
                            fun jumpTo(y: Float) {
                                if (letters.isEmpty() || size.height <= 0) return
                                val slot =
                                    ((y / size.height) * letters.size)
                                        .toInt()
                                        .coerceIn(0, letters.lastIndex)
                                val letter = letters[slot]
                                val index = rows.indexOfFirst { it.section == letter }
                                if (index >= 0) {
                                    activeLetter = letter
                                    scope.launch {
                                        listState.scrollToItem(index)
                                    }
                                }
                            }

                            detectDragGestures(
                                onDragStart = { offset -> jumpTo(offset.y) },
                                onDrag = { change, _ ->
                                    jumpTo(change.position.y)
                                    change.consume()
                                },
                            )
                        },
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                letters.forEach { letter ->
                    val selected = letter == activeLetter
                    Text(
                        text = letter,
                        modifier =
                            Modifier
                                .clickable {
                                    val index = rows.indexOfFirst { it.section == letter }
                                    if (index >= 0) {
                                        activeLetter = letter
                                        scope.launch {
                                            listState.animateScrollToItem(index)
                                        }
                                    }
                                }
                                .padding(horizontal = 10.dp, vertical = 2.dp),
                        style = MaterialTheme.typography.labelLarge,
                        color =
                            if (selected) {
                                MaterialTheme.colorScheme.primary
                            } else {
                                MaterialTheme.colorScheme.onSurfaceVariant
                            },
                        fontWeight =
                            if (selected) {
                                FontWeight.Bold
                            } else {
                                FontWeight.Normal
                            },
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
    onOpenPeek: (AppEntry) -> Unit,
    onAllApps: () -> Unit,
    onAppearance: () -> Unit,
    onLive: () -> Unit,
    onOpenSettings: () -> Unit,
) {
    var query by remember { mutableStateOf("") }
    val normalizedQuery = query.trim()
    val locale = Locale.getDefault()
    val filteredApps =
        remember(apps, normalizedQuery) {
            if (normalizedQuery.isEmpty()) {
                apps.take(6)
            } else {
                apps.filter { app ->
                    app.label.contains(normalizedQuery, ignoreCase = true)
                }.take(12)
            }
        }

    val commands =
        listOf(
            SearchCommand(
                title = "All apps",
                subtitle = "Alphabetical launcher list",
                mark = "A",
                onClick = onAllApps,
            ),
            SearchCommand(
                title = "Appearance",
                subtitle = "Theme and Sable accent",
                mark = "◐",
                onClick = onAppearance,
            ),
            SearchCommand(
                title = "Local context",
                subtitle = "Calendar, photos and local media state",
                mark = "◫",
                onClick = onLive,
            ),
            SearchCommand(
                title = "System Settings",
                subtitle = "Open Android settings",
                mark = "⚙",
                onClick = onOpenSettings,
            ),
        )
    val filteredCommands =
        commands.filter { command ->
            normalizedQuery.isEmpty() ||
                command.title.lowercase(locale).contains(normalizedQuery.lowercase(locale)) ||
                command.subtitle.lowercase(locale).contains(normalizedQuery.lowercase(locale))
        }

    Column(
        modifier =
            Modifier
                .fillMaxSize()
                .padding(horizontal = 20.dp, vertical = 18.dp),
    ) {
        MetroHeader(
            title = "search",
            onBack = onBack,
        )
        Spacer(Modifier.height(10.dp))

        OutlinedTextField(
            value = query,
            onValueChange = { query = it },
            modifier = Modifier.fillMaxWidth(),
            singleLine = true,
            shape = RoundedCornerShape(6.dp),
            label = { Text("Search apps and Sable actions") },
        )

        Spacer(Modifier.height(14.dp))

        LazyColumn(
            modifier = Modifier.fillMaxSize(),
            contentPadding = PaddingValues(bottom = 24.dp),
        ) {
            if (filteredCommands.isNotEmpty()) {
                item {
                    SectionLabel(
                        if (normalizedQuery.isEmpty()) {
                            "quick actions"
                        } else {
                            "commands"
                        },
                    )
                }
                items(filteredCommands) { command ->
                    SearchCommandRow(command)
                }
                item {
                    Spacer(Modifier.height(12.dp))
                }
            }

            if (filteredApps.isNotEmpty()) {
                item {
                    SectionLabel("apps")
                }
                items(
                    items = filteredApps,
                    key = { it.stableKey() },
                ) { app ->
                    AppRow(
                        app = app,
                        onClick = { onLaunchApp(app) },
                        onContext = { onOpenPeek(app) },
                    )
                }
            } else if (filteredCommands.isEmpty()) {
                item {
                    EmptyState("No local results match “$normalizedQuery”.")
                }
            }
        }
    }
}

@Composable
private fun SearchCommandRow(
    command: SearchCommand,
) {
    Row(
        modifier =
            Modifier
                .fillMaxWidth()
                .heightIn(min = 58.dp)
                .clickable(onClick = command.onClick)
                .padding(vertical = 6.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(
            modifier =
                Modifier
                    .size(42.dp)
                    .clip(RoundedCornerShape(6.dp))
                    .background(MaterialTheme.colorScheme.surfaceVariant),
            contentAlignment = Alignment.Center,
        ) {
            Text(
                text = command.mark,
                fontWeight = FontWeight.Bold,
            )
        }
        Spacer(Modifier.width(14.dp))
        Column {
            Text(
                text = command.title,
                style = MaterialTheme.typography.bodyLarge,
            )
            Text(
                text = command.subtitle,
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
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
            AppMark(app = app, size = 42)
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
                text = "›",
                fontSize = 26.sp,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    }
}

@Composable
private fun CompactAppRow(
    app: AppEntry,
    onClick: () -> Unit,
    onContext: () -> Unit,
) {
    Row(
        modifier =
            Modifier
                .fillMaxWidth()
                .heightIn(min = 54.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Row(
            modifier =
                Modifier
                    .weight(1f)
                    .clickable(onClick = onClick)
                    .padding(vertical = 6.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            AppMark(app = app, size = 36)
            Spacer(Modifier.width(12.dp))
            Text(
                text = app.label,
                style = MaterialTheme.typography.bodyLarge,
                maxLines = 1,
            )
        }
        TextButton(onClick = onContext) {
            Text("⋯")
        }
    }
}

@Composable
private fun AppMark(
    app: AppEntry,
    size: Int,
) {
    Box(
        modifier =
            Modifier
                .size(size.dp)
                .clip(RoundedCornerShape(6.dp))
                .background(appColor(app)),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = appMark(app),
            fontWeight = FontWeight.Bold,
        )
    }
}

@Composable
private fun SablePeekScreen(
    app: AppEntry,
    isPinned: Boolean,
    onClose: () -> Unit,
    onOpen: () -> Unit,
    onOpenAppInfo: () -> Unit,
    onTogglePinned: () -> Unit,
) {
    Box(
        modifier =
            Modifier
                .fillMaxSize()
                .background(MaterialTheme.colorScheme.background),
    ) {
        TextButton(
            onClick = onClose,
            modifier =
                Modifier
                    .align(Alignment.TopStart)
                    .padding(10.dp),
        ) {
            Text("Close")
        }

        Surface(
            modifier =
                Modifier
                    .align(Alignment.BottomCenter)
                    .fillMaxWidth()
                    .padding(12.dp),
            color = MaterialTheme.colorScheme.surfaceVariant,
            shape = RoundedCornerShape(6.dp),
        ) {
            Column(
                modifier = Modifier.padding(20.dp),
            ) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    AppMark(app = app, size = 54)
                    Spacer(Modifier.width(14.dp))
                    Column(modifier = Modifier.weight(1f)) {
                        Text(
                            text = app.label,
                            style = MaterialTheme.typography.headlineLarge,
                        )
                        Text(
                            text = "Sable Peek",
                            style = MaterialTheme.typography.bodyMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                }

                Spacer(Modifier.height(20.dp))

                Button(
                    onClick = onOpen,
                    modifier =
                        Modifier
                            .fillMaxWidth()
                            .height(54.dp),
                    shape = RoundedCornerShape(6.dp),
                ) {
                    Text("Open")
                }

                Spacer(Modifier.height(8.dp))

                ContextAction(
                    mark = if (isPinned) "−" else "+",
                    label = if (isPinned) "Unpin from Favorites" else "Pin to Favorites",
                    onClick = onTogglePinned,
                )
                ContextAction(
                    mark = "ⓘ",
                    label = "Permissions & app info",
                    onClick = onOpenAppInfo,
                )

                Text(
                    text = "Published app shortcuts and notification content stay hidden until their Android capability and privacy gates are wired.",
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.padding(top = 12.dp),
                )
            }
        }
    }
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
                .padding(horizontal = 20.dp, vertical = 18.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        item {
            MetroHeader(
                title = "appearance",
                onBack = onBack,
            )
            Spacer(Modifier.height(8.dp))
            SectionLabel("theme")
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
            SectionLabel("accent")
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
private fun LiveSurfaceScreen(
    snapshot: LiveSurfaceSnapshot,
    onBack: () -> Unit,
    onRequestPermissions: () -> Unit,
) {
    LazyColumn(
        modifier =
            Modifier
                .fillMaxSize()
                .padding(horizontal = 20.dp, vertical = 18.dp),
        contentPadding = PaddingValues(bottom = 28.dp),
    ) {
        item {
            MetroHeader(
                title = "local context",
                onBack = onBack,
            )
            Spacer(Modifier.height(12.dp))
            Text(
                text = snapshot.timeText,
                style = MaterialTheme.typography.displayLarge,
            )
            Text(
                text = snapshot.dateText,
                style = MaterialTheme.typography.bodyLarge,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            Spacer(Modifier.height(18.dp))
        }

        item {
            LiveCard("17", snapshot.calendar)
            Spacer(Modifier.height(8.dp))
            LiveCard("♪", snapshot.music)
            Spacer(Modifier.height(8.dp))
            LiveCard("▣", snapshot.photos)
            Spacer(Modifier.height(14.dp))
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
                Spacer(Modifier.height(14.dp))
            }
        }

        item {
            Text(
                text = "Weather and tasks remain unavailable until explicit providers are configured.",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            Spacer(Modifier.height(8.dp))
            Text(
                text = "SableStart does not perform ambient network search or invent remote context.",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
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
                .background(MaterialTheme.colorScheme.surfaceVariant)
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
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            if (!datum.detail.equals(status, ignoreCase = true)) {
                Text(
                    status,
                    style = MaterialTheme.typography.labelLarge,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
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
        color = MaterialTheme.colorScheme.onSurface,
        modifier = Modifier.semantics { heading() },
    )
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

private fun buildRailRows(apps: List<AppEntry>): List<AppRailRow> {
    val locale = Locale.getDefault()
    val sorted =
        apps.sortedWith(
            compareBy<AppEntry> { it.label.lowercase(locale) }
                .thenBy { it.component.packageName }
                .thenBy { it.component.className },
        )

    return sorted.mapIndexed { index, app ->
        val section = alphabetSection(app.label, locale)
        AppRailRow(
            app = app,
            section = section,
            startsSection =
                index == 0 ||
                    alphabetSection(sorted[index - 1].label, locale) != section,
        )
    }
}

private fun alphabetSection(
    label: String,
    locale: Locale,
): String {
    val first =
        label
            .trim()
            .firstOrNull()
            ?.toString()
            ?.uppercase(locale)
            .orEmpty()

    return if (first.firstOrNull()?.isLetter() == true) first else "#"
}

private fun choosePrimaryApps(
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

    PRIMARY_APP_LABELS.forEach { preferred ->
        candidates.firstOrNull { app ->
            app.label.equals(preferred, ignoreCase = true)
        }?.let { app ->
            selected.putIfAbsent(app.stableKey(), app)
        }
    }

    candidates.forEach { app ->
        selected.putIfAbsent(app.stableKey(), app)
    }

    return selected.values.take(MAX_PRIMARY_APPS)
}

private fun chooseContextDatum(snapshot: LiveSurfaceSnapshot): LiveDatum? =
    when {
        snapshot.calendar.availability == LiveAvailability.LIVE -> snapshot.calendar
        snapshot.music.availability == LiveAvailability.LIVE -> snapshot.music
        snapshot.photos.availability == LiveAvailability.LIVE -> snapshot.photos
        else -> null
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

private val PRIMARY_APP_LABELS =
    listOf(
        "Sable Mail",
        "Sable Messages",
        "Messages",
        "Phone",
        "Calendar",
        "Photos",
        "Sable Media",
        "Camera",
        "Sable Calculator",
        "Calculator",
        "Files",
        "Vanadium",
    )

private const val MAX_PRIMARY_APPS = 3
private const val MAX_START_TILES = 4
private const val MAX_FAVORITES_ON_START = 6
private const val MAX_SESSION_RECENTS = 8
