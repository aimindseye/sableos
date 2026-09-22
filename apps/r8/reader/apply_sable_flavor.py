#!/usr/bin/env python3
"""Compose the bounded Sable Reader product from pinned Vaachak inputs.

UI3 keeps Vaachak Mobile / Readium as the publication engine and composes the
bounded text-accessibility path from the separately pinned Vaachak Text Reader
capability source: local text, Android sharing/process-text, TTS and
user-directed camera/gallery OCR. Translation remains intentionally excluded.

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
    if len(sys.argv) != 3:
        fail(
            "usage: apply_sable_flavor.py "
            "<vaachak-mobile-checkout> <vaachak-textreader-checkout>"
        )

    mobile_root = pathlib.Path(sys.argv[1]).resolve()
    text_root = pathlib.Path(sys.argv[2]).resolve()

    gradle_file = mobile_root / "leisure" / "build.gradle.kts"
    if not gradle_file.is_file():
        fail(f"missing {gradle_file}")

    gradle_text = gradle_file.read_text(encoding="utf-8")
    if 'compileSdk = libs.versions.android.compileSdk.get().toInt()' not in gradle_text:
        fail("Vaachak compileSdk anchor changed; inspect upstream")
    gradle_text = gradle_text.replace(
        'compileSdk = libs.versions.android.compileSdk.get().toInt()',
        '    compileSdk = libs.versions.android.compileSdk.get().toInt()
    ndkVersion = "30.0.16248370"',
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

    # The Sable flavor is injected into an upstream Kotlin DSL build. Generated
    # type-safe dependency accessors such as sableImplementation(...) do not
    # exist when the script itself is compiled, because that configuration is
    # created by this same script. Use the stable named-configuration API.
    sable_ocr_dependencies = """dependencies {
    add("sableImplementation", "androidx.camera:camera-camera2:1.3.1")
    add("sableImplementation", "androidx.camera:camera-lifecycle:1.3.1")
    add("sableImplementation", "androidx.camera:camera-view:1.3.1")
    add("sableImplementation", "com.google.mlkit:text-recognition:16.0.1")
    add("sableImplementation", "com.google.mlkit:text-recognition-devanagari:16.0.1")
"""
    gradle_text = gradle_text.replace(
        dependencies_anchor,
        sable_ocr_dependencies,
        1,
    )
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

    # Compose the pinned MIT-licensed text capability into only the Sable product
    # flavor. Translation and the Text Reader launcher/theme remain excluded.
    text_reader_util = (
        text_root
        / "app"
        / "src"
        / "main"
        / "java"
        / "org"
        / "vaachak"
        / "textreader"
        / "TextReaderUtil.kt"
    )
    copy_file(
        text_reader_util,
        mobile_root
        / "leisure"
        / "src"
        / "sable"
        / "java"
        / "org"
        / "vaachak"
        / "textreader"
        / "TextReaderUtil.kt",
    )

    camera_scanner = (
        text_root
        / "app"
        / "src"
        / "main"
        / "java"
        / "org"
        / "vaachak"
        / "textreader"
        / "CameraScannerView.kt"
    )
    copy_file(
        camera_scanner,
        mobile_root
        / "leisure"
        / "src"
        / "sable"
        / "java"
        / "org"
        / "vaachak"
        / "textreader"
        / "CameraScannerView.kt",
    )

    text_activity = (
        mobile_root
        / "leisure"
        / "src"
        / "sable"
        / "java"
        / "org"
        / "vaachak"
        / "reader"
        / "leisure"
        / "SableTextActivity.kt"
    )
    write(
        text_activity,
        '''package org.vaachak.reader.leisure

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.text.selection.SelectionContainer
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.lifecycleScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.sableos.design.SableActionButton
import org.sableos.design.SableHeroHeader
import org.sableos.design.SablePanel
import org.sableos.design.SableValuePanel
import org.sableos.design.SableScrollableScreen
import org.sableos.design.SableSpacing
import org.sableos.design.SableGlobalTheme
import org.vaachak.textreader.TextReaderUtil
import java.io.FilterInputStream
import java.io.InputStream
import java.util.Locale

private const val MAX_TEXT_BYTES = 2 * 1024 * 1024L

private data class PlainTextPayload(
    val source: String,
    val text: String,
    val status: String,
)

class SableTextActivity : ComponentActivity() {
    private var payload by mutableStateOf(
        PlainTextPayload(
            source = "Plain text",
            text = "",
            status = "Waiting for text",
        ),
    )
    private var narrationStatus by mutableStateOf("Narration ready")
    private lateinit var speaker: PlainTextSpeaker

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        speaker = PlainTextSpeaker(this) { narrationStatus = it }
        loadIntent(intent)

        setContent {
            SableGlobalTheme(window = window) {
                SableScrollableScreen {
                    SableHeroHeader(
                        eyebrow = "Sable",
                        title = "reader",
                        subtitle = payload.source,
                    )

                    SablePanel {
                        Text(
                            payload.status,
                            style = MaterialTheme.typography.labelLarge,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                        SelectionContainer {
                            Text(
                                if (payload.text.isBlank()) {
                                    "No text available."
                                } else {
                                    payload.text
                                },
                                style = MaterialTheme.typography.bodyLarge,
                            )
                        }
                    }

                    SableValuePanel(
                        label = "read aloud",
                        value = narrationStatus,
                        supportingText = "Local Android text-to-speech",
                    )

                    androidx.compose.foundation.layout.Row(
                        horizontalArrangement =
                            androidx.compose.foundation.layout.Arrangement.spacedBy(
                                SableSpacing.Sm,
                            ),
                    ) {
                        SableActionButton(
                            text = "Read",
                            modifier = androidx.compose.ui.Modifier.weight(1f),
                            onClick = { speaker.speak(payload.text) },
                        )
                        SableActionButton(
                            text = "Stop",
                            primary = false,
                            modifier = androidx.compose.ui.Modifier.weight(1f),
                            onClick = { speaker.stop() },
                        )
                    }

                    SableActionButton(
                        text = "Camera / image OCR",
                        onClick = {
                            startActivity(
                                Intent(
                                    this@SableTextActivity,
                                    SableOcrActivity::class.java,
                                ),
                            )
                        },
                    )

                    Text(
                        "Text reading and OCR stay on-device in the Sable Reader path. " +
                            "Translation remains disabled in this tranche.",
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        loadIntent(intent)
    }

    override fun onDestroy() {
        speaker.close()
        super.onDestroy()
    }

    private fun loadIntent(intent: Intent?) {
        when (intent?.action) {
            Intent.ACTION_PROCESS_TEXT -> {
                val text = intent.getCharSequenceExtra(Intent.EXTRA_PROCESS_TEXT)?.toString()
                setDirectText("Selected text", text)
            }

            Intent.ACTION_SEND -> {
                val text = intent.getCharSequenceExtra(Intent.EXTRA_TEXT)?.toString()
                if (!text.isNullOrBlank()) {
                    setDirectText("Shared text", text)
                } else {
                    @Suppress("DEPRECATION")
                    val uri = intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)
                    if (uri != null) {
                        loadUri("Shared document", uri)
                    } else {
                        setDirectText("Shared text", null)
                    }
                }
            }

            Intent.ACTION_VIEW -> {
                val uri = intent.data
                if (uri != null) {
                    loadUri("Text document", uri)
                } else {
                    setDirectText("Text document", null)
                }
            }

            else -> setDirectText("Plain text", null)
        }
    }

    private fun setDirectText(source: String, text: String?) {
        payload =
            if (text.isNullOrBlank()) {
                PlainTextPayload(
                    source = source,
                    text = "",
                    status = "No readable text supplied",
                )
            } else {
                PlainTextPayload(
                    source = source,
                    text = text,
                    status = "Local text",
                )
            }
    }

    private fun loadUri(source: String, uri: Uri) {
        payload = PlainTextPayload(source, "", "Loading local text")
        lifecycleScope.launch {
            val result =
                withContext(Dispatchers.IO) {
                    runCatching {
                        contentResolver.openInputStream(uri)?.use { stream ->
                            TextReaderUtil.readTextFromStream(
                                BoundedInputStream(
                                    stream,
                                    MAX_TEXT_BYTES,
                                ),
                            )
                        } ?: "Error: File stream is null."
                    }
                }

            result
                .onSuccess { text ->
                    payload =
                        if (text.startsWith("Error")) {
                            PlainTextPayload(source, "", text)
                        } else {
                            PlainTextPayload(
                                source = source,
                                text = text,
                                status = "Local text · bounded to 2 MiB",
                            )
                        }
                }
                .onFailure {
                    payload =
                        PlainTextPayload(
                            source = source,
                            text = "",
                            status = "Unable to read this text source",
                        )
                }
        }
    }
}

private class BoundedInputStream(
    input: InputStream,
    private var remaining: Long,
) : FilterInputStream(input) {
    override fun read(): Int {
        if (remaining <= 0) return -1
        val value = super.read()
        if (value >= 0) remaining -= 1
        return value
    }

    override fun read(
        buffer: ByteArray,
        offset: Int,
        length: Int,
    ): Int {
        if (remaining <= 0) return -1
        val allowed = minOf(length.toLong(), remaining).toInt()
        val count = super.read(buffer, offset, allowed)
        if (count > 0) remaining -= count.toLong()
        return count
    }
}

private class PlainTextSpeaker(
    context: Context,
    private val onStatus: (String) -> Unit,
) : TextToSpeech.OnInitListener {
    private val tts = TextToSpeech(context.applicationContext, this)
    private var ready = false

    override fun onInit(status: Int) {
        ready = status == TextToSpeech.SUCCESS
        if (ready) {
            tts.language = Locale.getDefault()
            tts.setOnUtteranceProgressListener(
                object : UtteranceProgressListener() {
                    override fun onStart(utteranceId: String?) {
                        onStatus("Reading")
                    }

                    override fun onDone(utteranceId: String?) {
                        if (utteranceId == "sable-text-final") {
                            onStatus("Narration complete")
                        }
                    }

                    @Deprecated("Deprecated in Android")
                    override fun onError(utteranceId: String?) {
                        onStatus("Narration error")
                    }
                },
            )
            onStatus("Narration ready")
        } else {
            onStatus("Text-to-speech unavailable")
        }
    }

    fun speak(text: String) {
        if (!ready) {
            onStatus("Text-to-speech unavailable")
            return
        }
        if (text.isBlank()) {
            onStatus("No text to read")
            return
        }

        val maximum = (TextToSpeech.getMaxSpeechInputLength() - 128).coerceAtLeast(512)
        val chunks = text.chunked(maximum)

        chunks.forEachIndexed { index, chunk ->
            val final = index == chunks.lastIndex
            tts.speak(
                chunk,
                if (index == 0) TextToSpeech.QUEUE_FLUSH else TextToSpeech.QUEUE_ADD,
                null,
                if (final) "sable-text-final" else "sable-text-$index",
            )
        }
    }

    fun stop() {
        tts.stop()
        onStatus("Narration stopped")
    }

    fun close() {
        tts.stop()
        tts.shutdown()
    }
}
''',
    )

    ocr_activity = (
        mobile_root
        / "leisure"
        / "src"
        / "sable"
        / "java"
        / "org"
        / "vaachak"
        / "reader"
        / "leisure"
        / "SableOcrActivity.kt"
    )
    write(
        ocr_activity,
        r'''package org.vaachak.reader.leisure

import android.Manifest
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.text.selection.SelectionContainer
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.devanagari.DevanagariTextRecognizerOptions
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import org.sableos.design.SableActionButton
import org.sableos.design.SableHeroHeader
import org.sableos.design.SablePanel
import org.sableos.design.SableScrollableScreen
import org.sableos.design.SableSpacing
import org.sableos.design.SableGlobalTheme
import org.vaachak.textreader.CameraScannerView

private enum class OcrScript(val label: String) {
    Latin("Latin"),
    Devanagari("Devanagari"),
}

class SableOcrActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        setContent {
            var script by remember { mutableStateOf(OcrScript.Latin) }
            var scannedText by remember { mutableStateOf("") }
            var status by remember { mutableStateOf("Choose camera or an image") }
            var showCamera by remember { mutableStateOf(false) }

            fun recognize(uri: Uri) {
                status = "Recognizing local image"
                val image =
                    runCatching {
                        InputImage.fromFilePath(this, uri)
                    }.getOrElse {
                        status = "Unable to read that image"
                        return
                    }
                val recognizer =
                    if (script == OcrScript.Devanagari) {
                        TextRecognition.getClient(
                            DevanagariTextRecognizerOptions.Builder().build(),
                        )
                    } else {
                        TextRecognition.getClient(
                            TextRecognizerOptions.DEFAULT_OPTIONS,
                        )
                    }
                recognizer
                    .process(image)
                    .addOnSuccessListener { result ->
                        scannedText = result.text
                        status =
                            if (result.text.isBlank()) {
                                "No text recognized"
                            } else {
                                "Text recognized locally"
                            }
                    }
                    .addOnFailureListener {
                        status = "OCR unavailable for this image"
                    }
                    .addOnCompleteListener {
                        recognizer.close()
                    }
            }

            val gallery =
                rememberLauncherForActivityResult(
                    ActivityResultContracts.GetContent(),
                ) { uri ->
                    if (uri != null) {
                        recognize(uri)
                    }
                }

            val cameraPermission =
                rememberLauncherForActivityResult(
                    ActivityResultContracts.RequestPermission(),
                ) { granted ->
                    showCamera = granted
                    if (!granted) {
                        status = "Camera permission was not granted"
                    }
                }

            SableGlobalTheme(window = window) {
                if (showCamera) {
                    CameraScannerView(
                        isDevanagari = script == OcrScript.Devanagari,
                        onScriptChange = { useDevanagari ->
                            script =
                                if (useDevanagari) {
                                    OcrScript.Devanagari
                                } else {
                                    OcrScript.Latin
                                }
                        },
                        onTextScanned = { text ->
                            scannedText = text
                            status =
                                if (text.isBlank()) {
                                    "No text recognized"
                                } else {
                                    "Text recognized locally"
                                }
                        },
                        onOpenGallery = {
                            showCamera = false
                            gallery.launch("image/*")
                        },
                        onDismiss = {
                            showCamera = false
                        },
                    )
                } else {
                    SableScrollableScreen {
                        SableHeroHeader(
                            eyebrow = "Sable Reader",
                            title = "OCR",
                            subtitle = "Camera or image · on-device recognition",
                        )

                        Row(
                            horizontalArrangement =
                                Arrangement.spacedBy(SableSpacing.Sm),
                        ) {
                            OcrScript.entries.forEach { choice ->
                                SableActionButton(
                                    text = choice.label,
                                    primary = choice == script,
                                    modifier = Modifier.weight(1f),
                                    onClick = {
                                        script = choice
                                    },
                                )
                            }
                        }

                        Row(
                            horizontalArrangement =
                                Arrangement.spacedBy(SableSpacing.Sm),
                        ) {
                            SableActionButton(
                                text = "Camera",
                                modifier = Modifier.weight(1f),
                                onClick = {
                                    cameraPermission.launch(
                                        Manifest.permission.CAMERA,
                                    )
                                },
                            )
                            SableActionButton(
                                text = "Image",
                                primary = false,
                                modifier = Modifier.weight(1f),
                                onClick = {
                                    gallery.launch("image/*")
                                },
                            )
                        }

                        SablePanel {
                            Text(
                                text = status,
                                style = MaterialTheme.typography.labelLarge,
                                color =
                                    MaterialTheme.colorScheme.onSurfaceVariant,
                            )
                            SelectionContainer {
                                Text(
                                    text =
                                        scannedText.ifBlank {
                                            "Recognized text will appear here."
                                        },
                                    style = MaterialTheme.typography.bodyLarge,
                                )
                            }
                        }

                        SableActionButton(
                            text = "Read recognized text",
                            primary = scannedText.isNotBlank(),
                            onClick = {
                                if (scannedText.isNotBlank()) {
                                    startActivity(
                                        Intent(
                                            this@SableOcrActivity,
                                            SableTextActivity::class.java,
                                        ).apply {
                                            action = Intent.ACTION_SEND
                                            type = "text/plain"
                                            putExtra(
                                                Intent.EXTRA_TEXT,
                                                scannedText,
                                            )
                                        },
                                    )
                                }
                            },
                        )

                        Text(
                            text =
                                "Camera permission is requested only when Camera " +
                                    "OCR is chosen. Gallery OCR does not require it. " +
                                    "Translation and network fallback are disabled.",
                            style = MaterialTheme.typography.bodyMedium,
                            color =
                                MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                }
            }
        }
    }
}
''',
    )

    test_source = (
        mobile_root
        / "leisure"
        / "src"
        / "testSable"
        / "java"
        / "org"
        / "vaachak"
        / "textreader"
        / "SableTextReaderUtilTest.kt"
    )
    write(
        test_source,
        '''package org.vaachak.textreader

import java.io.ByteArrayInputStream
import org.junit.Assert.assertEquals
import org.junit.Test

class SableTextReaderUtilTest {
    @Test
    fun readsPlainTextCapabilityInsideSableReader() {
        val input = ByteArrayInputStream("Sable Reader\\nPlain text".toByteArray())
        assertEquals(
            "Sable Reader\\nPlain text",
            TextReaderUtil.readTextFromStream(input),
        )
    }

    @Test
    fun emptyStreamProducesEmptyText() {
        val input = ByteArrayInputStream(ByteArray(0))
        assertEquals("", TextReaderUtil.readTextFromStream(input))
    }
}
''',
    )

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
    <uses-permission android:name="android.permission.CAMERA" />
    <uses-feature
        android:name="android.hardware.camera"
        android:required="false" />

    <queries>
        <provider android:authorities="org.sableos.appearance" />
    </queries>

    <application
        android:icon="@drawable/ic_sable_reader"
        android:roundIcon="@drawable/ic_sable_reader"
        android:label="@string/app_name">
        <activity
            android:name="org.vaachak.reader.leisure.SableTextActivity"
            android:exported="true"
            android:label="@string/app_name">

            <intent-filter tools:ignore="AppLinkUrlError">
                <action android:name="android.intent.action.VIEW" />
                <category android:name="android.intent.category.DEFAULT" />
                <data android:mimeType="text/plain" />
                <data android:scheme="content" />
                <data android:scheme="file" />
            </intent-filter>

            <intent-filter>
                <action android:name="android.intent.action.SEND" />
                <category android:name="android.intent.category.DEFAULT" />
                <data android:mimeType="text/plain" />
            </intent-filter>

            <intent-filter>
                <action android:name="android.intent.action.PROCESS_TEXT" />
                <category android:name="android.intent.category.DEFAULT" />
                <data android:mimeType="text/plain" />
            </intent-filter>
        </activity>

        <activity
            android:name="org.vaachak.reader.leisure.SableOcrActivity"
            android:exported="false"
            android:label="Sable Reader OCR" />
    </application>
</manifest>
''',
    )

    print("SABLE_READER_FLAVOR_PATCH=PASS")
    print("SABLE_READER_VARIANT_MANIFEST_IDENTITY_OVERRIDE=PASS")
    print("SABLE_READER_NETWORK_PERMISSION=REMOVED_BY_FLAVOR_OVERLAY")
    print("SABLE_READER_CANONICAL_DESIGN=COMPOSED")
    print("R9_READER_READIUM_APPEARANCE_BRIDGE=PASS")
    print("R9_READER_READING_OVERRIDES=SEPIA_EINK_ONLY")
    print("SABLE_READER_TEXT_UTIL=PINNED_TEXTREADER_COMPOSED")
    print("SABLE_READER_TEXT_VIEW=ENABLED")
    print("SABLE_READER_TEXT_SEND=ENABLED")
    print("SABLE_READER_PROCESS_TEXT=ENABLED")
    print("SABLE_READER_OCR=CAMERA_GALLERY_LATIN_DEVANAGARI_ENABLED")
    print("SABLE_READER_OCR_CAMERA_PERMISSION=OPTIONAL_RUNTIME_ONLY")
    print("SABLE_READER_OCR_NETWORK_FALLBACK=DISABLED")
    print("SABLE_READER_TRANSLATION=DEFERRED")
    print("SABLE_READER_UPSTREAM_PUBLICATION_CORE=UNCHANGED")


if __name__ == "__main__":
    main()
