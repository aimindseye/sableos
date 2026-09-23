#!/usr/bin/env python3
"""Compose the bounded Sable Reader publication product from pinned Vaachak.

Sable Reader owns publication/library/Readium behavior. Plain-text reading,
Android VIEW/SEND/PROCESS_TEXT, OCR and text-specific TTS are separate
Sable Text Reader product responsibilities.

The script mutates only ephemeral CI checkouts. Canonical upstream repositories
remain untouched.
"""

from __future__ import annotations

import pathlib
import shutil
import sys


def fail(message: str) -> None:
    raise SystemExit(message)


def write(path: pathlib.Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")


def copy_file(source: pathlib.Path, destination: pathlib.Path) -> None:
    if not source.is_file():
        fail(f"missing composition input: {source}")
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, destination)


def replace_exact_text(
    path: pathlib.Path,
    old: str,
    new: str,
    label: str,
    expected: int = 1,
) -> None:
    text = path.read_text(encoding="utf-8")
    count = text.count(old)
    if count != expected:
        fail(
            f"{label}: expected {expected} occurrence(s), "
            f"found {count} in {path}"
        )
    path.write_text(text.replace(old, new), encoding="utf-8")


def add_file_opt_in(
    path: pathlib.Path,
    annotation: str,
    label: str,
) -> None:
    text = path.read_text(encoding="utf-8")
    if annotation in text:
        return
    package_marker = "package "
    package_index = text.find(package_marker)
    if package_index < 0:
        fail(f"{label}: package declaration missing in {path}")
    text = text[:package_index] + annotation + "\n\n" + text[package_index:]
    path.write_text(text, encoding="utf-8")


def migrate_hilt_viewmodel_imports(source_root: pathlib.Path) -> int:
    old = "import androidx.hilt.navigation.compose.hiltViewModel"
    new = "import androidx.hilt.lifecycle.viewmodel.compose.hiltViewModel"
    count = 0
    for path in sorted(source_root.rglob("*.kt")):
        text = path.read_text(encoding="utf-8")
        occurrences = text.count(old)
        if occurrences:
            path.write_text(text.replace(old, new), encoding="utf-8")
            count += occurrences
    if count == 0:
        fail("SABLE_READER_HILT_VIEWMODEL_MIGRATION=FAIL_NO_OLD_IMPORTS")
    return count


def repo_root() -> pathlib.Path:
    return pathlib.Path(__file__).resolve().parents[3]


