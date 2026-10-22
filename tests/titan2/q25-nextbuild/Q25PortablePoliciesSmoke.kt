package org.sableos.start.nextbuild

import org.sableos.start.model.CommandQuery
import org.sableos.start.model.CommandRanking
import org.sableos.start.model.CommandScope
import org.sableos.start.privacy.AllAppsKeyAction
import org.sableos.start.privacy.AllAppsKeyPolicy
import org.sableos.start.privacy.AppAction
import org.sableos.start.privacy.AppActionContext
import org.sableos.start.privacy.AppActionPolicy

/** Pure host-side Q25 policy smoke checks; never queries installed profiles, IMS or device. */
fun main() {
    check(CommandQuery.parse("?camera") == CommandQuery(CommandScope.Apps, "camera"))
    check(CommandQuery.parse("/apps camera") == CommandQuery(CommandScope.Apps, "camera"))
    check(CommandQuery.parse("/settings wifi") == CommandQuery(CommandScope.Settings, "wifi"))
    check(CommandQuery.parse("@alice").scope == CommandScope.People)
    check(CommandQuery.parse("!appearance").scope == CommandScope.Actions)
    check(CommandQuery.parse("/hub").scope == CommandScope.Hub)
    check(CommandQuery.parse("calendar").scope == CommandScope.All)
    check(CommandQuery.dialable("+1 (201) 555-0100") == "+12015550100")
    check(CommandQuery.dialable("9") == null)
    check(CommandRanking.settings("wi").first().title == "Wi-Fi")
    val apps = listOf("Camera", "Calendar", "Hub", "Calculator")
    check(
        CommandRanking.apps(
            items = apps,
            label = { it },
            recentRank = { if (it == "Calendar") 0 else null },
            term = "cal",
        ) == listOf("Calendar", "Calculator"),
    )
    check(
        CommandRanking.apps(
            items = apps,
            label = { it },
            recentRank = { if (it == "Hub") 0 else null },
            term = "",
        ).first() == "Hub",
    )
    check(
        AllAppsKeyPolicy.decide(84, 0, 0).action == AllAppsKeyAction.Search,
    )
    check(
        AllAppsKeyPolicy.decide(66, 0, 0).action == AllAppsKeyAction.Open,
    )
    check(
        AllAppsKeyPolicy.decide(66, 0, AllAppsKeyPolicy.META_ALT_ON).action == AllAppsKeyAction.AppInfo,
    )
    check(
        AllAppsKeyPolicy.decide(66, 0, AllAppsKeyPolicy.META_FUNCTION_ON).action == AllAppsKeyAction.Actions,
    )
    check(
        AllAppsKeyPolicy.decide(42, 'c'.code, 0).action == AllAppsKeyAction.TypeToJump,
    )
    check(
        AllAppsKeyPolicy.decide(42, 'c'.code, 0, editableFocused = true).action == AllAppsKeyAction.PassThrough,
    )
    check(
        AllAppsKeyPolicy.decide(84, 0, 0, repeat = true).action == AllAppsKeyAction.IgnoreRepeat,
    )
    val choices = AppActionPolicy.actions(
        AppActionContext(
            pinnedToStart = false,
            inBaseBar = null,
            launcherUser = false,
            canUninstall = false,
        ),
    )
    check(AppAction.PinToStart in choices)
    check(AppAction.Uninstall !in choices)
    check(AppAction.NotificationSettings !in choices)
    check(AppActionPolicy.requiresConfirmation(AppAction.Uninstall))
    println("Q25_PORTABLE_POLICY_SMOKE=PASS_22")
}
