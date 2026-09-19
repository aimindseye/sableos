package org.sableos.system.preview

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawingPadding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import org.sableos.design.SableActionButton
import org.sableos.design.SableHeroHeader
import org.sableos.design.SableSpacing
import org.sableos.design.SableTile

private enum class PreviewPage(
    val label: String,
) {
    Settings("settings"),
    Applications("applications"),
    AppSecurity("app security"),
    SetupWelcome("setup welcome"),
    SetupFinish("setup finish"),
    About("about"),
    Lockscreen("lockscreen"),
}

private data class PreviewApp(
    val name: String,
    val access: String,
    val accent: Color,
)

private val previewApps =
    listOf(
        PreviewApp(
            name = "Camera",
            access = "Camera · Microphone · Photos",
            accent = Color(0xFF4D9CFF),
        ),
        PreviewApp(
            name = "Maps",
            access = "Location · Network · +1 more",
            accent = Color(0xFF35C66B),
        ),
        PreviewApp(
            name = "Messages",
            access = "Contacts · Notifications",
            accent = Color(0xFFFF8A4D),
        ),
        PreviewApp(
            name = "Calculator",
            access = "No sensitive access",
            accent = Color(0xFF8D5CE6),
        ),
        PreviewApp(
            name = "Sable Media",
            access = "Files selected by you · Network for radio",
            accent = Color(0xFFFF4F9A),
        ),
    )

@Composable
internal fun SystemSurfacesPreviewScreen() {
    var pageIndex by remember { mutableIntStateOf(0) }
    val pages = PreviewPage.entries
    val page = pages[pageIndex]

    fun goTo(target: PreviewPage) {
        pageIndex = pages.indexOf(target)
    }

    BackHandler(enabled = page != PreviewPage.Settings) {
        pageIndex = 0
    }

    Surface(
        modifier = Modifier.fillMaxSize(),
        color = MaterialTheme.colorScheme.background,
    ) {
        Column(
            modifier =
                Modifier
                    .fillMaxSize()
                    .safeDrawingPadding(),
        ) {
            Box(
                modifier = Modifier.weight(1f),
            ) {
                when (page) {
                    PreviewPage.Settings ->
                        SettingsPreview(
                            onApplications = {
                                goTo(PreviewPage.Applications)
                            },
                            onAbout = {
                                goTo(PreviewPage.About)
                            },
                        )

                    PreviewPage.Applications ->
                        ApplicationsPreview(
                            onBack = {
                                goTo(PreviewPage.Settings)
                            },
                            onApp = {
                                goTo(PreviewPage.AppSecurity)
                            },
                        )

                    PreviewPage.AppSecurity ->
                        AppSecurityPreview(
                            onBack = {
                                goTo(PreviewPage.Applications)
                            },
                        )

                    PreviewPage.SetupWelcome ->
                        SetupWelcomePreview(
                            onContinue = {
                                goTo(PreviewPage.SetupFinish)
                            },
                        )

                    PreviewPage.SetupFinish ->
                        SetupFinishPreview()

                    PreviewPage.About ->
                        AboutPreview(
                            onBack = {
                                goTo(PreviewPage.Settings)
                            },
                        )

                    PreviewPage.Lockscreen ->
                        LockscreenPreview()
                }
            }

            PreviewNavigator(
                current = pageIndex,
                count = pages.size,
                label = page.label,
                onPrevious = {
                    pageIndex =
                        if (pageIndex == 0) {
                            pages.lastIndex
                        } else {
                            pageIndex - 1
                        }
                },
                onNext = {
                    pageIndex =
                        if (pageIndex == pages.lastIndex) {
                            0
                        } else {
                            pageIndex + 1
                        }
                },
            )
        }
    }
}

@Composable
private fun PreviewList(
    content: androidx.compose.foundation.lazy.LazyListScope.() -> Unit,
) {
    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding =
            PaddingValues(
                horizontal = SableSpacing.ScreenHorizontal,
                vertical = SableSpacing.ScreenVertical,
            ),
        verticalArrangement = Arrangement.spacedBy(SableSpacing.Lg),
        content = content,
    )
}

