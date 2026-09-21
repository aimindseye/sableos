package org.sableos.start.visualreview

import android.Manifest
import android.content.Intent
import android.content.pm.LauncherApps
import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.UserHandle
import android.provider.Settings
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.runtime.mutableStateOf
import org.sableos.design.SableAppearance
import org.sableos.design.applySableSystemBars
import org.sableos.design.resolveSableDarkAppearance
import org.sableos.start.model.AppEntry
import org.sableos.start.model.stableKey
import org.sableos.start.platform.LiveSurfaceRepository
import org.sableos.start.ui.SableStartScreen
import java.util.Locale

/**
 * Non-product Android Studio / Pixel 7 emulator host for the production R9
 * SableStartScreen.
 *
 * This APK deliberately has no HOME intent filter and is never part of the
 * Panther product. Launcher3QuickStep remains the only product HOME. The
 * activity exists solely to make the exact production presentation source
 * fast to review on the established Mac mini emulator workflow.
 */
class R9LauncherVisualReviewActivity : ComponentActivity() {
    private val appsState = mutableStateOf<List<AppEntry>>(emptyList())
    private val appearanceState = mutableStateOf(SableAppearance())
    private val refreshGeneration = mutableStateOf(0)
    private val livePermissionLauncher =
        registerForActivityResult(
            ActivityResultContracts.RequestMultiplePermissions(),
        ) {
            refreshGeneration.value += 1
        }

    private lateinit var launcherApps: LauncherApps
    private lateinit var liveSurfaceRepository: LiveSurfaceRepository

    private var pinnedKeys: Set<String> = emptySet()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        enableEdgeToEdge()
        launcherApps = getSystemService(LauncherApps::class.java)
        liveSurfaceRepository = LiveSurfaceRepository(this)

        refreshInventory()
        pinnedKeys = defaultPinnedKeys(appsState.value)

        applyCurrentSystemBars()

