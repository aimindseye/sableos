package org.sableos.hub

import java.nio.charset.StandardCharsets
import java.util.Base64

data class ConnectedAppKey(
    val packageName: String,
    val userSerial: Long,
) {
    init {
        require(packageName.isNotBlank())
        require(userSerial >= 0L)
    }
}

private const val SEVEN_DAY_RETENTION = 7
private const val THIRTY_DAY_RETENTION = 30

enum class HistoryRetention(
    val days: Int?,
    val label: String,
) {
    SevenDays(SEVEN_DAY_RETENTION, "7 days"),
    ThirtyDays(THIRTY_DAY_RETENTION, "30 days"),
    UntilDeleted(null, "Until deleted"),
    ;

    fun next(): HistoryRetention =
        when (this) {
            SevenDays -> ThirtyDays
            ThirtyDays -> UntilDeleted
            UntilDeleted -> SevenDays
        }
}

data class ConnectedAppPolicy(
    val key: ConnectedAppKey,
    val includeInMessages: Boolean = false,
    val allowQuickReply: Boolean = false,
    val hideFromLauncher: Boolean = false,
    val retention: HistoryRetention = HistoryRetention.ThirtyDays,
) {
    fun normalized(): ConnectedAppPolicy =
        if (includeInMessages) {
            this
        } else {
            copy(
                allowQuickReply = false,
                hideFromLauncher = false,
            )
        }

    fun isDefaultDisabled(): Boolean {
        val value = normalized()
        return !value.includeInMessages &&
            !value.allowQuickReply &&
            !value.hideFromLauncher &&
            value.retention == HistoryRetention.ThirtyDays
    }
}

object ConnectedAppPolicyCodec {
    private const val VERSION = "1"
    private const val FIELD_COUNT = 7
    private const val USER_SERIAL_INDEX = 1
    private const val PACKAGE_INDEX = 2
    private const val INCLUDE_INDEX = 3
    private const val REPLY_INDEX = 4
    private const val HIDE_INDEX = 5
    private const val RETENTION_INDEX = 6
    private const val SEPARATOR = "|"

    fun encode(policy: ConnectedAppPolicy): String {
        val value = policy.normalized()
        return listOf(
            VERSION,
            value.key.userSerial.toString(),
            encodeText(value.key.packageName),
            value.includeInMessages.asDigit(),
            value.allowQuickReply.asDigit(),
            value.hideFromLauncher.asDigit(),
            value.retention.name,
        ).joinToString(SEPARATOR)
    }

    fun decode(encoded: String): ConnectedAppPolicy? =
        runCatching {
            val fields = encoded.split(SEPARATOR)
            require(fields.size == FIELD_COUNT && fields[0] == VERSION)

            ConnectedAppPolicy(
                key =
                    ConnectedAppKey(
                        packageName = requireNotNull(decodeText(fields[PACKAGE_INDEX])),
                        userSerial = fields[USER_SERIAL_INDEX].toLong(),
                    ),
                includeInMessages = parseBooleanDigit(fields[INCLUDE_INDEX]),
                allowQuickReply = parseBooleanDigit(fields[REPLY_INDEX]),
                hideFromLauncher = parseBooleanDigit(fields[HIDE_INDEX]),
                retention = HistoryRetention.valueOf(fields[RETENTION_INDEX]),
            ).normalized()
        }.getOrNull()

    private fun encodeText(value: String): String =
        Base64.getUrlEncoder()
            .withoutPadding()
            .encodeToString(value.toByteArray(StandardCharsets.UTF_8))

    private fun decodeText(value: String): String? =
        runCatching {
            String(
                Base64.getUrlDecoder().decode(value),
                StandardCharsets.UTF_8,
            )
        }.getOrNull()

    private fun Boolean.asDigit(): String = if (this) "1" else "0"

    private fun parseBooleanDigit(value: String): Boolean =
        when (value) {
            "1" -> true
            "0" -> false
            else -> error("Invalid boolean digit")
        }
}
