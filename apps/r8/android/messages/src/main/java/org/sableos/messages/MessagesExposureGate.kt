package org.sableos.messages

/** Default-deny boundary for user-visible message content. SystemUI/private-profile enforcement
 * remains owned by the platform. This app never attempts to unlock a profile itself. */
object MessagesExposureGate {
    fun showConversations(androidUserLocked: Boolean): Boolean = !androidUserLocked
}
