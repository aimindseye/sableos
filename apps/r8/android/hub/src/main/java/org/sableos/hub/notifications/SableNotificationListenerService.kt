package org.sableos.hub.notifications

import android.app.Notification
import android.database.ContentObserver
import android.os.Handler
import android.os.Looper
import android.os.UserManager
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.sableos.hub.ConnectedAppKey
import org.sableos.hub.ConnectedAppPolicy
import org.sableos.hub.ConnectedAppsInventory
import org.sableos.hub.ConnectedAppsRepository
import org.sableos.hub.ConnectedNotificationHistoryStore
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.atomic.AtomicLong

class SableNotificationListenerService : NotificationListenerService() {
    private val workerScope =
        CoroutineScope(
            SupervisorJob() + Dispatchers.Default,
        )

    private lateinit var policies: ConnectedAppsRepository
    private lateinit var history: ConnectedNotificationHistoryStore
    private lateinit var normalizer: ConnectedNotificationNormalizer
    private lateinit var userManager: UserManager
    private val generationCounter = AtomicLong(0L)
    private val notificationGenerations = ConcurrentHashMap<String, Long>()

    private val policyObserver =
        object : ContentObserver(Handler(Looper.getMainLooper())) {
            override fun onChange(selfChange: Boolean) {
                refreshPoliciesAndReprocess()
            }
        }

    override fun onCreate() {
        super.onCreate()
        policies = ConnectedAppsRepository(applicationContext)
        history = ConnectedNotificationHistoryStore(applicationContext)
        normalizer =
            ConnectedNotificationNormalizer(
                inventory = ConnectedAppsInventory(applicationContext),
            )
        userManager =
            checkNotNull(
                applicationContext.getSystemService(UserManager::class.java),
            )

        contentResolver.registerContentObserver(
            ConnectedAppsRepository.POLICY_URI,
            false,
            policyObserver,
        )
        workerScope.launch(Dispatchers.IO) {
            policies.loadPolicies()
        }
    }

    override fun onListenerConnected() {
        super.onListenerConnected()
        refreshPoliciesAndReprocess()
    }

    override fun onNotificationPosted(sbn: StatusBarNotification) {
        val envelope = eligibleEnvelope(sbn)
        if (envelope != null) {
            val generation = generationCounter.incrementAndGet()
            notificationGenerations[sbn.key] = generation
            workerScope.launch {
                processEnvelope(
                    envelope = envelope,
                    generation = generation,
                )
            }
        }
    }

    private fun eligibleEnvelope(
        sbn: StatusBarNotification,
    ): ConnectedNotificationEnvelope? {
        val userSerial = userManager.getSerialNumberForUser(sbn.user)
        val key =
            userSerial
                .takeIf { it >= 0L }
                ?.let { serial ->
                    ConnectedAppKey(
                        packageName = sbn.packageName,
                        userSerial = serial,
                    )
                }
        val policy =
            key?.let(policies::cachedPolicyFor)

        if (key == null || policy?.includeInMessages != true) {
            ConnectedReplyRegistry.remove(sbn.key)
        }

        return if (key == null || policy?.includeInMessages != true) {
            null
        } else {
            captureEnvelope(
                sbn = sbn,
                key = key,
                policy = policy,
            )
        }
    }

    private fun captureEnvelope(
        sbn: StatusBarNotification,
        key: ConnectedAppKey,
        policy: ConnectedAppPolicy,
    ): ConnectedNotificationEnvelope {
        val notification = sbn.notification
        return ConnectedNotificationEnvelope(
            key = key,
            notificationKey = sbn.key,
            notificationId = sbn.id,
            notificationTag =
                boundedText(
                    sbn.tag,
                    MAX_NOTIFICATION_ID_LENGTH,
                ),
            shortcutId =
                boundedText(
                    notification.shortcutId,
                    MAX_NOTIFICATION_ID_LENGTH,
                ),
            postTimeMillis = sbn.postTime,
            notificationTitle =
                boundedText(
                    notification.extras
                        .getCharSequence(Notification.EXTRA_TITLE)
                        ?.toString(),
                    MAX_NOTIFICATION_LABEL_LENGTH,
                ),
            notificationBody =
                boundedText(
                    notification.extras
                        .getCharSequence(Notification.EXTRA_BIG_TEXT)
                        ?.toString(),
                    MAX_NOTIFICATION_BODY_LENGTH,
                ) ?: boundedText(
                    notification.extras
                        .getCharSequence(Notification.EXTRA_TEXT)
                        ?.toString(),
                    MAX_NOTIFICATION_BODY_LENGTH,
                ),
            conversationTitle =
                boundedText(
                    notification.extras
                        .getCharSequence(Notification.EXTRA_CONVERSATION_TITLE)
                        ?.toString(),
                    MAX_NOTIFICATION_LABEL_LENGTH,
                ),
            messages =
                captureMessages(
                    notification = notification,
                    fallbackTimestampMillis = sbn.postTime,
                ),
            replyCandidate = captureReplyCandidate(notification),
            allowQuickReply = policy.allowQuickReply,
        )
    }

