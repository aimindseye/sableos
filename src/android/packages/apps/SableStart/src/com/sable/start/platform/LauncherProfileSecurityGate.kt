package org.sableos.start.platform

/**
 * Launcher-side defense-in-depth, not an OS-wide application lock or profile policy.
 * Android UserManager/LauncherApps remain authoritative for profile and activity state.
 *
 * Never treat a stale All Apps snapshot or a saved UI toggle as permission to launch.
 */
internal object LauncherProfileSecurityGate {
    fun mayLaunch(
        knownProfile: Boolean,
        ownUser: Boolean,
        supportedManagedOrPrivateProfile: Boolean,
        quietModeEnabled: Boolean,
        currentActivityVisible: Boolean,
    ): Boolean {
        if (!knownProfile || !currentActivityVisible) return false
        if (ownUser) return true
        return supportedManagedOrPrivateProfile && !quietModeEnabled
    }

    /** Only Android's actual private profile can be toggled through this entry. */
    fun mayTogglePrivateSpace(
        knownProfile: Boolean,
        isActualPrivateProfile: Boolean,
    ): Boolean = knownProfile && isActualPrivateProfile
}