        setContent {
            SableStartScreen(
                apps = appsState.value,
                liveSurfaceRepository = liveSurfaceRepository,
                appearance = appearanceState.value,
                refreshGeneration = refreshGeneration.value,
                initialPinnedKeys = pinnedKeys,
                onPinnedKeysChanged = { keys ->
                    pinnedKeys = keys
                },
                onAppearanceChanged = { appearance ->
                    appearanceState.value = appearance
                    applyCurrentSystemBars()
                },
                onResetAppearance = {
                    appearanceState.value = SableAppearance()
                    applyCurrentSystemBars()
                },
                onLaunchApp = ::launchApp,
                onOpenSettings = ::openSettings,
                onOpenAppInfo = ::openAppInfo,
                onRequestLivePermissions = ::requestLivePermissions,
            )
        }
    }

    override fun onResume() {
        super.onResume()
        if (::launcherApps.isInitialized) {
            refreshInventory()
            applyCurrentSystemBars()
        }
    }

    private fun applyCurrentSystemBars() {
        applySableSystemBars(
            window = window,
            darkTheme =
                resolveSableDarkAppearance(
                    context = this,
                    appearance = appearanceState.value,
                ),
        )
    }

    private fun refreshInventory() {
        val locale = Locale.getDefault()

        appsState.value =
            launcherApps.profiles
                .flatMap { user ->
                    launcherApps.getActivityList(null, user).mapNotNull { info ->
                        val component = info.componentName
                        val label = info.label?.toString()?.trim().orEmpty()
                        if (
                            label.isEmpty() ||
                            component.packageName == packageName ||
                            component.packageName == GRAPHENE_MESSAGING_PACKAGE
                        ) {
                            null
                        } else {
                            AppEntry(
                                label = label,
                                component = component,
                                user = info.user,
                                privacySummary =
                                    buildPrivacyPermissionSummary(
                                        packageName = component.packageName,
                                        user = info.user,
                                    ),
                            )
                        }
                    }
                }
                .distinctBy { entry -> entry.stableKey() }
                .sortedWith(
                    compareBy<AppEntry> { entry ->
                        entry.label.lowercase(locale)
                    }.thenBy { entry ->
                        entry.component.flattenToString()
                    }.thenBy { entry ->
                        entry.user.hashCode()
                    },
                )
    }

    private fun buildPrivacyPermissionSummary(
        packageName: String,
        user: UserHandle,
    ): String {
        val profileContext =
            runCatching {
                createContextAsUser(user, 0)
            }.getOrElse {
                this
            }

        val packageInfo =
            runCatching {
                profileContext.packageManager.getPackageInfo(
                    packageName,
                    PackageManager.PackageInfoFlags.of(
                        PackageManager.GET_PERMISSIONS.toLong(),
                    ),
                )
            }.getOrNull() ?: return "permissions · unavailable"

        val requested = packageInfo.requestedPermissions.orEmpty()
        val flags = packageInfo.requestedPermissionsFlags ?: IntArray(0)

        val granted =
            buildSet {
                requested.forEachIndexed { index, permission ->
                    val permissionFlags = flags.getOrNull(index) ?: 0
                    if (
                        permissionFlags and
                            PackageInfo.REQUESTED_PERMISSION_GRANTED != 0
                    ) {
                        add(permission)
                    }
                }
            }

        val labels =
            PRIVACY_PERMISSION_GROUPS.mapNotNull { group ->
                group.label.takeIf { _ ->
                    group.permissions.any(granted::contains)
                }
            }

        return if (labels.isEmpty()) {
            "permissions · none sensitive"
        } else {
            "permissions · " + labels.joinToString(" · ")
        }
    }

    private fun launchApp(entry: AppEntry): Boolean =
        runCatching {
            launcherApps.startMainActivity(
                entry.component,
                entry.user,
                null,
                null,
            )
            true
        }.getOrElse {
            false
        }

    private fun openSettings() {
        runCatching {
            startActivity(Intent(Settings.ACTION_SETTINGS))
        }
    }

    private fun openAppInfo(entry: AppEntry) {
        runCatching {
            startActivity(
                Intent(
                    Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                    Uri.parse("package:${entry.component.packageName}"),
                ),
            )
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

        livePermissionLauncher.launch(
            permissions.toTypedArray(),
        )
    }

    private fun defaultPinnedKeys(apps: List<AppEntry>): Set<String> {
        val selected = linkedMapOf<String, AppEntry>()

        REVIEW_PIN_LABELS.forEach { preferred ->
            apps.firstOrNull { entry ->
                entry.label.equals(preferred, ignoreCase = true)
            }?.let { entry ->
                selected.putIfAbsent(entry.stableKey(), entry)
            }
        }

        apps.forEach { entry ->
            if (selected.size < REVIEW_PIN_COUNT) {
                selected.putIfAbsent(entry.stableKey(), entry)
            }
        }

        return selected.values
            .take(REVIEW_PIN_COUNT)
            .mapTo(linkedSetOf()) { entry -> entry.stableKey() }
    }

    private data class PrivacyPermissionGroup(
        val label: String,
        val permissions: Set<String>,
    )

    private companion object {
        const val GRAPHENE_MESSAGING_PACKAGE = "com.android.messaging"
        const val REVIEW_PIN_COUNT = 3

        val REVIEW_PIN_LABELS =
            listOf(
                "Phone",
                "Calendar",
                "Calculator",
                "Files",
                "Camera",
            )

        val PRIVACY_PERMISSION_GROUPS =
            listOf(
                PrivacyPermissionGroup(
                    label = "location",
                    permissions =
                        setOf(
                            Manifest.permission.ACCESS_COARSE_LOCATION,
                            Manifest.permission.ACCESS_FINE_LOCATION,
                            Manifest.permission.ACCESS_BACKGROUND_LOCATION,
                        ),
                ),
                PrivacyPermissionGroup(
                    label = "camera",
                    permissions = setOf(Manifest.permission.CAMERA),
                ),
                PrivacyPermissionGroup(
                    label = "microphone",
                    permissions = setOf(Manifest.permission.RECORD_AUDIO),
                ),
                PrivacyPermissionGroup(
                    label = "contacts",
                    permissions =
                        setOf(
                            Manifest.permission.READ_CONTACTS,
                            Manifest.permission.WRITE_CONTACTS,
                            Manifest.permission.GET_ACCOUNTS,
                        ),
                ),
                PrivacyPermissionGroup(
                    label = "phone",
                    permissions =
                        setOf(
                            Manifest.permission.READ_PHONE_STATE,
                            Manifest.permission.READ_PHONE_NUMBERS,
                            Manifest.permission.CALL_PHONE,
                            Manifest.permission.ANSWER_PHONE_CALLS,
                        ),
                ),
                PrivacyPermissionGroup(
                    label = "messages",
                    permissions =
                        setOf(
                            Manifest.permission.READ_SMS,
                            Manifest.permission.RECEIVE_SMS,
                            Manifest.permission.SEND_SMS,
                            Manifest.permission.RECEIVE_MMS,
                        ),
                ),
                PrivacyPermissionGroup(
                    label = "calendar",
                    permissions =
                        setOf(
                            Manifest.permission.READ_CALENDAR,
                            Manifest.permission.WRITE_CALENDAR,
                        ),
                ),
                PrivacyPermissionGroup(
                    label = "photos",
                    permissions =
                        setOf(
                            Manifest.permission.READ_MEDIA_IMAGES,
                            Manifest.permission.READ_MEDIA_VIDEO,
                            Manifest.permission.READ_EXTERNAL_STORAGE,
                        ),
                ),
                PrivacyPermissionGroup(
                    label = "audio",
                    permissions = setOf(Manifest.permission.READ_MEDIA_AUDIO),
                ),
                PrivacyPermissionGroup(
                    label = "nearby",
                    permissions =
                        setOf(
                            Manifest.permission.BLUETOOTH_SCAN,
                            Manifest.permission.BLUETOOTH_CONNECT,
                            Manifest.permission.NEARBY_WIFI_DEVICES,
                        ),
                ),
                PrivacyPermissionGroup(
                    label = "notifications",
                    permissions = setOf(Manifest.permission.POST_NOTIFICATIONS),
                ),
            )
    }
}