    @Suppress("DEPRECATION")
    private fun captureMessages(
        notification: Notification,
        fallbackTimestampMillis: Long,
    ): List<ConnectedNotificationMessageSnapshot> {
        val bundles =
            notification.extras
                .getParcelableArray(
                    Notification.EXTRA_MESSAGES,
                )
                ?.takeLast(MAX_NOTIFICATION_MESSAGES)
                ?.toTypedArray()
        return Notification.MessagingStyle.Message
            .getMessagesFromBundleArray(bundles)
            .map { message ->
                ConnectedNotificationMessageSnapshot(
                    senderLabel =
                        boundedText(
                            message.senderPerson
                                ?.name
                                ?.toString(),
                            MAX_NOTIFICATION_LABEL_LENGTH,
                        ),
                    body =
                        boundedText(
                            message.text
                                ?.toString(),
                            MAX_NOTIFICATION_BODY_LENGTH,
                        ),
                    timestampMillis =
                        message.timestamp
                            .takeIf { it > 0L }
                            ?: fallbackTimestampMillis,
                    incoming = message.senderPerson != null,
                )
            }
    }

    private fun captureReplyCandidate(
        notification: Notification,
    ): ConnectedNotificationReplyCandidate? {
        val candidates =
            notification.actions
                .orEmpty()
                .asSequence()
                .take(MAX_NOTIFICATION_ACTIONS)
                .mapNotNull { action ->
                    val pendingIntent = action.actionIntent
                    val remoteInput =
                        action.remoteInputs
                            ?.asSequence()
                            ?.take(MAX_NOTIFICATION_REMOTE_INPUTS)
                            ?.firstOrNull { input ->
                                input.allowFreeFormInput
                            }
                    if (pendingIntent == null || remoteInput == null) {
                        null
                    } else {
                        CapturedReplyCandidate(
                            candidate =
                                ConnectedNotificationReplyCandidate(
                                    pendingIntent = pendingIntent,
                                    remoteInput = remoteInput,
                                ),
                            semanticAction = action.semanticAction,
                        )
                    }
                }.toList()

        return candidates
            .firstOrNull { candidate ->
                candidate.semanticAction == Notification.Action.SEMANTIC_ACTION_REPLY
            }?.candidate
            ?: candidates.firstOrNull()?.candidate
    }

    private suspend fun processEnvelope(
        envelope: ConnectedNotificationEnvelope,
        generation: Long,
    ) {
        val latestPolicy = policies.cachedPolicyFor(envelope.key)?.normalized()
        if (latestPolicy?.includeInMessages != true) {
            ConnectedReplyRegistry.remove(envelope.notificationKey)
            return
        }

        val normalized =
            normalizer.normalize(
                envelope.copy(
                    allowQuickReply = latestPolicy.allowQuickReply,
                ),
            )

        if (notificationGenerations[envelope.notificationKey] != generation) {
            return
        }

        ConnectedReplyRegistry.remove(envelope.notificationKey)
        ConnectedReplyRegistry.register(normalized.replyHandle)

        val policySnapshot = policies.cachedPolicySnapshot()
        withContext(Dispatchers.IO) {
            history.merge(
                records = normalized.records,
                policies = policySnapshot,
            )
        }
    }

    private fun refreshPoliciesAndReprocess() {
        workerScope.launch(Dispatchers.IO) {
            policies.loadPolicies()
            withContext(Dispatchers.Main.immediate) {
                activeNotifications
                    .orEmpty()
                    .forEach(::onNotificationPosted)
            }
        }
    }

    override fun onNotificationRemoved(sbn: StatusBarNotification) {
        notificationGenerations.remove(sbn.key)
        ConnectedReplyRegistry.remove(sbn.key)
        applicationContext.contentResolver.notifyChange(
            ConnectedAppsRepository.HISTORY_URI,
            null,
        )
    }

    override fun onDestroy() {
        runCatching {
            contentResolver.unregisterContentObserver(policyObserver)
        }
        workerScope.cancel()
        super.onDestroy()
    }

    private fun boundedText(
        value: String?,
        maxLength: Int,
    ): String? =
        value
            ?.trim()
            ?.takeIf { it.isNotEmpty() }
            ?.take(maxLength)

    private data class CapturedReplyCandidate(
        val candidate: ConnectedNotificationReplyCandidate,
        val semanticAction: Int,
    )
}
