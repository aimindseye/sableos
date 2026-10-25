package org.sableos.start.privacy

/**
 * All Apps permission chips only match the *static granted group summary*
 * returned by LauncherAppsRepository. These are not permission-use timelines,
 * background activity, AppOps, or proof that a profile is currently unlocked.
 */
enum class AllAppsPermissionChip(
    val title: String,
    val grantedGroup: String?,
) {
    All("all apps", null),
    Camera("camera", "camera"),
    Location("location", "location"),
    Microphone("microphone", "microphone"),
    Contacts("contacts", "contacts"),
    Messages("messages", "messages"),
}

object AllAppsPermissionChipPolicy {
    private const val PREFIX = "permissions · "

    fun matches(
        privacySummary: String,
        chip: AllAppsPermissionChip,
    ): Boolean {
        if (chip == AllAppsPermissionChip.All) return true
        // An unavailable/locked profile must NOT be classified as having no
        // sensitive grants. If package permission state is unknown, don't match.
        if (!privacySummary.startsWith(PREFIX)) return false
        val groups =
            privacySummary
                .removePrefix(PREFIX)
                .split(" · ")
                .map(String::trim)
        return chip.grantedGroup in groups
    }
}