@Composable
private fun SettingsPreview(
    onApplications: () -> Unit,
    onAbout: () -> Unit,
) {
    PreviewList {
        item {
            SableHeroHeader(
                eyebrow = "SableOS · UI5 preview",
                title = "settings",
                subtitle = "Device controls with security and privacy state kept visible.",
            )
        }

        item {
            SettingsSectionTitle("device")
        }

        item {
            SettingsRow(
                title = "Network & internet",
                subtitle = "Wi-Fi, mobile data, VPN and network privacy",
                value = "Connected",
            )
        }

        item {
            SettingsRow(
                title = "Connected devices",
                subtitle = "Bluetooth, USB and nearby device access",
                value = "2 devices",
            )
        }

        item {
            SettingsSectionTitle("privacy & security")
        }

        item {
            SettingsRow(
                title = "Applications",
                subtitle = "Access, privacy signals and app controls",
                value = "42 apps",
                accent = true,
                onClick = onApplications,
            )
        }

        item {
            SettingsRow(
                title = "Privacy",
                subtitle = "Permission use, indicators and privacy controls",
                value = "Review",
            )
        }

        item {
            SettingsRow(
                title = "Security",
                subtitle = "Device protection, credentials and exploit protection",
                value = "Protected",
            )
        }

        item {
            SettingsSectionTitle("system")
        }

        item {
            SettingsRow(
                title = "Battery",
                subtitle = "Usage and background restrictions",
                value = "84%",
            )
        }

        item {
            SettingsRow(
                title = "Storage",
                subtitle = "Local storage and media",
                value = "37 GB free",
            )
        }

        item {
            SettingsRow(
                title = "About SableOS",
                subtitle = "Version, build, device and update information",
                value = "Android 17",
                onClick = onAbout,
            )
        }
    }
}

@Composable
private fun ApplicationsPreview(
    onBack: () -> Unit,
    onApp: () -> Unit,
) {
    PreviewList {
        item {
            BackHeader(
                eyebrow = "Settings",
                title = "applications",
                subtitle =
                    "Effective sensitive access is summarized here. Advanced evidence stays in each app.",
                onBack = onBack,
            )
        }

        item {
            PreviewEvidenceBanner()
        }

        items(previewApps) { app ->
            AppSummaryRow(
                app = app,
                onClick = onApp,
            )
        }
    }
}