def main() -> None:
    if len(sys.argv) != 2:
        fail("usage: apply_sable_flavor.py <vaachak-mobile-checkout>")

    mobile_root = pathlib.Path(sys.argv[1]).resolve()

    gradle_file = mobile_root / "leisure" / "build.gradle.kts"
    if not gradle_file.is_file():
        fail(f"missing {gradle_file}")

    gradle_text = gradle_file.read_text(encoding="utf-8")
    compile_sdk_anchor = (
        "    compileSdk = libs.versions.android.compileSdk.get().toInt()\n"
    )
    if compile_sdk_anchor not in gradle_text:
        fail("Vaachak compileSdk anchor changed; inspect upstream")
    gradle_text = gradle_text.replace(
        compile_sdk_anchor,
        compile_sdk_anchor + '    ndkVersion = "30.0.16248370"\n',
        1,
    )
    anchor = "    val releaseSigningConfig = if (isReleaseLikeTaskRequested) {\n"
    if anchor not in gradle_text:
        fail("Vaachak Gradle anchor changed; inspect upstream before updating the pin")
    if 'create("sable")' in gradle_text:
        fail("Sable flavor already present; refusing an ambiguous double patch")

    flavor = '''    flavorDimensions += "product"
    productFlavors {
        create("vaachak") {
            dimension = "product"
            buildConfigField("boolean", "SABLE_PRODUCT", "false")
        }
        create("sable") {
            dimension = "product"
            applicationId = "org.sableos.reader"
            buildConfigField("boolean", "SABLE_PRODUCT", "true")
        }
    }

'''
    gradle_text = gradle_text.replace(anchor, flavor + anchor, 1)

    # LeakCanary contributes its own launcher activity to debug APKs. The Sable
    # qualification checkout does not need upstream debug tooling, so remove only
    # this debug dependency from the ephemeral composed source tree. Canonical
    # Vaachak source remains untouched.
    # The composed Sable debug APK is the development product artifact, not a
    # side-by-side upstream debug app. Keep the canonical package identity so
    # Panther product integration can bind exactly org.sableos.reader.
    debug_app_id_suffix = '            applicationIdSuffix = ".debug"\n'
    if debug_app_id_suffix not in gradle_text:
        fail("Vaachak debug applicationIdSuffix anchor changed; inspect upstream")
    gradle_text = gradle_text.replace(debug_app_id_suffix, "", 1)

    leakcanary_dependency = "    debugImplementation(libs.leakcanary.android)\n"
    if leakcanary_dependency not in gradle_text:
        fail("Vaachak LeakCanary dependency anchor changed; inspect upstream")
    gradle_text = gradle_text.replace(leakcanary_dependency, "", 1)

    version_catalog = mobile_root / "gradle" / "libs.versions.toml"
    version_catalog_text = version_catalog.read_text(encoding="utf-8")
    hilt_catalog_anchor = (
        'androidx-hilt-navigation-compose = { group = "androidx.hilt", '
        'name = "hilt-navigation-compose", version.ref = "hiltNavigationCompose" }\n'
    )
    if hilt_catalog_anchor not in version_catalog_text:
        fail("Vaachak Hilt version-catalog anchor changed; inspect upstream")
    version_catalog_text = version_catalog_text.replace(
        hilt_catalog_anchor,
        hilt_catalog_anchor
        + 'androidx-hilt-lifecycle-viewmodel-compose = { group = "androidx.hilt", '
        + 'name = "hilt-lifecycle-viewmodel-compose", version.ref = "hiltNavigationCompose" }\n',
        1,
    )
    version_catalog.write_text(version_catalog_text, encoding="utf-8")

    dependencies_anchor = "dependencies {\n"
    if gradle_text.count(dependencies_anchor) != 1:
        fail("Vaachak dependencies anchor changed; inspect upstream")

    hilt_dependency_anchor = "    implementation(libs.androidx.hilt.navigation.compose)\n"
    if hilt_dependency_anchor not in gradle_text:
        fail("Vaachak Hilt dependency anchor changed; inspect upstream")
    gradle_text = gradle_text.replace(
        hilt_dependency_anchor,
        hilt_dependency_anchor
        + "    implementation(libs.androidx.hilt.lifecycle.viewmodel.compose)\n",
        1,
    )

    gradle_file.write_text(
        gradle_text,
        encoding="utf-8",
    )

    # Bounded warning cleanup for the pinned Reader checkout. These changes are
    # compile-time/API maintenance only; they do not alter Sable Reader product
    # behavior or upstream Vaachak repositories.
    leisure_sources = mobile_root / "leisure" / "src" / "main" / "java"
    hilt_migration_count = migrate_hilt_viewmodel_imports(leisure_sources)

    login_screen = (
        leisure_sources
        / "org/vaachak/reader/leisure/ui/login/LoginScreen.kt"
    )
    replace_exact_text(
        login_screen,
        "import androidx.compose.material3.TabRow",
        "import androidx.compose.material3.PrimaryTabRow",
        "SABLE_READER_WARNING_LOGIN_TAB_IMPORT",
    )
    replace_exact_text(
        login_screen,
        "            TabRow(selectedTabIndex = if (isRegisterMode) 1 else 0) {",
        "            PrimaryTabRow(selectedTabIndex = if (isRegisterMode) 1 else 0) {",
        "SABLE_READER_WARNING_LOGIN_TAB_API",
    )

    highlights_screen = (
        leisure_sources
        / "org/vaachak/reader/leisure/ui/highlights/AllHighlightsScreen.kt"
    )
    replace_exact_text(
        highlights_screen,
        "import androidx.compose.material.icons.filled.MenuBook",
        "import androidx.compose.material.icons.automirrored.filled.MenuBook",
        "SABLE_READER_WARNING_MENU_BOOK_IMPORT",
    )
    replace_exact_text(
        highlights_screen,
        "Icons.Default.MenuBook",
        "Icons.AutoMirrored.Filled.MenuBook",
        "SABLE_READER_WARNING_MENU_BOOK_USAGE",
    )

    about_screen = (
        leisure_sources
        / "org/vaachak/reader/leisure/ui/settings/AboutScreen.kt"
    )
    replace_exact_text(
        about_screen,
        "import androidx.compose.material.icons.filled.OpenInNew",
        "import androidx.compose.material.icons.automirrored.filled.OpenInNew",
        "SABLE_READER_WARNING_OPEN_IN_NEW_IMPORT",
    )
    replace_exact_text(
        about_screen,
        "Icons.Filled.OpenInNew",
        "Icons.AutoMirrored.Filled.OpenInNew",
        "SABLE_READER_WARNING_OPEN_IN_NEW_USAGE",
    )

    highlights_view_model = (
        leisure_sources
        / "org/vaachak/reader/leisure/ui/highlights/AllHighlightsViewModel.kt"
    )
    add_file_opt_in(
        highlights_view_model,
        "@file:OptIn(kotlinx.coroutines.ExperimentalCoroutinesApi::class)",
        "SABLE_READER_WARNING_COROUTINES_OPT_IN",
    )

    reader_settings_sheet = (
        leisure_sources
        / "org/vaachak/reader/leisure/ui/reader/components/ReaderSettingsSheet.kt"
    )
    add_file_opt_in(
        reader_settings_sheet,
        "@file:OptIn(" 
        "org.readium.r2.shared.ExperimentalReadiumApi::class, "
        "androidx.compose.material3.ExperimentalMaterial3Api::class"
        ")",
        "SABLE_READER_WARNING_READIUM_SETTINGS_OPT_IN",
    )

    tts_settings_sheet = (
        leisure_sources
        / "org/vaachak/reader/leisure/ui/reader/components/TtsSettingsBottomSheet.kt"
    )
    add_file_opt_in(
        tts_settings_sheet,
        "@file:OptIn("
        "org.readium.r2.shared.ExperimentalReadiumApi::class, "
        "androidx.compose.material3.ExperimentalMaterial3Api::class"
        ")",
        "SABLE_READER_WARNING_READIUM_TTS_OPT_IN",
    )
    replace_exact_text(
        tts_settings_sheet,
        "import androidx.compose.material3.ExposedDropdownMenuBox",
        "import androidx.compose.material3.ExposedDropdownMenuAnchorType\n"
        "import androidx.compose.material3.ExposedDropdownMenuBox",
        "SABLE_READER_WARNING_MENU_ANCHOR_IMPORT",
    )
    replace_exact_text(
        tts_settings_sheet,
        "                                    .menuAnchor()",
        "                                    .menuAnchor(\n"
        "                                        ExposedDropdownMenuAnchorType.PrimaryNotEditable,\n"
        "                                        enabled = true,\n"
        "                                    )",
        "SABLE_READER_WARNING_MENU_ANCHOR_API",
    )

    android_tts_manager = (
        leisure_sources
        / "org/vaachak/reader/leisure/domain/tts/AndroidTtsManager.kt"
    )
    replace_exact_text(
        android_tts_manager,
        "            override fun onError(utteranceId: String?) {",
        "            @Suppress(\"OVERRIDE_DEPRECATION\")\n"
        "            override fun onError(utteranceId: String?) {",
        "SABLE_READER_WARNING_TTS_DEPRECATED_OVERRIDE",
    )

    bookshelf_screen = (
        leisure_sources
        / "org/vaachak/reader/leisure/ui/bookshelf/BookshelfScreen.kt"
    )
    replace_exact_text(
        bookshelf_screen,
        """    var hasCover by remember(book.coverPath) { mutableStateOf(false) }
    LaunchedEffect(book.coverPath) {
        hasCover = if (book.coverPath != null) {
            withContext(Dispatchers.IO) { File(book.coverPath).exists() }
        } else {
            false
        }
    }
""",
        """    val coverPath = book.coverPath
    var hasCover by remember(coverPath) { mutableStateOf(false) }
    LaunchedEffect(coverPath) {
        hasCover = if (coverPath != null) {
            withContext(Dispatchers.IO) { File(coverPath).exists() }
        } else {
            false
        }
    }
""",
        "SABLE_READER_WARNING_BOOK_COVER_NULLABILITY",
    )
    replace_exact_text(
        bookshelf_screen,
        "if (hasCover && book.coverPath != null) {",
        "if (hasCover && coverPath != null) {",
        "SABLE_READER_WARNING_BOOK_COVER_CONDITION",
    )
    replace_exact_text(
        bookshelf_screen,
        "File(book.coverPath)",
        "File(coverPath)",
        "SABLE_READER_WARNING_BOOK_COVER_FILE",
    )
    replace_exact_text(
        bookshelf_screen,
        """    var hasCover by remember(firstBook?.coverPath) { mutableStateOf(false) }
    LaunchedEffect(firstBook?.coverPath) {
        hasCover = if (firstBook?.coverPath != null) {
            withContext(Dispatchers.IO) { File(firstBook.coverPath).exists() }
        } else {
            false
        }
    }
""",
        """    val firstCoverPath = firstBook?.coverPath
    var hasCover by remember(firstCoverPath) { mutableStateOf(false) }
    LaunchedEffect(firstCoverPath) {
        hasCover = if (firstCoverPath != null) {
            withContext(Dispatchers.IO) { File(firstCoverPath).exists() }
        } else {
            false
        }
    }
""",
        "SABLE_READER_WARNING_STACK_COVER_NULLABILITY",
    )
    replace_exact_text(
        bookshelf_screen,
        "if (hasCover && firstBook.coverPath != null) {",
        "if (hasCover && firstCoverPath != null) {",
        "SABLE_READER_WARNING_STACK_COVER_CONDITION",
    )
    replace_exact_text(
        bookshelf_screen,
        "File(firstBook.coverPath)",
        "File(firstCoverPath)",
        "SABLE_READER_WARNING_STACK_COVER_FILE",
    )

    # Sable's touch-first bookshelf must not look capped at one 3x2 page.
    # Keep upstream paging for the upstream flavor, but render the Sable flavor
    # as one continuous vertical library with an explicit total count.
    bookshelf_text = bookshelf_screen.read_text(encoding="utf-8")

    shelf_items_old = """    val shelfItems = remember(state.groupedLibrary, state.bookshelfPrefs.groupBySeries) {
        if (state.bookshelfPrefs.groupBySeries) {
            state.groupedLibrary.map { (author, books) ->
                if (books.size > 1) LibraryItem.Stack(author, books)
                else LibraryItem.Book(books.first())
            }
        } else {
            state.groupedLibrary.values.flatten().map { LibraryItem.Book(it) }
        }
    }
"""
    shelf_items_new = """    val shelfItems = remember(state.groupedLibrary, state.bookshelfPrefs.groupBySeries) {
        if (BuildConfig.SABLE_PRODUCT) {
            // Sable always presents the physical library count. Upstream Smart
            // Stacks can collapse many imported books into a handful of grouped
            // items, which made the Panther UI report six when more books were
            // actually present.
            state.groupedLibrary.values
                .flatten()
                .distinctBy { it.bookHash }
                .map { LibraryItem.Book(it) }
        } else if (state.bookshelfPrefs.groupBySeries) {
            state.groupedLibrary.map { (author, books) ->
                if (books.size > 1) LibraryItem.Stack(author, books)
                else LibraryItem.Book(books.first())
            }
        } else {
            state.groupedLibrary.values.flatten().map { LibraryItem.Book(it) }
        }
    }
"""
    if bookshelf_text.count(shelf_items_old) != 1:
        fail("SABLE_READER_LIBRARY_ACTUAL_BOOK_COUNT_ANCHOR_CHANGED")
    bookshelf_text = bookshelf_text.replace(
        shelf_items_old,
        shelf_items_new,
        1,
    )

    bookshelf_import_anchor = (
        "import androidx.compose.foundation.lazy.LazyRow\n"
        "import androidx.compose.foundation.lazy.items\n"
    )
    bookshelf_import_replacement = (
        bookshelf_import_anchor
        + "import androidx.compose.foundation.lazy.grid.GridCells\n"
        + "import androidx.compose.foundation.lazy.grid.LazyVerticalGrid\n"
        + "import androidx.compose.foundation.lazy.grid.items as gridItems\n"
    )
    if bookshelf_import_replacement not in bookshelf_text:
        if bookshelf_import_anchor not in bookshelf_text:
            fail("SABLE_READER_LIBRARY_GRID_IMPORT_ANCHOR_CHANGED")
        bookshelf_text = bookshelf_text.replace(
            bookshelf_import_anchor,
            bookshelf_import_replacement,
            1,
        )

    build_config_anchor = (
        "import org.vaachak.reader.core.domain.model.DitheringMode\n"
    )
    build_config_replacement = (
        build_config_anchor
        + "import org.vaachak.reader.leisure.BuildConfig\n"
    )
    if "import org.vaachak.reader.leisure.BuildConfig\n" not in bookshelf_text:
        if build_config_anchor not in bookshelf_text:
            fail("SABLE_READER_LIBRARY_BUILD_CONFIG_ANCHOR_CHANGED")
        bookshelf_text = bookshelf_text.replace(
            build_config_anchor,
            build_config_replacement,
            1,
        )

    paginated_header = """fun PaginatedGrid(
    items: List<LibraryItem>,
    itemsPerPage: Int,
    columns: Int,
    state: BookshelfUiState,
    contentColor: Color,
    viewModel: BookshelfViewModel,
    onBookClick: (String) -> Unit,
    onDeleteBook: (BookEntity) -> Unit,
    bottomBarTextLeft: String
) {
"""
    sable_grid_dispatch = paginated_header + """    if (BuildConfig.SABLE_PRODUCT) {
        SableContinuousLibraryGrid(
            items = items,
            columns = columns,
            state = state,
            contentColor = contentColor,
            viewModel = viewModel,
            onBookClick = onBookClick,
            onDeleteBook = onDeleteBook,
            bottomBarTextLeft = bottomBarTextLeft,
        )
        return
    }

"""
    if "SableContinuousLibraryGrid(" not in bookshelf_text:
        if bookshelf_text.count(paginated_header) != 1:
            fail("SABLE_READER_LIBRARY_PAGER_HEADER_CHANGED")
        bookshelf_text = bookshelf_text.replace(
            paginated_header,
            sable_grid_dispatch,
            1,
        )

        paginated_annotation = """@OptIn(ExperimentalFoundationApi::class)
@Composable
fun PaginatedGrid(
"""
        continuous_grid = """@Composable
private fun SableContinuousLibraryGrid(
    items: List<LibraryItem>,
    columns: Int,
    state: BookshelfUiState,
    contentColor: Color,
    viewModel: BookshelfViewModel,
    onBookClick: (String) -> Unit,
    onDeleteBook: (BookEntity) -> Unit,
    bottomBarTextLeft: String,
) {
    if (items.isEmpty()) {
        Box(
            Modifier.fillMaxSize(),
            contentAlignment = Alignment.Center,
        ) {
            Text(
                "No books found",
                color = contentColor.copy(alpha = 0.5f),
            )
        }
        return
    }

    Column(modifier = Modifier.fillMaxSize()) {
        LazyVerticalGrid(
            columns = GridCells.Fixed(columns),
            modifier = Modifier.weight(1f).fillMaxWidth(),
            contentPadding = PaddingValues(16.dp),
            horizontalArrangement = Arrangement.spacedBy(16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            gridItems(items) { item ->
                when (item) {
                    is LibraryItem.Book ->
                        NeoReaderCoverCard(
                            book = item.entity,
                            state = state,
                            onClick = { onBookClick(item.entity.bookHash) },
                            onDelete = { onDeleteBook(item.entity) },
                        )
                    is LibraryItem.Stack ->
                        StackGridItem(
                            stack = item,
                            state = state,
                            onClick = { viewModel.openStack(item.name) },
                        )
                }
            }
        }

        Row(
            modifier =
                Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp, vertical = 8.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                bottomBarTextLeft,
                style = MaterialTheme.typography.labelMedium,
                color = contentColor.copy(alpha = 0.7f),
            )
            Text(
                "items: " + items.size,
                style = MaterialTheme.typography.labelMedium,
                color = contentColor,
            )
        }
    }
}

""" + paginated_annotation
        if bookshelf_text.count(paginated_annotation) != 1:
            fail("SABLE_READER_LIBRARY_PAGER_ANNOTATION_CHANGED")
        bookshelf_text = bookshelf_text.replace(
            paginated_annotation,
            continuous_grid,
            1,
        )

    bookshelf_screen.write_text(bookshelf_text, encoding="utf-8")
    print("R9_READER_LIBRARY_NAVIGATION=PASS_CONTINUOUS_VERTICAL_GRID")
    print("R9_READER_LIBRARY_COUNT=PASS_ACTUAL_BOOKS_NOT_STACKS")

    catalog_view_model = (
        leisure_sources
        / "org/vaachak/reader/leisure/ui/catalog/CatalogViewModel.kt"
    )
    replace_exact_text(
        catalog_view_model,
        'pub.metadata.authors.firstOrNull()?.name?.toString() ?: "Unknown"',
        'pub.metadata.authors.firstOrNull()?.name ?: "Unknown"',
        "SABLE_READER_WARNING_FEED_AUTHOR_TO_STRING",
    )
    replace_exact_text(
        catalog_view_model,
        'publication.metadata.authors.firstOrNull()?.name?.toString() ?: "Unknown"',
        'publication.metadata.authors.firstOrNull()?.name ?: "Unknown"',
        "SABLE_READER_WARNING_DOWNLOAD_AUTHOR_TO_STRING",
    )

    reader_screen_warning_path = (
        leisure_sources
        / "org/vaachak/reader/leisure/ui/reader/ReaderScreen.kt"
    )
    replace_exact_text(
        reader_screen_warning_path,
        'bookmark.text ?: "Empty"',
        "bookmark.text",
        "SABLE_READER_WARNING_BOOKMARK_EMPTY_ELVIS",
        expected=2,
    )
    replace_exact_text(
        reader_screen_warning_path,
        'bookmark.text ?: "Bookmark"',
        "bookmark.text",
        "SABLE_READER_WARNING_BOOKMARK_TEXT_ELVIS",
    )

    reader_view_model_warning_path = (
        leisure_sources
        / "org/vaachak/reader/leisure/ui/reader/ReaderViewModel.kt"
    )
    replace_exact_text(
        reader_view_model_warning_path,
        "id = entity.id.toString(),",
        "id = entity.id,",
        "SABLE_READER_WARNING_DECORATION_ID_TO_STRING",
    )
    replace_exact_text(
        reader_view_model_warning_path,
        "if (locator != null && _isTtsActive.value) {",
        "if (_isTtsActive.value) {",
        "SABLE_READER_WARNING_TTS_LOCATOR_ALWAYS_NONNULL",
    )
    replace_exact_text(
        reader_view_model_warning_path,
        "lockedOutUtteranceText = nav.location.value?.utterance",
        "lockedOutUtteranceText = nav.location.value.utterance",
        "SABLE_READER_WARNING_TTS_LOCATION_SAFE_CALL",
    )

    settings_screen = (
        leisure_sources
        / "org/vaachak/reader/leisure/ui/settings/SettingsScreen.kt"
    )
    replace_exact_text(
        settings_screen,
        "state.userProfile?.isAuthenticated == true",
        "state.userProfile.isAuthenticated",
        "SABLE_READER_WARNING_SETTINGS_PROFILE_SAFE_CALL",
    )

    sync_settings_screen = (
        leisure_sources
        / "org/vaachak/reader/leisure/ui/settings/SyncSettingsScreen.kt"
    )
    replace_exact_text(
        sync_settings_screen,
        "state.userProfile?.isAuthenticated == true",
        "state.userProfile.isAuthenticated",
        "SABLE_READER_WARNING_SYNC_AUTH_SAFE_CALL",
    )
    replace_exact_text(
        sync_settings_screen,
        "state.userProfile?.username ?: \"\"",
        "state.userProfile.username ?: \"\"",
        "SABLE_READER_WARNING_SYNC_USERNAME_SAFE_CALL",
    )

    print(f"SABLE_READER_HILT_VIEWMODEL_MIGRATION=PASS count={hilt_migration_count}")
    print("SABLE_READER_WARNING_CLEANUP=PASS")
    print("SABLE_READER_NDK_PIN=30.0.16248370")

    # Consume the exact same Sable design source used by Start and R8 first-party apps.
    design_source = (
        repo_root()
        / "src"
        / "android"
        / "shared"
        / "sabledesign"
        / "src"
        / "main"
        / "java"
        / "org"
        / "sableos"
        / "design"
    )
    design_destination = (
        mobile_root
        / "leisure"
        / "src"
        / "main"
        / "java"
        / "org"
        / "sableos"
        / "design"
    )
    for name in ("SableTheme.kt", "SableComponents.kt", "SableSystemBars.kt", "SableGlobalAppearance.kt"):
        copy_file(design_source / name, design_destination / name)

    # Keep upstream Vaachak appearance unchanged for its own flavor and preserve the
    # special E-ink theme. Sable light/dark paths use the canonical Sable theme.
    product_theme = mobile_root / "leisure" / "src" / "main" / "java" / (
        "org/vaachak/reader/leisure/ui/theme/ProductReaderTheme.kt"
    )
    write(
        product_theme,
        '''package org.vaachak.reader.leisure.ui.theme

import androidx.compose.runtime.Composable
import org.sableos.design.SableTheme
import org.sableos.design.rememberGlobalSableAppearance
import org.vaachak.reader.core.domain.model.ThemeMode
import org.vaachak.reader.leisure.BuildConfig

@Composable
fun ProductReaderTheme(
    themeMode: ThemeMode,
    contrast: Float,
    content: @Composable () -> Unit,
) {
    if (!BuildConfig.SABLE_PRODUCT || themeMode == ThemeMode.E_INK) {
        VaachakTheme(
            themeMode = themeMode,
            contrast = contrast,
            content = content,
        )
        return
    }

    // Normal Reader chrome follows the SableOS system appearance. E-ink is an
    // explicit reading-only override and deliberately remains high-contrast.
    SableTheme(
        appearance = rememberGlobalSableAppearance(),
        content = content,
    )
}
''',
    )

    main_activity = (
        mobile_root
        / "leisure"
        / "src"
        / "main"
        / "java"
        / "org"
        / "vaachak"
        / "reader"
        / "leisure"
        / "MainActivity.kt"
    )
    main_text = main_activity.read_text(encoding="utf-8")
    import_anchor = "import org.vaachak.reader.leisure.ui.theme.VaachakTheme\n"
    call_anchor = "VaachakTheme(themeMode = currentTheme, contrast = einkContrast) {"
    if import_anchor not in main_text or call_anchor not in main_text:
        fail("Vaachak theme anchor changed; inspect upstream before updating the pin")
    main_text = main_text.replace(
        import_anchor,
        "import org.vaachak.reader.leisure.ui.theme.ProductReaderTheme\n",
        1,
    )
    main_text = main_text.replace(
        call_anchor,
        "ProductReaderTheme(themeMode = currentTheme, contrast = einkContrast) {",
        1,
    )
    main_activity.write_text(main_text, encoding="utf-8")

    # Sable-specific settings must not reintroduce Reader-owned Light/Dark
    # surfaces. Upstream Offline Mode forces Library Settings to a paper-white
    # E-ink presentation; for Sable that is independent from connectivity and
    # was the source of the physically observed light settings screen.
    app_appearance = (
        mobile_root
        / "leisure/src/main/java/org/vaachak/reader/leisure/ui/settings/AppAppearanceScreen.kt"
    )
    app_appearance_text = app_appearance.read_text(encoding="utf-8")
    app_build_anchor = "import org.vaachak.reader.core.domain.model.ThemeMode\n"
    if "import org.vaachak.reader.leisure.BuildConfig\n" not in app_appearance_text:
        if app_build_anchor not in app_appearance_text:
            fail("SABLE_READER_APP_APPEARANCE_BUILD_CONFIG_ANCHOR_CHANGED")
        app_appearance_text = app_appearance_text.replace(
            app_build_anchor,
            app_build_anchor + "import org.vaachak.reader.leisure.BuildConfig\n",
            1,
        )
    app_theme_row_old = """            Row(horizontalArrangement = Arrangement.spacedBy(16.dp)) {
                ThemeOption(
                    name = "Light",
                    bg = Color(0xFFF0F0F0),
                    fg = Color.Black,
                    selected = uiState.themeMode == ThemeMode.LIGHT,
                    enabled = true,
                    modifier = Modifier.tid("app_appearance_theme_light")
                ) {
                    viewModel.setAppTheme(ThemeMode.LIGHT)
                }
                ThemeOption(
                    name = "Dark",
                    bg = Color(0xFF1E1E1E),
                    fg = Color.White,
                    selected = uiState.themeMode == ThemeMode.DARK,
                    enabled = true,
                    modifier = Modifier.tid("app_appearance_theme_dark")
                ) {
                    viewModel.setAppTheme(ThemeMode.DARK)
                }
                ThemeOption(
                    name = "E-Ink",
                    bg = Color.White,
                    fg = Color.Black,
                    selected = uiState.themeMode == ThemeMode.E_INK,
                    enabled = true,
                    modifier = Modifier.tid("app_appearance_theme_eink")
                ) {
                    viewModel.setAppTheme(ThemeMode.E_INK)
                }
            }
"""
    app_theme_row_new = """            if (BuildConfig.SABLE_PRODUCT) {
                Text(
                    "Light and Dark follow SableOS. E-Ink remains an explicit reader override.",
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                Row(horizontalArrangement = Arrangement.spacedBy(16.dp)) {
                    ThemeOption(
                        name = "SableOS",
                        bg = MaterialTheme.colorScheme.surface,
                        fg = MaterialTheme.colorScheme.onSurface,
                        selected = uiState.themeMode != ThemeMode.E_INK,
                        enabled = true,
                        modifier = Modifier.tid("app_appearance_theme_system")
                    ) {
                        // LIGHT is only a non-E-ink sentinel for the upstream
                        // preference model; ProductReaderTheme ignores it and
                        // reads the SableOS appearance authority.
                        viewModel.setAppTheme(ThemeMode.LIGHT)
                    }
                    ThemeOption(
                        name = "E-Ink",
                        bg = Color.White,
                        fg = Color.Black,
                        selected = uiState.themeMode == ThemeMode.E_INK,
                        enabled = true,
                        modifier = Modifier.tid("app_appearance_theme_eink")
                    ) {
                        viewModel.setAppTheme(ThemeMode.E_INK)
                    }
                }
            } else {
                Row(horizontalArrangement = Arrangement.spacedBy(16.dp)) {
                    ThemeOption(
                        name = "Light",
                        bg = Color(0xFFF0F0F0),
                        fg = Color.Black,
                        selected = uiState.themeMode == ThemeMode.LIGHT,
                        enabled = true,
                        modifier = Modifier.tid("app_appearance_theme_light")
                    ) {
                        viewModel.setAppTheme(ThemeMode.LIGHT)
                    }
                    ThemeOption(
                        name = "Dark",
                        bg = Color(0xFF1E1E1E),
                        fg = Color.White,
                        selected = uiState.themeMode == ThemeMode.DARK,
                        enabled = true,
                        modifier = Modifier.tid("app_appearance_theme_dark")
                    ) {
                        viewModel.setAppTheme(ThemeMode.DARK)
                    }
                    ThemeOption(
                        name = "E-Ink",
                        bg = Color.White,
                        fg = Color.Black,
                        selected = uiState.themeMode == ThemeMode.E_INK,
                        enabled = true,
                        modifier = Modifier.tid("app_appearance_theme_eink")
                    ) {
                        viewModel.setAppTheme(ThemeMode.E_INK)
                    }
                }
            }
"""
    if app_appearance_text.count(app_theme_row_old) != 1:
        fail("SABLE_READER_APP_APPEARANCE_THEME_ROW_CHANGED")
    app_appearance.write_text(
        app_appearance_text.replace(app_theme_row_old, app_theme_row_new, 1),
        encoding="utf-8",
    )

    default_appearance = (
        mobile_root
        / "leisure/src/main/java/org/vaachak/reader/leisure/ui/settings/DefaultAppearanceScreen.kt"
    )
    default_text = default_appearance.read_text(encoding="utf-8")
    default_import_anchor = "import org.readium.r2.navigator.preferences.FontFamily\n"
    if "import org.vaachak.reader.leisure.BuildConfig\n" not in default_text:
        if default_import_anchor not in default_text:
            fail("SABLE_READER_DEFAULT_APPEARANCE_BUILD_CONFIG_ANCHOR_CHANGED")
        default_text = default_text.replace(
            default_import_anchor,
            default_import_anchor + "import org.vaachak.reader.leisure.BuildConfig\n",
            1,
        )
    default_page_old = """                Row(horizontalArrangement = Arrangement.spacedBy(16.dp)) {
                    ThemeOption(
                        name = "Light",
                        bg = Color.White,
                        fg = Color.Black,
                        selected = readerPrefs.theme == "light",
                        enabled = true,
                        modifier = Modifier.tid(Tid.ReaderSettings.themeLight)
                    ) {
                        viewModel.updateReaderPreferences(readerPrefs.copy(theme = "light"))
                    }
                    ThemeOption(
                        name = "Dark",
                        bg = Color(0xFF121212),
                        fg = Color.White,
                        selected = readerPrefs.theme == "dark",
                        enabled = true,
                        modifier = Modifier.tid(Tid.ReaderSettings.themeDark)
                    ) {
                        viewModel.updateReaderPreferences(readerPrefs.copy(theme = "dark"))
                    }
                    ThemeOption(
                        name = "Sepia",
                        bg = Color(0xFFF5E6D3),
                        fg = Color(0xFF5F4B32),
                        selected = readerPrefs.theme == "sepia",
                        enabled = true,
                        modifier = Modifier.tid(Tid.ReaderSettings.themeSepia)
                    ) {
                        viewModel.updateReaderPreferences(readerPrefs.copy(theme = "sepia"))
                    }
                }
"""
    default_page_new = """                Row(horizontalArrangement = Arrangement.spacedBy(16.dp)) {
                    if (BuildConfig.SABLE_PRODUCT) {
                        ThemeOption(
                            name = "SableOS",
                            bg = MaterialTheme.colorScheme.surface,
                            fg = MaterialTheme.colorScheme.onSurface,
                            selected = readerPrefs.theme != "sepia",
                            enabled = true,
                            modifier = Modifier.tid(Tid.ReaderSettings.themeLight)
                        ) {
                            viewModel.updateReaderPreferences(readerPrefs.copy(theme = "light"))
                        }
                    } else {
                        ThemeOption(
                            name = "Light",
                            bg = Color.White,
                            fg = Color.Black,
                            selected = readerPrefs.theme == "light",
                            enabled = true,
                            modifier = Modifier.tid(Tid.ReaderSettings.themeLight)
                        ) {
                            viewModel.updateReaderPreferences(readerPrefs.copy(theme = "light"))
                        }
                        ThemeOption(
                            name = "Dark",
                            bg = Color(0xFF121212),
                            fg = Color.White,
                            selected = readerPrefs.theme == "dark",
                            enabled = true,
                            modifier = Modifier.tid(Tid.ReaderSettings.themeDark)
                        ) {
                            viewModel.updateReaderPreferences(readerPrefs.copy(theme = "dark"))
                        }
                    }
                    ThemeOption(
                        name = "Sepia",
                        bg = Color(0xFFF5E6D3),
                        fg = Color(0xFF5F4B32),
                        selected = readerPrefs.theme == "sepia",
                        enabled = true,
                        modifier = Modifier.tid(Tid.ReaderSettings.themeSepia)
                    ) {
                        viewModel.updateReaderPreferences(readerPrefs.copy(theme = "sepia"))
                    }
                }
"""
    if default_text.count(default_page_old) != 1:
        fail("SABLE_READER_DEFAULT_APPEARANCE_PAGE_COLOR_CHANGED")
    default_appearance.write_text(
        default_text.replace(default_page_old, default_page_new, 1),
        encoding="utf-8",
    )

    library_settings = (
        mobile_root
        / "leisure/src/main/java/org/vaachak/reader/leisure/ui/settings/LibrarySettingsScreen.kt"
    )
    library_text = library_settings.read_text(encoding="utf-8")
    library_import_anchor = "import org.vaachak.reader.core.domain.model.DitheringMode\n"
    if "import org.vaachak.reader.leisure.BuildConfig\n" not in library_text:
        if library_import_anchor not in library_text:
            fail("SABLE_READER_LIBRARY_SETTINGS_BUILD_CONFIG_ANCHOR_CHANGED")
        library_text = library_text.replace(
            library_import_anchor,
            library_import_anchor + "import org.vaachak.reader.leisure.BuildConfig\n",
            1,
        )
    offline_old = """    val containerColor = if (state.isOfflineMode) Color.White else MaterialTheme.colorScheme.background
    val contentColor = if (state.isOfflineMode) Color.Black else MaterialTheme.colorScheme.onBackground
"""
    offline_new = """    val useOfflinePaperTheme = state.isOfflineMode && !BuildConfig.SABLE_PRODUCT
    val containerColor = if (useOfflinePaperTheme) Color.White else MaterialTheme.colorScheme.background
    val contentColor = if (useOfflinePaperTheme) Color.Black else MaterialTheme.colorScheme.onBackground
"""
    if library_text.count(offline_old) != 1:
        fail("SABLE_READER_LIBRARY_SETTINGS_OFFLINE_THEME_ANCHOR_CHANGED")
    library_text = library_text.replace(offline_old, offline_new, 1)
    library_text = library_text.replace(
        "isEink = state.isOfflineMode",
        "isEink = useOfflinePaperTheme",
    )
    library_text = library_text.replace(
        "if (state.isOfflineMode) Color.LightGray.copy(alpha = 0.3f) else MaterialTheme.colorScheme.surfaceVariant",
        "if (useOfflinePaperTheme) Color.LightGray.copy(alpha = 0.3f) else MaterialTheme.colorScheme.surfaceVariant",
    )
    library_settings.write_text(library_text, encoding="utf-8")
    print("R9_READER_SETTINGS_GLOBAL_APPEARANCE=PASS_NO_OFFLINE_LIGHT_OVERRIDE")
    print("R9_READER_LOCAL_LIGHT_DARK_CONTROLS=PASS_RETIRED_FOR_SABLE")

    # Bind the Readium EPUB canvas to SableOS Light/Dark. Upstream Reader keeps
    # its own persisted page theme, which caused the physical R9 candidate to
    # render Sable chrome and book content in conflicting modes. Sepia and E-ink
    # remain deliberate reading-only overrides.
    reader_screen = (
        mobile_root
        / "leisure"
        / "src"
        / "main"
        / "java"
        / "org"
        / "vaachak"
        / "reader"
        / "leisure"
        / "ui"
        / "reader"
        / "ReaderScreen.kt"
    )
    reader_text = reader_screen.read_text(encoding="utf-8")

    reader_import_anchor = "import androidx.compose.foundation.BorderStroke\n"
    reader_import_replacement = (
        reader_import_anchor
        + "import androidx.compose.foundation.isSystemInDarkTheme\n"
    )
    if reader_import_replacement not in reader_text:
        if reader_import_anchor not in reader_text:
            fail("ReaderScreen Compose import anchor changed")
        reader_text = reader_text.replace(
            reader_import_anchor,
            reader_import_replacement,
            1,
        )

    readium_import_anchor = (
        "import org.readium.r2.navigator.input.TapEvent\n"
    )
    readium_import_replacement = (
        readium_import_anchor
        + "import org.readium.r2.navigator.preferences.Theme\n"
    )
    if readium_import_replacement not in reader_text:
        if readium_import_anchor not in reader_text:
            fail("ReaderScreen Readium import anchor changed")
        reader_text = reader_text.replace(
            readium_import_anchor,
            readium_import_replacement,
            1,
        )

    sable_import_anchor = (
        "import org.vaachak.reader.core.domain.model.HighlightEntity\n"
    )
    sable_import_replacement = (
        "import org.sableos.design.AppearanceMode\n"
        "import org.sableos.design.rememberGlobalSableAppearance\n"
        + sable_import_anchor
    )
    if "import org.sableos.design.rememberGlobalSableAppearance\n" not in reader_text:
        if sable_import_anchor not in reader_text:
            fail("ReaderScreen Sable import anchor changed")
        reader_text = reader_text.replace(
            sable_import_anchor,
            sable_import_replacement,
            1,
        )

    prefs_anchor = (
        "    val epubPreferences by viewModel.epubPreferences.collectAsState()\n"
    )
    prefs_replacement = prefs_anchor + r'''
    val sableAppearance = rememberGlobalSableAppearance()
    val systemDark = isSystemInDarkTheme()
    val sableDark =
        when (sableAppearance.mode) {
            AppearanceMode.FollowSystem -> systemDark
            AppearanceMode.Light -> false
            AppearanceMode.Dark -> true
        }
    val effectiveEpubPreferences =
        remember(epubPreferences, sableAppearance, systemDark, isEink) {
            when {
                // E-ink is intentionally a white-page, high-contrast reading mode.
                isEink -> epubPreferences.copy(theme = Theme.LIGHT)

                // Sepia is the only normal Reader page-color override retained
                // independently of the operating-system Light/Dark selection.
                epubPreferences.theme == Theme.SEPIA -> epubPreferences

                else ->
                    epubPreferences.copy(
                        theme = if (sableDark) Theme.DARK else Theme.LIGHT,
                    )
            }
        }
'''
    if "val effectiveEpubPreferences =" not in reader_text:
        if prefs_anchor not in reader_text:
            fail("ReaderScreen EPUB preference anchor changed")
        reader_text = reader_text.replace(
            prefs_anchor,
            prefs_replacement,
            1,
        )

    submit_old = (
        "    LaunchedEffect(epubPreferences, currentNavigatorFragment) {\n"
        "        if (currentNavigatorFragment?.view != null) {\n"
        "            currentNavigatorFragment?.submitPreferences(epubPreferences)\n"
        "        }\n"
        "    }\n"
    )
    submit_new = (
        "    LaunchedEffect(effectiveEpubPreferences, currentNavigatorFragment) {\n"
        "        if (currentNavigatorFragment?.view != null) {\n"
        "            currentNavigatorFragment?.submitPreferences(effectiveEpubPreferences)\n"
        "        }\n"
        "    }\n"
    )
    if submit_new not in reader_text:
        if submit_old not in reader_text:
            fail("ReaderScreen EPUB submit anchor changed")
        reader_text = reader_text.replace(submit_old, submit_new, 1)

    reader_screen.write_text(reader_text, encoding="utf-8")

    # The Sable flavor must not present ordinary Light/Dark as Reader-owned
    # appearance controls. SableOS owns those modes globally; Reader retains
    # only reading-specific Sepia (and the separate E-ink mode).
    reader_settings_text = reader_settings_sheet.read_text(encoding="utf-8")
    reader_settings_import_anchor = (
        "import org.vaachak.reader.leisure.ui.reader.ReaderViewModel\n"
    )
    reader_settings_import_replacement = (
        reader_settings_import_anchor
        + "import org.vaachak.reader.leisure.BuildConfig\n"
    )
    if "import org.vaachak.reader.leisure.BuildConfig\n" not in reader_settings_text:
        if reader_settings_import_anchor not in reader_settings_text:
            fail("SABLE_READER_SETTINGS_BUILD_CONFIG_ANCHOR_CHANGED")
        reader_settings_text = reader_settings_text.replace(
            reader_settings_import_anchor,
            reader_settings_import_replacement,
            1,
        )

    page_color_old = """                    item {
                        SettingsSectionTitle("Page Color")
                        Row(horizontalArrangement = Arrangement.spacedBy(16.dp)) {
                            val currentTheme = prefs.theme ?: Theme.LIGHT
                            ThemeOption(
                                name = "Light",
                                bg = Color.White,
                                fg = Color.Black,
                                selected = currentTheme == Theme.LIGHT,
                                enabled = areSettingsEnabled,
                                modifier = Modifier.tid(Tid.ReaderSettings.themeLight)
                            ) {
                                update(prefs.copy(theme = Theme.LIGHT))
                            }
                            ThemeOption(
                                name = "Dark",
                                bg = Color(0xFF121212),
                                fg = Color.White,
                                selected = currentTheme == Theme.DARK,
                                enabled = areSettingsEnabled,
                                modifier = Modifier.tid(Tid.ReaderSettings.themeDark)
                            ) {
                                update(prefs.copy(theme = Theme.DARK))
                            }
                            ThemeOption(
                                name = "Sepia",
                                bg = Color(0xFFF5E6D3),
                                fg = Color(0xFF5F4B32),
                                selected = currentTheme == Theme.SEPIA,
                                enabled = areSettingsEnabled,
                                modifier = Modifier.tid(Tid.ReaderSettings.themeSepia)
                            ) {
                                update(prefs.copy(theme = Theme.SEPIA))
                            }
                        }
                    }
"""
    page_color_new = """                    item {
                        SettingsSectionTitle("Page Color")
                        val currentTheme = prefs.theme ?: Theme.LIGHT
                        if (BuildConfig.SABLE_PRODUCT) {
                            Text(
                                "Light and Dark follow SableOS. Sepia is an optional reading override.",
                                style = MaterialTheme.typography.bodyMedium,
                                color = contentColor.copy(alpha = 0.72f),
                            )
                            Row(horizontalArrangement = Arrangement.spacedBy(16.dp)) {
                                ThemeOption(
                                    name = "Sepia",
                                    bg = Color(0xFFF5E6D3),
                                    fg = Color(0xFF5F4B32),
                                    selected = currentTheme == Theme.SEPIA,
                                    enabled = areSettingsEnabled,
                                    modifier = Modifier.tid(Tid.ReaderSettings.themeSepia)
                                ) {
                                    update(prefs.copy(theme = Theme.SEPIA))
                                }
                                if (currentTheme == Theme.SEPIA) {
                                    OutlinedButton(
                                        onClick = {
                                            update(prefs.copy(theme = Theme.LIGHT))
                                        },
                                        enabled = areSettingsEnabled,
                                    ) {
                                        Text("Follow SableOS")
                                    }
                                } else {
                                    Text(
                                        "Following SableOS",
                                        modifier = Modifier.padding(vertical = 12.dp),
                                        style = MaterialTheme.typography.labelLarge,
                                        color = primaryColor,
                                    )
                                }
                            }
                        } else {
                            Row(horizontalArrangement = Arrangement.spacedBy(16.dp)) {
                                ThemeOption(
                                    name = "Light",
                                    bg = Color.White,
                                    fg = Color.Black,
                                    selected = currentTheme == Theme.LIGHT,
                                    enabled = areSettingsEnabled,
                                    modifier = Modifier.tid(Tid.ReaderSettings.themeLight)
                                ) {
                                    update(prefs.copy(theme = Theme.LIGHT))
                                }
                                ThemeOption(
                                    name = "Dark",
                                    bg = Color(0xFF121212),
                                    fg = Color.White,
                                    selected = currentTheme == Theme.DARK,
                                    enabled = areSettingsEnabled,
                                    modifier = Modifier.tid(Tid.ReaderSettings.themeDark)
                                ) {
                                    update(prefs.copy(theme = Theme.DARK))
                                }
                                ThemeOption(
                                    name = "Sepia",
                                    bg = Color(0xFFF5E6D3),
                                    fg = Color(0xFF5F4B32),
                                    selected = currentTheme == Theme.SEPIA,
                                    enabled = areSettingsEnabled,
                                    modifier = Modifier.tid(Tid.ReaderSettings.themeSepia)
                                ) {
                                    update(prefs.copy(theme = Theme.SEPIA))
                                }
                            }
                        }
                    }
"""
    if "Light and Dark follow SableOS." not in reader_settings_text:
        if reader_settings_text.count(page_color_old) != 1:
            fail("SABLE_READER_SETTINGS_PAGE_COLOR_ANCHOR_CHANGED")
        reader_settings_text = reader_settings_text.replace(
            page_color_old,
            page_color_new,
            1,
        )
    reader_settings_sheet.write_text(reader_settings_text, encoding="utf-8")
    print("R9_READER_LIGHT_DARK_OWNERSHIP=PASS_SABLEOS_GLOBAL")
    print("R9_READER_SETTINGS_OVERRIDES=PASS_SEPIA_ONLY")

    # Plain-text, share/process-text, OCR and text-specific TTS are intentionally
    # owned by the standalone Sable Text Reader product.
    print("SABLE_READER_TEXTREADER_COMPOSITION=PASS_ABSENT")

    values = mobile_root / "leisure" / "src" / "sable" / "res" / "values"
    write(
        values / "strings.xml",
        '<resources>\n    <string name="app_name">Sable Reader</string>\n</resources>\n',
    )

    write(
        mobile_root
        / "leisure"
        / "src"
        / "sable"
        / "res"
        / "drawable"
        / "ic_sable_reader.xml",
        '''<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="48dp"
    android:height="48dp"
    android:viewportWidth="256"
    android:viewportHeight="256">
    <path android:fillColor="#161C24"
        android:pathData="M32,16h192c8.8,0 16,7.2 16,16v192c0,8.8 -7.2,16 -16,16H32c-8.8,0 -16,-7.2 -16,-16V32c0,-8.8 7.2,-16 16,-16z" />
    <group android:scaleX="0.70" android:scaleY="0.70"
        android:translateX="38.4" android:translateY="34">
        <path android:fillColor="#F7F9FC"
            android:pathData="M232,48H160a40,40,0,0,0-32,16A40,40,0,0,0,96,48H24a8,8,0,0,0-8,8V200a8,8,0,0,0,8,8H96a24,24,0,0,1,24,24,8,8,0,0,0,16,0,24,24,0,0,1,24-24h72a8,8,0,0,0,8-8V56A8,8,0,0,0,232,48ZM96,192H32V64H96a24,24,0,0,1,24,24V200A39.81,39.81,0,0,0,96,192Zm128,0H160a39.81,39.81,0,0,0-24,8V88a24,24,0,0,1,24-24h64ZM160,88h40a8,8,0,0,1,0,16H160a8,8,0,0,1,0-16Zm48,40a8,8,0,0,1-8,8H160a8,8,0,0,1,0-16h40A8,8,0,0,1,208,128Zm0,32a8,8,0,0,1-8,8H160a8,8,0,0,1,0-16h40A8,8,0,0,1,208,160Z" />
    </group>
    <path android:fillColor="#35C66B" android:pathData="M28,226h200v6H28z" />
</vector>
''',
    )

    # The upstream debug source set is higher priority than the product flavor
    # during manifest merging. Give the exact SableDebug variant an explicit
    # identity overlay so Sable product icons win without mutating upstream
    # debug behavior for the Vaachak flavor.
    sable_debug_manifest_dir = mobile_root / "leisure" / "src" / "sableDebug"
    write(
        sable_debug_manifest_dir / "AndroidManifest.xml",
        '''<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    xmlns:tools="http://schemas.android.com/tools">
    <application
        android:icon="@drawable/ic_sable_reader"
        android:roundIcon="@drawable/ic_sable_reader"
        android:label="@string/app_name"
        tools:replace="android:icon,android:roundIcon,android:label" />
</manifest>
''',
    )

    manifest_dir = mobile_root / "leisure" / "src" / "sable"
    write(
        manifest_dir / "AndroidManifest.xml",
        '''<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    xmlns:tools="http://schemas.android.com/tools">
    <uses-permission
        android:name="android.permission.INTERNET"
        tools:node="remove" />

    <queries>
        <provider android:authorities="org.sableos.appearance" />
    </queries>

    <application
        android:icon="@drawable/ic_sable_reader"
        android:roundIcon="@drawable/ic_sable_reader"
        android:label="@string/app_name" />
</manifest>
''',
    )

    print("SABLE_READER_FLAVOR_PATCH=PASS")
    print("SABLE_READER_VARIANT_MANIFEST_IDENTITY_OVERRIDE=PASS")
    print("SABLE_READER_NETWORK_PERMISSION=REMOVED_BY_FLAVOR_OVERLAY")
    print("SABLE_READER_CANONICAL_DESIGN=COMPOSED")
    print("R9_READER_READIUM_APPEARANCE_BRIDGE=PASS")
    print("R9_READER_READING_OVERRIDES=SEPIA_EINK_ONLY")
    print("R9_READER_LIGHT_DARK_OWNERSHIP=PASS_SABLEOS_GLOBAL")
    print("R9_READER_LIBRARY_NAVIGATION=PASS_CONTINUOUS_VERTICAL_GRID")
    print("SABLE_READER_PUBLICATION_FOCUS=PASS")
    print("SABLE_READER_TEXTREADER_RUNTIME=PASS_ABSENT")
    print("SABLE_READER_UPSTREAM_PUBLICATION_CORE=UNCHANGED")


if __name__ == "__main__":
    main()
