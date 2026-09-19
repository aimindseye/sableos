#!/usr/bin/env python3
from __future__ import annotations

import subprocess
import sys
from pathlib import Path

EXPECTED_COMMIT = "c733317d933c22bcd790a4790306f30ccf2026b8"
SABLE_APPLICATION_ID = "org.sableos.mail"
SABLE_LABEL = "Sable Mail"


def fail(message: str) -> None:
    raise SystemExit(message)


def replace_once(path: Path, old: str, new: str) -> None:
    text = path.read_text(encoding="utf-8")
    count = text.count(old)
    if count != 1:
        fail(f"SABLE_MAIL_PATCH_ANCHOR=FAIL path={path} count={count} anchor={old!r}")
    path.write_text(text.replace(old, new, 1), encoding="utf-8")


def remove_once(path: Path, old: str) -> None:
    replace_once(path, old, "")


def write(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")


def git_head(root: Path) -> str:
    return subprocess.check_output(
        ["git", "-C", str(root), "rev-parse", "HEAD"],
        text=True,
    ).strip()


def main() -> None:
    if len(sys.argv) != 2:
        fail("usage: apply_sable_flavor.py <thunderbird-android-root>")

    root = Path(sys.argv[1]).resolve()
    if not (root / ".git").exists():
        fail(f"SABLE_MAIL_UPSTREAM=FAIL_NOT_GIT path={root}")

    actual = git_head(root)
    if actual != EXPECTED_COMMIT:
        fail(
            "SABLE_MAIL_UPSTREAM=FAIL_COMMIT "
            f"expected={EXPECTED_COMMIT} actual={actual}"
        )

    app = root / "app-thunderbird"
    build = app / "build.gradle.kts"

    replace_once(
        build,
        'applicationId = "net.thunderbird.android"',
        f'applicationId = "{SABLE_APPLICATION_ID}"',
    )
    replace_once(
        build,
        'testApplicationId = "net.thunderbird.android.tests"',
        f'testApplicationId = "{SABLE_APPLICATION_ID}.tests"',
    )
    replace_once(
        build,
        'versionName = "23.0"',
        'versionName = "23.0-sable-r8"',
    )
    replace_once(
        build,
        'signingConfig = signingConfigs.getByType(SigningType.TB_RELEASE)',
        'signingConfig = signingConfigs.getByName("debug")',
    )
    replace_once(
        build,
        'isMinifyEnabled = !isCI.get()',
        'isMinifyEnabled = true',
    )
    replace_once(
        build,
        'isShrinkResources = !isCI.get()',
        'isShrinkResources = true',
    )
    replace_once(
        build,
        r'buildConfigField("String", "CLIENT_INFO_APP_NAME", "\"Thunderbird for Android\"")',
        r'buildConfigField("String", "CLIENT_INFO_APP_NAME", "\"Sable Mail\"")',
    )
    replace_once(
        build,
        '"fossImplementation"(projects.feature.funding.link)',
        '"fossImplementation"(projects.feature.funding.noop)',
    )
    replace_once(
        build,
        "    implementation(projects.feature.onboarding.migration.thunderbird)\n",
        "    implementation(projects.feature.onboarding.migration.noop)\n",
    )
    replace_once(
        build,
        "    implementation(projects.feature.migration.launcher.thunderbird)\n",
        "    implementation(projects.feature.migration.launcher.noop)\n",
    )

    for line in (
        "    implementation(projects.feature.thundermail.api)\n",
        "    implementation(projects.feature.thundermail.thunderbird)\n",
        "    testImplementation(projects.feature.thundermail.internal.common)\n",
    ):
        remove_once(build, line)

    for variant in ("debug", "beta", "daily", "release"):
        feature_flags = (
            app
            / f"src/{variant}/kotlin/net/thunderbird/android/featureflag/"
            "TbFeatureFlagFactory.kt"
        )
        remove_once(
            feature_flags,
            "import net.thunderbird.feature.thundermail.featureflag.ThundermailFeatureFlags\n",
        )
        remove_once(
            feature_flags,
            "                FeatureFlag(ThundermailFeatureFlags.ThundermailOnboardingEnabled, enabled = true),\n",
        )

    strings = app / "src/main/res/values/strings.xml"
    replace_once(
        strings,
        '<string name="app_name" translatable="false">Thunderbird</string>',
        '<string name="app_name" translatable="false">Sable Mail</string>',
    )
    replace_once(
        strings,
        '<string name="brand_name" translatable="false">Thunderbird</string>',
        '<string name="brand_name" translatable="false">Sable Mail</string>',
    )

    debug_strings = app / "src/debug/res/values/strings.xml"
    replace_once(
        debug_strings,
        ">Thunderbird Debug</string>",
        ">Sable Mail</string>",
    )

    name_provider = (
        app
        / "src/main/kotlin/net/thunderbird/android/provider/TbAppNameProvider.kt"
    )
    replace_once(
        name_provider,
        'override val filePrefix: String = "thunderbird"',
        'override val filePrefix: String = "sable-mail"',
    )

    funding_settings = (
        app
        / "src/main/kotlin/net/thunderbird/android/feature/TbFundingSettings.kt"
    )
    if not funding_settings.is_file():
        fail(f"SABLE_MAIL_FUNDING_SOURCE=FAIL_MISSING path={funding_settings}")
    funding_settings.unlink()

    feature_module = (
        app
        / "src/main/kotlin/net/thunderbird/android/feature/FeatureModule.kt"
    )
    remove_once(
        feature_module,
        "import net.thunderbird.feature.thundermail.thunderbird.inject.featureThundermailModule\n",
    )
    remove_once(
        feature_module,
        "    includes(featureThundermailModule)\n",
    )
    remove_once(
        feature_module,
        "import net.thunderbird.feature.funding.api.FundingSettings\n",
    )
    remove_once(
        feature_module,
        "    single<FundingSettings> { TbFundingSettings() }\n",
    )

    di_test = app / "src/test/kotlin/net/thunderbird/android/DependencyInjectionTest.kt"
    remove_once(
        di_test,
        "import net.thunderbird.feature.thundermail.internal.common.ui.ThundermailContract\n",
    )
    remove_once(
        di_test,
        "                definition<ThundermailContract.ViewModel>(ThundermailContract.State::class),\n",
    )

    oauth_source = '''package net.thunderbird.android.auth

import net.thunderbird.core.common.oauth.OAuthConfiguration
import net.thunderbird.core.common.oauth.OAuthConfigurationFactory

/**
 * Sable Mail deliberately ships without inherited Thunderbird OAuth client IDs.
 *
 * Generic IMAP/SMTP remains available. Gmail/Microsoft OAuth must stay hidden
 * until Sable-owned provider registrations and redirect URIs are qualified.
 */
class TbOAuthConfigurationFactory : OAuthConfigurationFactory {
    override fun createConfigurations(): Map<List<String>, OAuthConfiguration> =
        emptyMap()
}
'''

    for variant in ("debug", "beta", "daily", "release"):
        write(
            app
            / f"src/{variant}/kotlin/net/thunderbird/android/auth/TbOAuthConfigurationFactory.kt",
            oauth_source,
        )

    provider_module = (
        app
        / "src/main/kotlin/net/thunderbird/android/provider/ProviderModule.kt"
    )
    replace_once(
        provider_module,
        "    single<ThemeProvider> { TbThemeProvider() }",
        "    single<ThemeProvider> { TbThemeProvider(androidContext()) }",
    )

    theme_provider = (
        app
        / "src/main/kotlin/net/thunderbird/android/provider/TbThemeProvider.kt"
    )
    write(
        theme_provider,
        '''package net.thunderbird.android.provider

import android.content.Context
import net.thunderbird.android.SableMailAppearanceReader
import net.thunderbird.android.SableMailThemeResources
import net.thunderbird.core.ui.theme.api.ThemeProvider

internal class TbThemeProvider(
    private val context: Context,
) : ThemeProvider {
    override val appThemeResourceId: Int
        get() = SableMailThemeResources.main(context)

    override val appLightThemeResourceId: Int
        get() = SableMailThemeResources.main(context, forceDark = false)

    override val appDarkThemeResourceId: Int
        get() = SableMailThemeResources.main(context, forceDark = true)

    override val dialogThemeResourceId: Int
        get() = SableMailThemeResources.dialog(context)

    override val translucentDialogThemeResourceId: Int
        get() = SableMailThemeResources.translucentDialog(context)
}
''',
    )

    icon_provider = (
        app
        / "src/main/kotlin/net/thunderbird/android/provider/TbAppIconNotificationProvider.kt"
    )
    write(
        icon_provider,
        '''package net.thunderbird.android.provider

import app.k9mail.core.android.common.provider.NotificationIconResourceProvider
import net.thunderbird.android.R

class TbAppIconNotificationProvider : NotificationIconResourceProvider {
    override val pushNotificationIcon: Int
        get() = R.drawable.ic_sable_mail_notification
}
''',
    )

    thunderbird_app = (
        app
        / "src/main/kotlin/net/thunderbird/android/ThunderbirdApp.kt"
    )
    write(
        thunderbird_app,
        '''package net.thunderbird.android

import app.k9mail.feature.telemetry.api.TelemetryManager
import net.thunderbird.app.common.BaseApplication
import net.thunderbird.core.preference.GeneralSettingsManager
import org.koin.android.ext.android.inject
import org.koin.core.module.Module

class ThunderbirdApp : BaseApplication() {
    private val telemetryManager: TelemetryManager by inject()
    private val generalSettingsManager: GeneralSettingsManager by inject()

    override fun provideAppModule(): Module = appModule

    override fun onCreate() {
        super.onCreate()

        SableMailAppearanceSync.install(
            application = this,
            generalSettingsManager = generalSettingsManager,
        )
        initializeTelemetry()
    }

    private fun initializeTelemetry() {
        telemetryManager.init(
            uploadEnabled = false,
            releaseChannel = BuildConfig.GLEAN_RELEASE_CHANNEL,
            versionCode = BuildConfig.VERSION_CODE,
            versionName = BuildConfig.VERSION_NAME,
        )
    }
}
''',
    )

    appearance_bridge = (
        app
        / "src/main/kotlin/net/thunderbird/android/SableMailAppearance.kt"
    )
    write(
        appearance_bridge,
        '''package net.thunderbird.android

import android.app.Activity
import android.app.Application
import android.content.Context
import android.content.res.Configuration
import android.database.ContentObserver
import android.net.Uri
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import java.lang.ref.WeakReference
import net.thunderbird.core.preference.AppTheme
import net.thunderbird.core.preference.GeneralSettingsManager
import net.thunderbird.core.preference.update

internal data class SableMailAppearance(
    val mode: String = "follow-system",
    val accent: String = "blue",
)

internal object SableMailAppearanceReader {
    private const val AUTHORITY = "org.sableos.start.appearance"
    private val URI = Uri.parse("content://$AUTHORITY/appearance")

    fun read(context: Context): SableMailAppearance =
        runCatching {
            context.contentResolver.query(
                URI,
                arrayOf("mode", "accent"),
                null,
                null,
                null,
            )?.use { cursor ->
                if (!cursor.moveToFirst()) {
                    return@use SableMailAppearance()
                }

                SableMailAppearance(
                    mode = cursor.getString(cursor.getColumnIndexOrThrow("mode")),
                    accent = cursor.getString(cursor.getColumnIndexOrThrow("accent")),
                )
            } ?: SableMailAppearance()
        }.getOrDefault(SableMailAppearance())

    fun uri(): Uri = URI

    fun resolveDark(
        context: Context,
        appearance: SableMailAppearance = read(context),
    ): Boolean =
        when (appearance.mode) {
            "light" -> false
            "dark" -> true
            else ->
                (
                    context.resources.configuration.uiMode and
                        Configuration.UI_MODE_NIGHT_MASK
                ) == Configuration.UI_MODE_NIGHT_YES
        }
}

internal object SableMailThemeResources {
    fun main(
        context: Context,
        forceDark: Boolean? = null,
    ): Int =
        resolveStyle(
            appearance = SableMailAppearanceReader.read(context),
            dark =
                forceDark
                    ?: SableMailAppearanceReader.resolveDark(context),
            kind = Kind.MAIN,
        )

    fun dialog(context: Context): Int =
        resolveStyle(
            appearance = SableMailAppearanceReader.read(context),
            dark = SableMailAppearanceReader.resolveDark(context),
            kind = Kind.DIALOG,
        )

    fun translucentDialog(context: Context): Int =
        resolveStyle(
            appearance = SableMailAppearanceReader.read(context),
            dark = SableMailAppearanceReader.resolveDark(context),
            kind = Kind.TRANSLUCENT,
        )

    private enum class Kind {
        MAIN,
        DIALOG,
        TRANSLUCENT,
    }

    private fun resolveStyle(
        appearance: SableMailAppearance,
        dark: Boolean,
        kind: Kind,
    ): Int =
        when (kind) {
            Kind.MAIN ->
                if (dark) {
                    when (appearance.accent) {
                        "green" -> R.style.Theme_SableMail_Dark_Green
                        "purple" -> R.style.Theme_SableMail_Dark_Purple
                        "orange" -> R.style.Theme_SableMail_Dark_Orange
                        "slate" -> R.style.Theme_SableMail_Dark_Slate
                        else -> R.style.Theme_SableMail_Dark_Blue
                    }
                } else {
                    when (appearance.accent) {
                        "green" -> R.style.Theme_SableMail_Light_Green
                        "purple" -> R.style.Theme_SableMail_Light_Purple
                        "orange" -> R.style.Theme_SableMail_Light_Orange
                        "slate" -> R.style.Theme_SableMail_Light_Slate
                        else -> R.style.Theme_SableMail_Light_Blue
                    }
                }

            Kind.DIALOG ->
                if (dark) {
                    when (appearance.accent) {
                        "green" -> R.style.Theme_SableMail_Dark_Green_Dialog
                        "purple" -> R.style.Theme_SableMail_Dark_Purple_Dialog
                        "orange" -> R.style.Theme_SableMail_Dark_Orange_Dialog
                        "slate" -> R.style.Theme_SableMail_Dark_Slate_Dialog
                        else -> R.style.Theme_SableMail_Dark_Blue_Dialog
                    }
                } else {
                    when (appearance.accent) {
                        "green" -> R.style.Theme_SableMail_Light_Green_Dialog
                        "purple" -> R.style.Theme_SableMail_Light_Purple_Dialog
                        "orange" -> R.style.Theme_SableMail_Light_Orange_Dialog
                        "slate" -> R.style.Theme_SableMail_Light_Slate_Dialog
                        else -> R.style.Theme_SableMail_Light_Blue_Dialog
                    }
                }

            Kind.TRANSLUCENT ->
                if (dark) {
                    when (appearance.accent) {
                        "green" -> R.style.Theme_SableMail_Dark_Green_Dialog_Translucent
                        "purple" -> R.style.Theme_SableMail_Dark_Purple_Dialog_Translucent
                        "orange" -> R.style.Theme_SableMail_Dark_Orange_Dialog_Translucent
                        "slate" -> R.style.Theme_SableMail_Dark_Slate_Dialog_Translucent
                        else -> R.style.Theme_SableMail_Dark_Blue_Dialog_Translucent
                    }
                } else {
                    when (appearance.accent) {
                        "green" -> R.style.Theme_SableMail_Light_Green_Dialog_Translucent
                        "purple" -> R.style.Theme_SableMail_Light_Purple_Dialog_Translucent
                        "orange" -> R.style.Theme_SableMail_Light_Orange_Dialog_Translucent
                        "slate" -> R.style.Theme_SableMail_Light_Slate_Dialog_Translucent
                        else -> R.style.Theme_SableMail_Light_Blue_Dialog_Translucent
                    }
                }
        }
}

internal object SableMailAppearanceSync {
    fun install(
        application: Application,
        generalSettingsManager: GeneralSettingsManager,
    ) {
        var current = SableMailAppearanceReader.read(application)
        var resumedActivity = WeakReference<Activity>(null)

        fun applyMode(appearance: SableMailAppearance) {
            val desired =
                when (appearance.mode) {
                    "light" -> AppTheme.LIGHT
                    "dark" -> AppTheme.DARK
                    else -> AppTheme.FOLLOW_SYSTEM
                }

            val existing =
                generalSettingsManager
                    .getConfig()
                    .display
                    .coreSettings
                    .appTheme

            if (existing != desired) {
                generalSettingsManager.update { settings ->
                    settings.copy(
                        display =
                            settings.display.copy(
                                coreSettings =
                                    settings.display.coreSettings.copy(
                                        appTheme = desired,
                                    ),
                            ),
                    )
                }
            }
        }

        applyMode(current)

        application.registerActivityLifecycleCallbacks(
            object : Application.ActivityLifecycleCallbacks {
                override fun onActivityResumed(activity: Activity) {
                    resumedActivity = WeakReference(activity)
                }

                override fun onActivityPaused(activity: Activity) = Unit
                override fun onActivityCreated(activity: Activity, state: Bundle?) = Unit
                override fun onActivityStarted(activity: Activity) = Unit
                override fun onActivityStopped(activity: Activity) = Unit
                override fun onActivitySaveInstanceState(activity: Activity, state: Bundle) = Unit

                override fun onActivityDestroyed(activity: Activity) {
                    if (resumedActivity.get() === activity) {
                        resumedActivity.clear()
                    }
                }
            },
        )

        application.contentResolver.registerContentObserver(
            SableMailAppearanceReader.uri(),
            false,
            object : ContentObserver(Handler(Looper.getMainLooper())) {
                override fun onChange(selfChange: Boolean) {
                    val next = SableMailAppearanceReader.read(application)
                    val modeChanged = next.mode != current.mode
                    val accentChanged = next.accent != current.accent
                    current = next

                    if (modeChanged) {
                        applyMode(next)
                    }
                    if (accentChanged) {
                        resumedActivity.get()?.recreate()
                    }
                }
            },
        )
    }
}
''',
    )

    core_theme_manager = (
        root
        / "core/ui/theme/manager/src/main/java/net/thunderbird/core/ui/theme/manager/ThemeManager.kt"
    )
    text = core_theme_manager.read_text(encoding="utf-8")
    text = text.replace(
        "override val appThemeResourceId: Int = themeProvider.appThemeResourceId",
        """override val appThemeResourceId: Int
        get() = themeProvider.appThemeResourceId""",
        1,
    )
    text = text.replace(
        "override val dialogThemeResourceId: Int = themeProvider.dialogThemeResourceId",
        """override val dialogThemeResourceId: Int
        get() = themeProvider.dialogThemeResourceId""",
        1,
    )
    text = text.replace(
        "override val translucentDialogThemeResourceId: Int = themeProvider.translucentDialogThemeResourceId",
        """override val translucentDialogThemeResourceId: Int
        get() = themeProvider.translucentDialogThemeResourceId""",
        1,
    )
    if "get() = themeProvider.appThemeResourceId" not in text:
        fail("SABLE_MAIL_THEME_MANAGER=FAIL_APP_THEME_GETTER")
    core_theme_manager.write_text(text, encoding="utf-8")

    manifest = app / "src/main/AndroidManifest.xml"
    manifest_text = manifest.read_text(encoding="utf-8")
    application_anchor = "\n    <application"
    if manifest_text.count(application_anchor) != 1:
        fail("SABLE_MAIL_MANIFEST=FAIL_APPLICATION_ANCHOR")
    manifest_text = manifest_text.replace(
        application_anchor,
        """
    <queries>
        <provider android:authorities="org.sableos.start.appearance" />
    </queries>

    <application""",
        1,
    )
    manifest.write_text(manifest_text, encoding="utf-8")

    replace_once(
        manifest,
        'android:icon="@mipmap/ic_launcher"',
        'android:icon="@drawable/ic_sable_mail"',
    )
    replace_once(
        manifest,
        'android:theme="@style/Theme.Thunderbird.Startup"',
        'android:theme="@style/Theme.SableMail.Startup"',
    )
    manifest_text = manifest.read_text(encoding="utf-8")
    manifest_text = manifest_text.replace(
        "@style/Theme.Thunderbird.DayNight.Dialog.Translucent",
        "@style/Theme.SableMail.DayNight.Dialog.Translucent",
    )
    manifest.write_text(manifest_text, encoding="utf-8")

    write(
        app / "src/main/res/drawable/ic_sable_mail.xml",
        '''<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="48dp"
    android:height="48dp"
    android:viewportWidth="48"
    android:viewportHeight="48">
    <path
        android:fillColor="#4D9CFF"
        android:pathData="M6,10h36v28H6z" />
    <path
        android:fillColor="#05070A"
        android:pathData="M8,12l16,13 16,-13v5L24,30 8,17z" />
</vector>
''',
    )
    write(
        app / "src/main/res/drawable/ic_sable_mail_notification.xml",
        '''<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="24dp"
    android:height="24dp"
    android:viewportWidth="24"
    android:viewportHeight="24">
    <path
        android:fillColor="#FFFFFFFF"
        android:pathData="M2,5h20v14H2zM4,7v1l8,6 8,-6V7l-8,6z" />
</vector>
''',
    )

    accents = {
        "Blue": ("#4D9CFF", "#06111F"),
        "Green": ("#35C66B", "#04140A"),
        "Purple": ("#7A42E8", "#FFFFFF"),
        "Orange": ("#F28C45", "#1D0C02"),
        "Slate": ("#64748B", "#FFFFFF"),
    }

    style_lines = [
        '<?xml version="1.0" encoding="utf-8"?>',
        "<resources>",
        '    <style name="Theme.SableMail.Startup" parent="Theme.Thunderbird.DayNight" />',
        '    <style name="Theme.SableMail.DayNight.Dialog.Translucent" parent="Theme.Thunderbird.DayNight.Dialog.Translucent" />',
        "",
    ]

    def style(name: str, parent: str, color: str, on_color: str) -> None:
        style_lines.extend(
            [
                f'    <style name="{name}" parent="{parent}">',
                f'        <item name="colorPrimary">{color}</item>',
                f'        <item name="colorOnPrimary">{on_color}</item>',
                f'        <item name="colorPrimaryContainer">{color}</item>',
                f'        <item name="colorOnPrimaryContainer">{on_color}</item>',
                f'        <item name="colorSecondary">{color}</item>',
                f'        <item name="colorOnSecondary">{on_color}</item>',
                f'        <item name="colorSecondaryContainer">{color}</item>',
                f'        <item name="colorOnSecondaryContainer">{on_color}</item>',
                '        <item name="appLogo">@drawable/ic_sable_mail</item>',
                "    </style>",
                "",
            ],
        )

    for accent, (color, on_color) in accents.items():
        for tone in ("Light", "Dark"):
            base = f"Theme.Thunderbird.{tone}"
            style(f"Theme.SableMail.{tone}.{accent}", base, color, on_color)
            style(
                f"Theme.SableMail.{tone}.{accent}.Dialog",
                f"Theme.Thunderbird.{tone}.Dialog",
                color,
                on_color,
            )
            style(
                f"Theme.SableMail.{tone}.{accent}.Dialog.Translucent",
                f"Theme.Thunderbird.{tone}.Dialog.Translucent",
                color,
                on_color,
            )

    style_lines.append("</resources>")
    write(
        app / "src/main/res/values/sable_mail_themes.xml",
        "\n".join(style_lines) + "\n",
    )

    print(f"SABLE_MAIL_UPSTREAM_COMMIT={actual}")
    print(f"SABLE_MAIL_APPLICATION_ID={SABLE_APPLICATION_ID}")
    print("SABLE_MAIL_BRANDING=SABLE_MAIL")
    print("SABLE_MAIL_BUILD_TYPE=FOSS_RELEASE_NON_DEBUGGABLE_MINIFIED")
    print("SABLE_MAIL_DEVELOPMENT_SIGNING=DEBUG_KEY_ONLY")
    print("SABLE_MAIL_TELEMETRY=NOOP_UPLOAD_DISABLED")
    print("SABLE_MAIL_FUNDING=NOOP")
    print("SABLE_MAIL_MIGRATION_UI=NOOP")
    print("SABLE_MAIL_FUNDING_SETTINGS_SOURCE=REMOVED_FROM_PRODUCT_APP")
    print("SABLE_MAIL_THUNDERMAIL=REMOVED_FROM_PRODUCT_APP")
    print("SABLE_MAIL_OAUTH=DISABLED_UNTIL_SABLE_CLIENT_REGISTRATION")
    print("SABLE_MAIL_GENERIC_IMAP_SMTP=UPSTREAM")
    print("SABLE_MAIL_GLOBAL_APPEARANCE=FOLLOW_SYSTEM_LIGHT_DARK_PLUS_5_ACCENTS")
    print("SABLE_MAIL_PATCH=PASS")


if __name__ == "__main__":
    main()
