package org.sableos.messages

/** Only navigation/actions may be intercepted before a child text field receives a key. */
internal object MessagesGlobalKeyPolicy {
    fun shouldHandle(action: MessagesAction): Boolean =
        when (action) {
            MessagesAction.ComposerTyping,
            MessagesAction.TypeToFilter,
            MessagesAction.ComposerEnterSend,
            MessagesAction.ComposerShiftEnterNewline,
            MessagesAction.ComposerAltEnterProviderSend,
            MessagesAction.ComposerBackspace,
            MessagesAction.ComposerDelete,
            -> false

            else -> true
        }
}
