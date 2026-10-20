package org.sableos.messages

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.provider.Telephony

/** Status is explicit: permission denied and provider failure must never fall back to sample data. */
sealed interface LiveSmsLoad {
    data class Ready(val threads: List<SableThread>) : LiveSmsLoad
    data object AccessDenied : LiveSmsLoad
    data object Unavailable : LiveSmsLoad
}

/**
 * Mirrors Sable Hub's established Telephony.Sms projection and bounded cursor consumption.
 * Calls must run on Dispatchers.IO. Never writes provider rows or assumes default-SMS ownership.
 */
class LiveSmsProvider(private val context: Context) {
    fun read(): LiveSmsLoad {
        if (context.checkSelfPermission(Manifest.permission.READ_SMS) !=
            PackageManager.PERMISSION_GRANTED
        ) return LiveSmsLoad.AccessDenied

        val projection = arrayOf(
            Telephony.Sms._ID,
            Telephony.Sms.THREAD_ID,
            Telephony.Sms.ADDRESS,
            Telephony.Sms.BODY,
            Telephony.Sms.DATE,
            Telephony.Sms.TYPE,
            Telephony.Sms.READ,
        )
        return try {
            val cursor = context.contentResolver.query(
                Telephony.Sms.CONTENT_URI, projection, null, null, Telephony.Sms.DATE + " DESC",
            ) ?: return LiveSmsLoad.Unavailable
            val rows = cursor.use {
                val id = it.getColumnIndexOrThrow(Telephony.Sms._ID)
                val thread = it.getColumnIndexOrThrow(Telephony.Sms.THREAD_ID)
                val address = it.getColumnIndexOrThrow(Telephony.Sms.ADDRESS)
                val body = it.getColumnIndexOrThrow(Telephony.Sms.BODY)
                val date = it.getColumnIndexOrThrow(Telephony.Sms.DATE)
                val type = it.getColumnIndexOrThrow(Telephony.Sms.TYPE)
                val read = it.getColumnIndexOrThrow(Telephony.Sms.READ)
                buildList {
                    while (size < ProviderSmsConversationMapper.MAX_MESSAGES && it.moveToNext()) {
                        val messageType = it.getInt(type)
                        if (messageType != Telephony.Sms.MESSAGE_TYPE_INBOX &&
                            messageType != Telephony.Sms.MESSAGE_TYPE_SENT
                        ) continue
                        add(
                            ProviderSmsRow(
                                id = it.getLong(id),
                                threadId = it.getLong(thread),
                                address = it.getString(address).orEmpty(),
                                body = it.getString(body).orEmpty(),
                                dateMillis = it.getLong(date),
                                incoming = messageType == Telephony.Sms.MESSAGE_TYPE_INBOX,
                                read = it.getInt(read) != 0,
                            ),
                        )
                    }
                }
            }
            LiveSmsLoad.Ready(ProviderSmsConversationMapper.map(rows))
        } catch (_: SecurityException) {
            LiveSmsLoad.AccessDenied
        } catch (_: RuntimeException) {
            LiveSmsLoad.Unavailable
        }
    }
}