@Composable
private fun AppSecurityPreview(
    onBack: () -> Unit,
) {
    PreviewList {
        item {
            BackHeader(
                eyebrow = "Applications",
                title = "Camera",
                subtitle = "Application Security & Privacy",
                onBack = onBack,
            )
        }

        item {
            PreviewEvidenceBanner()
        }

        item {
            AppIdentityCard()
        }

        item {
            EvidenceSectionTitle(
                title = "effective authority",
                subtitle = "What Android currently allows or has observed.",
            )
        }

        item {
            EvidenceRow(
                title = "Camera",
                detail = "Allowed only while the app is in use",
                evidence = "ENFORCED",
                accent = Color(0xFF4D9CFF),
            )
        }

        item {
            EvidenceRow(
                title = "Microphone",
                detail = "Allowed only while the app is in use · used today",
                evidence = "OBSERVED",
                accent = Color(0xFF35C66B),
            )
        }

        item {
            EvidenceRow(
                title = "Location",
                detail = "Not granted",
                evidence = "ENFORCED",
                accent = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }

        item {
            EvidenceSectionTitle(
                title = "components & attack surface",
                subtitle = "Reachability is inspection data, not a risk score.",
            )
        }

        item {
            SecurityMetricRow(
                title = "Activities",
                value = "6",
                detail = "1 exported",
            )
        }

        item {
            SecurityMetricRow(
                title = "Services",
                value = "2",
                detail = "0 exported",
            )
        }

        item {
            SecurityMetricRow(
                title = "Receivers",
                value = "3",
                detail = "1 exported · permission protected",
            )
        }

        item {
            EvidenceSectionTitle(
                title = "libraries & privacy signals",
                subtitle = "Detection does not prove execution or tracking.",
            )
        }

        item {
            EvidenceRow(
                title = "Native code",
                detail = "arm64-v8a libraries packaged",
                evidence = "DETECTED",
                accent = Color(0xFFFF8A4D),
            )
        }

        item {
            EvidenceRow(
                title = "Tracker signatures",
                detail = "No known signatures in preview sample",
                evidence = "INFERRED",
                accent = Color(0xFF8D5CE6),
            )
        }

        item {
            EvidenceSectionTitle(
                title = "data, network & background",
                subtitle = "Only trustworthy platform evidence should appear here.",
            )
        }

        item {
            SecurityMetricRow(
                title = "Network",
                value = "Allowed",
                detail = "12 MB Wi-Fi · 0 MB mobile in sample",
            )
        }

        item {
            SecurityMetricRow(
                title = "Background",
                value = "Restricted",
                detail = "No active foreground service",
            )
        }

        item {
            EvidenceSectionTitle(
                title = "security & privacy history",
                subtitle = "Bounded, local history of material app changes.",
            )
        }

        item {
            HistoryRow(
                date = "Sep 18",
                title = "Updated to version 17.2",
                detail = "No new sensitive permissions",
            )
        }

        item {
            HistoryRow(
                date = "Sep 11",
                title = "Microphone permission granted",
                detail = "User-approved runtime permission change",
            )
        }

        item {
            Text(
                text =
                    "Preview only. Production UI must source DECLARED, ENFORCED, OBSERVED, INFERRED and UNKNOWN states from qualified Android platform evidence.",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    }
}

@Composable
private fun SetupWelcomePreview(
    onContinue: () -> Unit,
) {
    PreviewList {
        item {
            Spacer(
                modifier = Modifier.height(48.dp),
            )
        }

        item {
            SableMark(
                size = 88.dp,
            )
        }

        item {
            Text(
                text = "welcome to",
                style = MaterialTheme.typography.titleLarge,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            Text(
                text = "SableOS",
                style = MaterialTheme.typography.displayLarge,
                fontWeight = FontWeight.Light,
            )
        }

        item {
            Text(
                text =
                    "A private, security-focused Android experience with clear control over applications, data and device access.",
                style = MaterialTheme.typography.bodyLarge,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }

        item {
            SableTile(
                title = "Private by default",
                subtitle = "No required account or advertising profile",
                active = true,
                modifier = Modifier.fillMaxWidth(),
                onClick = {},
            )
        }

        item {
            SableTile(
                title = "Your apps, visible authority",
                subtitle = "Review sensitive access and security-relevant state",
                modifier = Modifier.fillMaxWidth(),
                onClick = {},
            )
        }

        item {
            SableActionButton(
                text = "Start setup",
                modifier = Modifier.fillMaxWidth(),
                onClick = onContinue,
            )
        }

        item {
            SableActionButton(
                text = "Accessibility",
                primary = false,
                modifier = Modifier.fillMaxWidth(),
                onClick = {},
            )
        }
    }
}

@Composable
private fun SetupFinishPreview() {
    PreviewList {
        item {
            Spacer(
                modifier = Modifier.height(72.dp),
            )
        }

        item {
            SableMark(
                size = 72.dp,
            )
        }

        item {
            Text(
                text = "you're ready",
                style = MaterialTheme.typography.displayMedium,
                fontWeight = FontWeight.Light,
            )
        }

        item {
            Text(
                text =
                    "SableOS is ready to use. Privacy and security controls stay available from Settings at any time.",
                style = MaterialTheme.typography.bodyLarge,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }

        item {
            Surface(
                modifier = Modifier.fillMaxWidth(),
                shape = MaterialTheme.shapes.medium,
                color = MaterialTheme.colorScheme.surface,
                border =
                    BorderStroke(
                        1.dp,
                        MaterialTheme.colorScheme.outlineVariant,
                    ),
            ) {
                Column(
                    modifier = Modifier.padding(SableSpacing.Lg),
                    verticalArrangement = Arrangement.spacedBy(SableSpacing.Md),
                ) {
                    Text(
                        text = "setup summary",
                        style = MaterialTheme.typography.titleLarge,
                    )
                    SummaryLine("Network", "Connected")
                    SummaryLine("Screen lock", "Configured")
                    SummaryLine("Backup", "Not configured")
                    SummaryLine("App review", "Available in Settings")
                }
            }
        }

        item {
            SableActionButton(
                text = "Go to Start",
                modifier = Modifier.fillMaxWidth(),
                onClick = {},
            )
        }
    }
}

@Composable
private fun AboutPreview(
    onBack: () -> Unit,
) {
    PreviewList {
        item {
            BackHeader(
                eyebrow = "Settings",
                title = "about SableOS",
                subtitle = "Device and software identity.",
                onBack = onBack,
            )
        }

        item {
            SableMark(
                size = 68.dp,
            )
        }

        item {
            AboutValue(
                label = "SableOS version",
                value = "R8 development preview",
            )
        }

        item {
            AboutValue(
                label = "Android version",
                value = "17",
            )
        }

        item {
            AboutValue(
                label = "Device",
                value = "Pixel 7 · panther",
            )
        }

        item {
            AboutValue(
                label = "Security update",
                value = "Preview build",
            )
        }

        item {
            Text(
                text =
                    "Preview content is illustrative. Production version/build/security fields must come directly from the device build properties.",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    }
}

@Composable
private fun LockscreenPreview() {
    Box(
        modifier =
            Modifier
                .fillMaxSize()
                .background(MaterialTheme.colorScheme.background),
    ) {
        Column(
            modifier =
                Modifier
                    .fillMaxWidth()
                    .align(Alignment.TopStart)
                    .padding(
                        horizontal = 28.dp,
                        vertical = 52.dp,
                    ),
            verticalArrangement = Arrangement.spacedBy(SableSpacing.Md),
        ) {
            Text(
                text = "12:34",
                style = MaterialTheme.typography.displayLarge,
                fontWeight = FontWeight.Light,
            )
            Text(
                text = "Saturday, September 19",
                style = MaterialTheme.typography.titleLarge,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }

        Column(
            modifier =
                Modifier
                    .fillMaxWidth()
                    .align(Alignment.BottomCenter)
                    .padding(
                        horizontal = 28.dp,
                        vertical = 36.dp,
                    ),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(SableSpacing.Md),
        ) {
            Text(
                text = "No notifications",
                style = MaterialTheme.typography.bodyLarge,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )

            Surface(
                shape = MaterialTheme.shapes.large,
                color = MaterialTheme.colorScheme.primary,
                contentColor = MaterialTheme.colorScheme.onPrimary,
            ) {
                Text(
                    text = "unlock",
                    modifier =
                        Modifier.padding(
                            horizontal = 28.dp,
                            vertical = 14.dp,
                        ),
                    style = MaterialTheme.typography.titleMedium,
                )
            }

            Text(
                text = "UI6 visual preview · authentication behavior unchanged",
                style = MaterialTheme.typography.labelLarge,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    }
}

@Composable
private fun SettingsSectionTitle(
    text: String,
) {
    Text(
        text = text,
        style = MaterialTheme.typography.titleMedium,
        color = MaterialTheme.colorScheme.primary,
    )
}

@Composable
private fun SettingsRow(
    title: String,
    subtitle: String,
    value: String,
    accent: Boolean = false,
    onClick: () -> Unit = {},
) {
    Surface(
        onClick = onClick,
        modifier = Modifier.fillMaxWidth(),
        shape = MaterialTheme.shapes.medium,
        color =
            if (accent) {
                MaterialTheme.colorScheme.surfaceVariant
            } else {
                MaterialTheme.colorScheme.surface
            },
        border =
            BorderStroke(
                1.dp,
                if (accent) {
                    MaterialTheme.colorScheme.primary
                } else {
                    MaterialTheme.colorScheme.outlineVariant
                },
            ),
    ) {
        Row(
            modifier = Modifier.padding(SableSpacing.Lg),
            horizontalArrangement = Arrangement.spacedBy(SableSpacing.Lg),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Column(
                modifier = Modifier.weight(1f),
                verticalArrangement = Arrangement.spacedBy(SableSpacing.Xs),
            ) {
                Text(
                    text = title,
                    style = MaterialTheme.typography.titleMedium,
                )
                Text(
                    text = subtitle,
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }

            Text(
                text = value,
                style = MaterialTheme.typography.labelLarge,
                color =
                    if (accent) {
                        MaterialTheme.colorScheme.primary
                    } else {
                        MaterialTheme.colorScheme.onSurfaceVariant
                    },
            )
        }
    }
}

@Composable
private fun AppSummaryRow(
    app: PreviewApp,
    onClick: () -> Unit,
) {
    Surface(
        onClick = onClick,
        modifier = Modifier.fillMaxWidth(),
        shape = MaterialTheme.shapes.medium,
        color = MaterialTheme.colorScheme.surface,
        border =
            BorderStroke(
                1.dp,
                MaterialTheme.colorScheme.outlineVariant,
            ),
    ) {
        Row(
            modifier = Modifier.padding(SableSpacing.Lg),
            horizontalArrangement = Arrangement.spacedBy(SableSpacing.Lg),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Surface(
                modifier = Modifier.size(48.dp),
                shape = MaterialTheme.shapes.medium,
                color = app.accent,
                contentColor = Color.White,
            ) {
                Box(
                    contentAlignment = Alignment.Center,
                ) {
                    Text(
                        text = app.name.first().toString(),
                        style = MaterialTheme.typography.titleLarge,
                        fontWeight = FontWeight.Bold,
                    )
                }
            }

            Column(
                modifier = Modifier.weight(1f),
                verticalArrangement = Arrangement.spacedBy(SableSpacing.Xs),
            ) {
                Text(
                    text = app.name,
                    style = MaterialTheme.typography.titleMedium,
                )
                Text(
                    text = app.access,
                    style = MaterialTheme.typography.bodyMedium,
                    color =
                        if (app.access == "No sensitive access") {
                            MaterialTheme.colorScheme.onSurfaceVariant
                        } else {
                            MaterialTheme.colorScheme.primary
                        },
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis,
                )
            }

            Text(
                text = "›",
                style = MaterialTheme.typography.headlineMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    }
}

@Composable
private fun AppIdentityCard() {
    Surface(
        modifier = Modifier.fillMaxWidth(),
        shape = MaterialTheme.shapes.medium,
        color = MaterialTheme.colorScheme.surfaceVariant,
        border =
            BorderStroke(
                1.dp,
                MaterialTheme.colorScheme.outlineVariant,
            ),
    ) {
        Column(
            modifier = Modifier.padding(SableSpacing.Lg),
            verticalArrangement = Arrangement.spacedBy(SableSpacing.Md),
        ) {
            Text(
                text = "identity & provenance",
                style = MaterialTheme.typography.titleLarge,
            )
            SummaryLine("Package", "com.android.camera2")
            SummaryLine("Version", "17.2 · target SDK 36")
            SummaryLine("Installed by", "System image")
            SummaryLine("Signing", "Platform lineage verified")
            SummaryLine("Native code", "Yes · arm64-v8a")
        }
    }
}

@Composable
private fun EvidenceSectionTitle(
    title: String,
    subtitle: String,
) {
    Column(
        verticalArrangement = Arrangement.spacedBy(SableSpacing.Xs),
    ) {
        Text(
            text = title,
            style = MaterialTheme.typography.headlineSmall,
        )
        Text(
            text = subtitle,
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
}

@Composable
private fun EvidenceRow(
    title: String,
    detail: String,
    evidence: String,
    accent: Color,
) {
    Surface(
        modifier = Modifier.fillMaxWidth(),
        shape = MaterialTheme.shapes.medium,
        color = MaterialTheme.colorScheme.surface,
        border =
            BorderStroke(
                1.dp,
                MaterialTheme.colorScheme.outlineVariant,
            ),
    ) {
        Row(
            modifier = Modifier.padding(SableSpacing.Lg),
            horizontalArrangement = Arrangement.spacedBy(SableSpacing.Lg),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Box(
                modifier =
                    Modifier
                        .size(10.dp)
                        .background(
                            color = accent,
                            shape = MaterialTheme.shapes.extraSmall,
                        ),
            )

            Column(
                modifier = Modifier.weight(1f),
                verticalArrangement = Arrangement.spacedBy(SableSpacing.Xs),
            ) {
                Text(
                    text = title,
                    style = MaterialTheme.typography.titleMedium,
                )
                Text(
                    text = detail,
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }

            Text(
                text = evidence,
                style = MaterialTheme.typography.labelLarge,
                color = accent,
            )
        }
    }
}

@Composable
private fun SecurityMetricRow(
    title: String,
    value: String,
    detail: String,
) {
    Surface(
        modifier = Modifier.fillMaxWidth(),
        shape = MaterialTheme.shapes.medium,
        color = MaterialTheme.colorScheme.surface,
        border =
            BorderStroke(
                1.dp,
                MaterialTheme.colorScheme.outlineVariant,
            ),
    ) {
        Row(
            modifier = Modifier.padding(SableSpacing.Lg),
            horizontalArrangement = Arrangement.spacedBy(SableSpacing.Lg),
        ) {
            Column(
                modifier = Modifier.weight(1f),
            ) {
                Text(
                    text = title,
                    style = MaterialTheme.typography.titleMedium,
                )
                Text(
                    text = detail,
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }

            Text(
                text = value,
                style = MaterialTheme.typography.titleMedium,
                color = MaterialTheme.colorScheme.primary,
            )
        }
    }
}

@Composable
private fun HistoryRow(
    date: String,
    title: String,
    detail: String,
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(SableSpacing.Lg),
    ) {
        Text(
            text = date,
            style = MaterialTheme.typography.labelLarge,
            color = MaterialTheme.colorScheme.primary,
        )

        Column(
            modifier = Modifier.weight(1f),
        ) {
            Text(
                text = title,
                style = MaterialTheme.typography.titleMedium,
            )
            Text(
                text = detail,
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    }
}

@Composable
private fun PreviewEvidenceBanner() {
    Surface(
        modifier = Modifier.fillMaxWidth(),
        shape = MaterialTheme.shapes.medium,
        color = MaterialTheme.colorScheme.surfaceVariant,
        border =
            BorderStroke(
                1.dp,
                MaterialTheme.colorScheme.primary,
            ),
    ) {
        Text(
            text =
                "Preview sample data · production state must come from Android platform evidence.",
            modifier = Modifier.padding(SableSpacing.Lg),
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
}

@Composable
private fun BackHeader(
    eyebrow: String,
    title: String,
    subtitle: String,
    onBack: () -> Unit,
) {
    Column(
        verticalArrangement = Arrangement.spacedBy(SableSpacing.Md),
    ) {
        Surface(
            onClick = onBack,
            color = Color.Transparent,
        ) {
            Text(
                text = "‹  $eyebrow",
                modifier =
                    Modifier.padding(
                        horizontal = 2.dp,
                        vertical = 8.dp,
                    ),
                style = MaterialTheme.typography.labelLarge,
                color = MaterialTheme.colorScheme.primary,
            )
        }

        Text(
            text = title,
            style = MaterialTheme.typography.displayMedium,
            fontWeight = FontWeight.Light,
        )

        Text(
            text = subtitle,
            style = MaterialTheme.typography.bodyLarge,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
}

@Composable
private fun SummaryLine(
    label: String,
    value: String,
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(SableSpacing.Lg),
    ) {
        Text(
            text = label,
            modifier = Modifier.weight(0.42f),
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )

        Text(
            text = value,
            modifier = Modifier.weight(0.58f),
            style = MaterialTheme.typography.bodyMedium,
        )
    }
}

@Composable
private fun AboutValue(
    label: String,
    value: String,
) {
    Surface(
        modifier = Modifier.fillMaxWidth(),
        shape = MaterialTheme.shapes.medium,
        color = MaterialTheme.colorScheme.surface,
        border =
            BorderStroke(
                1.dp,
                MaterialTheme.colorScheme.outlineVariant,
            ),
    ) {
        Column(
            modifier = Modifier.padding(SableSpacing.Lg),
            verticalArrangement = Arrangement.spacedBy(SableSpacing.Xs),
        ) {
            Text(
                text = label,
                style = MaterialTheme.typography.labelLarge,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            Text(
                text = value,
                style = MaterialTheme.typography.titleLarge,
            )
        }
    }
}

@Composable
private fun SableMark(
    size: androidx.compose.ui.unit.Dp,
) {
    Surface(
        modifier = Modifier.size(size),
        shape = MaterialTheme.shapes.medium,
        color = MaterialTheme.colorScheme.primary,
        contentColor = MaterialTheme.colorScheme.onPrimary,
    ) {
        Box(
            contentAlignment = Alignment.Center,
        ) {
            Text(
                text = "S",
                style = MaterialTheme.typography.displayMedium,
                fontWeight = FontWeight.Light,
            )
        }
    }
}

@Composable
private fun PreviewNavigator(
    current: Int,
    count: Int,
    label: String,
    onPrevious: () -> Unit,
    onNext: () -> Unit,
) {
    Surface(
        modifier = Modifier.fillMaxWidth(),
        color = MaterialTheme.colorScheme.surface,
        border =
            BorderStroke(
                1.dp,
                MaterialTheme.colorScheme.outlineVariant,
            ),
    ) {
        Row(
            modifier =
                Modifier
                    .fillMaxWidth()
                    .heightIn(min = 62.dp)
                    .padding(horizontal = SableSpacing.Md),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Surface(
                onClick = onPrevious,
                modifier = Modifier.size(48.dp),
                color = Color.Transparent,
            ) {
                Box(
                    contentAlignment = Alignment.Center,
                ) {
                    Text(
                        text = "‹",
                        style = MaterialTheme.typography.titleLarge,
                        color = MaterialTheme.colorScheme.primary,
                    )
                }
            }

            Column(
                modifier = Modifier.weight(1f),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                Text(
                    text = "${current + 1} / $count",
                    style = MaterialTheme.typography.labelLarge,
                )
                Text(
                    text = label,
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }

            Surface(
                onClick = onNext,
                modifier = Modifier.size(48.dp),
                color = Color.Transparent,
            ) {
                Box(
                    contentAlignment = Alignment.Center,
                ) {
                    Text(
                        text = "›",
                        style = MaterialTheme.typography.titleLarge,
                        color = MaterialTheme.colorScheme.primary,
                    )
                }
            }
        }
    }
}
