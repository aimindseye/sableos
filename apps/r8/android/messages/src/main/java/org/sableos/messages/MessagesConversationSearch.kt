package org.sableos.messages

/** In-thread, permission-scoped filtering of an already authorized thread. */
object MessagesConversationSearch {
    fun visibleMessages(
        thread: SableThread,
        query: String,
        limit: Int = 3,
    ): List<SableMessage> {
        if (limit <= 0) return emptyList()
        val needle = query.trim()
        val selected = if (needle.isEmpty()) thread.messages else thread.messages.filter { message ->
            message.body.contains(needle, ignoreCase = true) ||
                message.sender.contains(needle, ignoreCase = true)
        }
        return selected.takeLast(limit)
    }

    fun showNewMessagePrompt(state: MessagesUiState): Boolean =
        state.newMessageIndicator &&
            (state.mode == MessagesMode.History || state.mode == MessagesMode.Search)
}
