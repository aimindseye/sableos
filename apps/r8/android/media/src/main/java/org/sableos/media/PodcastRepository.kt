package org.sableos.media

import android.content.Context
import android.text.Html
import android.util.Xml
import org.json.JSONArray
import org.json.JSONObject
import org.xmlpull.v1.XmlPullParser
import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.net.HttpURLConnection
import java.net.URL
import java.nio.charset.StandardCharsets
import java.text.SimpleDateFormat
import java.util.Locale
import java.util.TimeZone
import java.util.UUID

internal data class PodcastEpisode(
    val id: String,
    val podcastId: String,
    val podcastTitle: String,
    val title: String,
    val mediaUrl: String,
    val description: String,
    val publishedAt: Long,
    val durationMs: Long,
)

internal data class PodcastSubscription(
    val id: String,
    val feedUrl: String,
    val title: String,
    val author: String,
    val description: String,
    val episodes: List<PodcastEpisode>,
    val refreshedAt: Long,
)

internal data class PodcastRefreshResult(
    val subscriptions: List<PodcastSubscription>,
    val failedFeeds: Int,
)

internal class PodcastRepository(
    context: Context,
) {
    private val preferences =
        context.getSharedPreferences(
            "sable_media_podcasts",
            Context.MODE_PRIVATE,
        )

    fun loadSubscriptions(): List<PodcastSubscription> {
        val raw = preferences.getString(KEY_SUBSCRIPTIONS, null) ?: return emptyList()

        return runCatching {
            val array = JSONArray(raw)
            buildList {
                for (index in 0 until array.length()) {
                    val item = array.optJSONObject(index) ?: continue
                    decodeSubscription(item)?.let(::add)
                }
            }.sortedBy { it.title.lowercase(Locale.getDefault()) }
        }.getOrDefault(emptyList())
    }

    fun subscribe(
        current: List<PodcastSubscription>,
        feedUrl: String,
    ): List<PodcastSubscription> {
        val normalized = normalizeFeedUrl(feedUrl)
        require(isSupportedFeedUrl(normalized)) {
            "Podcast feed must use HTTP or HTTPS."
        }

        val fetched = fetch(normalized)
        val updated =
            (
                current.filterNot {
                    it.feedUrl.equals(normalized, ignoreCase = true)
                } + fetched
            ).sortedBy { it.title.lowercase(Locale.getDefault()) }

        persist(updated)
        return updated
    }

    fun refreshAll(
        current: List<PodcastSubscription>,
    ): PodcastRefreshResult {
        if (current.isEmpty()) {
            return PodcastRefreshResult(
                subscriptions = emptyList(),
                failedFeeds = 0,
            )
        }

        var failures = 0
        val refreshed =
            current.map { subscription ->
                runCatching {
                    fetch(subscription.feedUrl)
                }.getOrElse {
                    failures += 1
                    subscription
                }
            }.sortedBy { it.title.lowercase(Locale.getDefault()) }

        persist(refreshed)
        return PodcastRefreshResult(
            subscriptions = refreshed,
            failedFeeds = failures,
        )
    }

    fun remove(
        current: List<PodcastSubscription>,
        podcastId: String,
    ): List<PodcastSubscription> {
        val updated = current.filterNot { it.id == podcastId }
        persist(updated)
        return updated
    }

    private fun fetch(feedUrl: String): PodcastSubscription {
        val connection =
            (URL(feedUrl).openConnection() as HttpURLConnection).apply {
                connectTimeout = CONNECT_TIMEOUT_MS
                readTimeout = READ_TIMEOUT_MS
                instanceFollowRedirects = true
                requestMethod = "GET"
                setRequestProperty(
                    "Accept",
                    "application/rss+xml, application/atom+xml, application/xml, text/xml;q=0.9, */*;q=0.1",
                )
                setRequestProperty("User-Agent", USER_AGENT)
            }

        try {
            val status = connection.responseCode
            require(status in 200..299) {
                "Podcast feed returned HTTP $status."
            }

            val resolvedFeedUrl =
                connection.url
                    ?.toString()
                    ?.takeIf { it.isNotBlank() }
                    ?: feedUrl
            require(isSupportedFeedUrl(resolvedFeedUrl)) {
                "Podcast feed redirected to an unsupported URL."
            }

            val bytes =
                connection.inputStream.use { input ->
                    readLimited(input)
                }

            return parseFeed(
                feedUrl = resolvedFeedUrl,
                bytes = bytes,
            )
        } finally {
            connection.disconnect()
        }
    }

    private fun readLimited(
        input: java.io.InputStream,
    ): ByteArray {
        val output = ByteArrayOutputStream()
        val buffer = ByteArray(16 * 1024)
        var total = 0

        while (true) {
            val read = input.read(buffer)
            if (read < 0) break

            total += read
            require(total <= MAX_FEED_BYTES) {
                "Podcast feed is larger than the Sable Media safety limit."
            }
            output.write(buffer, 0, read)
        }

        return output.toByteArray()
    }

    private fun parseFeed(
        feedUrl: String,
        bytes: ByteArray,
    ): PodcastSubscription {
        val parser = Xml.newPullParser()
        parser.setFeature(XmlPullParser.FEATURE_PROCESS_NAMESPACES, false)
        val prolog =
            String(
                bytes,
                0,
                minOf(bytes.size, 4_096),
                StandardCharsets.ISO_8859_1,
            )
        require(!prolog.contains("<!DOCTYPE", ignoreCase = true)) {
            "Podcast feed document types are not accepted."
        }

        parser.setInput(
            ByteArrayInputStream(bytes),
            null,
        )

        val podcastId = stableId(feedUrl)
        var feedTitle = ""
        var feedAuthor = ""
        var feedDescription = ""
        var inEntry = false
        var currentTag = ""
        var current: EpisodeBuilder? = null
        val episodes = mutableListOf<PodcastEpisode>()

        while (parser.eventType != XmlPullParser.END_DOCUMENT) {
            when (parser.eventType) {
                XmlPullParser.START_TAG -> {
                    val tag = localName(parser.name)
                    currentTag = tag

                    if (tag == "item" || tag == "entry") {
                        inEntry = true
                        current = EpisodeBuilder()
                    } else if (inEntry && (tag == "enclosure" || tag == "content")) {
                        val candidate =
                            attribute(parser, "url")
                                .orEmpty()
                                .trim()
                        val type =
                            attribute(parser, "type")
                                .orEmpty()
                                .lowercase(Locale.US)

                        if (
                            candidate.isNotBlank() &&
                            (type.isBlank() || type.startsWith("audio/"))
                        ) {
                            current?.mediaUrl = candidate
                        }
                    } else if (inEntry && tag == "link") {
                        val rel =
                            attribute(parser, "rel")
                                .orEmpty()
                                .lowercase(Locale.US)
                        val href =
                            attribute(parser, "href")
                                .orEmpty()
                                .trim()
                        val type =
                            attribute(parser, "type")
                                .orEmpty()
                                .lowercase(Locale.US)

                        if (
                            href.isNotBlank() &&
                            rel == "enclosure" &&
                            (type.isBlank() || type.startsWith("audio/"))
                        ) {
                            current?.mediaUrl = href
                        }
                    }
                }

                XmlPullParser.TEXT,
                XmlPullParser.CDSECT,
                -> {
                    val value = parser.text?.trim().orEmpty()
                    if (value.isNotBlank()) {
                        if (inEntry) {
                            when (currentTag) {
                                "title" -> current?.title = appendText(current?.title, value)
                                "guid", "id" -> current?.guid = appendText(current?.guid, value)
                                "pubdate", "published", "updated" ->
                                    current?.published = appendText(current?.published, value)
                                "description", "summary", "encoded" ->
                                    current?.description = appendText(current?.description, value)
                                "duration" ->
                                    current?.duration = appendText(current?.duration, value)
                            }
                        } else {
                            when (currentTag) {
                                "title" ->
                                    if (feedTitle.isBlank()) {
                                        feedTitle = value
                                    }

                                "author", "creator", "name" ->
                                    if (feedAuthor.isBlank()) {
                                        feedAuthor = value
                                    }

                                "description", "subtitle" ->
                                    if (feedDescription.isBlank()) {
                                        feedDescription = value
                                    }
                            }
                        }
                    }
                }

                XmlPullParser.END_TAG -> {
                    val tag = localName(parser.name)
                    if (tag == "item" || tag == "entry") {
                        current
                            ?.toEpisode(
                                podcastId = podcastId,
                                podcastTitle =
                                    cleanText(feedTitle)
                                        .ifBlank { "Podcast" },
                            )
                            ?.let(episodes::add)
                        current = null
                        inEntry = false
                    }
                    currentTag = ""
                }
            }

            parser.next()
        }

        val normalizedTitle =
            cleanText(feedTitle)
                .ifBlank {
                    URL(feedUrl).host
                        ?.removePrefix("www.")
                        ?.takeIf { it.isNotBlank() }
                        ?: "Podcast"
                }

        val normalizedEpisodes =
            episodes
                .map { episode ->
                    episode.copy(
                        podcastTitle = normalizedTitle,
                    )
                }
                .distinctBy { it.id }
                .sortedWith(
                    compareByDescending<PodcastEpisode> { it.publishedAt }
                        .thenBy { it.title.lowercase(Locale.getDefault()) },
                )
                .take(MAX_EPISODES_PER_FEED)

        require(normalizedEpisodes.isNotEmpty()) {
            "No playable audio episodes were found in this feed."
        }

        return PodcastSubscription(
            id = podcastId,
            feedUrl = feedUrl,
            title = normalizedTitle,
            author = cleanText(feedAuthor),
            description = cleanText(feedDescription),
            episodes = normalizedEpisodes,
            refreshedAt = System.currentTimeMillis(),
        )
    }

    private fun persist(
        subscriptions: List<PodcastSubscription>,
    ) {
        val array = JSONArray()

        subscriptions.forEach { subscription ->
            val episodes = JSONArray()
            subscription.episodes.forEach { episode ->
                episodes.put(
                    JSONObject()
                        .put("id", episode.id)
                        .put("podcastId", episode.podcastId)
                        .put("podcastTitle", episode.podcastTitle)
                        .put("title", episode.title)
                        .put("mediaUrl", episode.mediaUrl)
                        .put("description", episode.description)
                        .put("publishedAt", episode.publishedAt)
                        .put("durationMs", episode.durationMs),
                )
            }

            array.put(
                JSONObject()
                    .put("id", subscription.id)
                    .put("feedUrl", subscription.feedUrl)
                    .put("title", subscription.title)
                    .put("author", subscription.author)
                    .put("description", subscription.description)
                    .put("refreshedAt", subscription.refreshedAt)
                    .put("episodes", episodes),
            )
        }

        preferences
            .edit()
            .putString(KEY_SUBSCRIPTIONS, array.toString())
            .apply()
    }

    private fun decodeSubscription(
        item: JSONObject,
    ): PodcastSubscription? {
        val id = item.optString("id")
        val feedUrl = item.optString("feedUrl")
        val title = item.optString("title")

        if (
            id.isBlank() ||
            !isSupportedFeedUrl(feedUrl) ||
            title.isBlank()
        ) {
            return null
        }

        val episodesArray = item.optJSONArray("episodes") ?: JSONArray()
        val episodes =
            buildList {
                for (index in 0 until episodesArray.length()) {
                    val episode = episodesArray.optJSONObject(index) ?: continue
                    val episodeId = episode.optString("id")
                    val mediaUrl = episode.optString("mediaUrl")
                    val episodeTitle = episode.optString("title")

                    if (
                        episodeId.isBlank() ||
                        mediaUrl.isBlank() ||
                        episodeTitle.isBlank()
                    ) {
                        continue
                    }

                    add(
                        PodcastEpisode(
                            id = episodeId,
                            podcastId = id,
                            podcastTitle =
                                episode.optString("podcastTitle")
                                    .ifBlank { title },
                            title = episodeTitle,
                            mediaUrl = mediaUrl,
                            description = episode.optString("description"),
                            publishedAt = episode.optLong("publishedAt", 0L),
                            durationMs = episode.optLong("durationMs", 0L),
                        ),
                    )
                }
            }

        return PodcastSubscription(
            id = id,
            feedUrl = feedUrl,
            title = title,
            author = item.optString("author"),
            description = item.optString("description"),
            episodes = episodes,
            refreshedAt = item.optLong("refreshedAt", 0L),
        )
    }

    private fun normalizeFeedUrl(value: String): String = value.trim()

    private data class EpisodeBuilder(
        var title: String = "",
        var guid: String = "",
        var mediaUrl: String = "",
        var description: String = "",
        var published: String = "",
        var duration: String = "",
    ) {
        fun toEpisode(
            podcastId: String,
            podcastTitle: String,
        ): PodcastEpisode? {
            val playableUrl = mediaUrl.trim()
            if (!isSupportedMediaUrl(playableUrl)) return null

            val normalizedTitle =
                cleanText(title)
                    .ifBlank { "Untitled episode" }
            val publishedAt = parsePublishedAt(published)
            val stableEpisodeKey =
                guid.trim()
                    .ifBlank { playableUrl }
                    .ifBlank { "$normalizedTitle:$publishedAt" }

            return PodcastEpisode(
                id = stableId("$podcastId:$stableEpisodeKey"),
                podcastId = podcastId,
                podcastTitle = podcastTitle,
                title = normalizedTitle,
                mediaUrl = playableUrl,
                description = cleanText(description),
                publishedAt = publishedAt,
                durationMs = parseDurationMs(duration),
            )
        }
    }

    companion object {
        private const val KEY_SUBSCRIPTIONS = "subscriptions"
        private const val USER_AGENT = "SableMedia/0.2 (Android; privacy-first podcast client)"
        private const val CONNECT_TIMEOUT_MS = 12_000
        private const val READ_TIMEOUT_MS = 20_000
        private const val MAX_FEED_BYTES = 4 * 1024 * 1024
        private const val MAX_EPISODES_PER_FEED = 200

        fun isSupportedFeedUrl(value: String): Boolean {
            val normalized = value.trim()
            val protocol =
                runCatching {
                    URL(normalized).protocol.lowercase(Locale.US)
                }.getOrNull()
            return protocol == "http" || protocol == "https"
        }

        private fun isSupportedMediaUrl(value: String): Boolean {
            val protocol =
                runCatching {
                    URL(value.trim()).protocol.lowercase(Locale.US)
                }.getOrNull()
            return protocol == "http" || protocol == "https"
        }

        private fun attribute(
            parser: XmlPullParser,
            name: String,
        ): String? {
            for (index in 0 until parser.attributeCount) {
                if (localName(parser.getAttributeName(index)) == name) {
                    return parser.getAttributeValue(index)
                }
            }
            return null
        }

        private fun localName(value: String?): String =
            value
                .orEmpty()
                .substringAfterLast(':')
                .lowercase(Locale.US)

        private fun appendText(
            existing: String?,
            value: String,
        ): String =
            if (existing.isNullOrBlank()) {
                value
            } else {
                "$existing $value"
            }

        private fun cleanText(value: String): String =
            Html.fromHtml(
                value,
                Html.FROM_HTML_MODE_LEGACY,
            ).toString()
                .replace(Regex("\\s+"), " ")
                .trim()
                .take(4_000)

        private fun parsePublishedAt(value: String): Long {
            val candidate = value.trim()
            if (candidate.isBlank()) return 0L

            val patterns =
                listOf(
                    "EEE, dd MMM yyyy HH:mm:ss Z",
                    "EEE, dd MMM yyyy HH:mm Z",
                    "yyyy-MM-dd'T'HH:mm:ssXXX",
                    "yyyy-MM-dd'T'HH:mm:ss'Z'",
                    "yyyy-MM-dd",
                )

            patterns.forEach { pattern ->
                val parsed =
                    runCatching {
                        SimpleDateFormat(
                            pattern,
                            Locale.US,
                        ).apply {
                            isLenient = true
                            timeZone = TimeZone.getTimeZone("UTC")
                        }.parse(candidate)
                    }.getOrNull()

                if (parsed != null) {
                    return parsed.time
                }
            }

            return 0L
        }

        private fun parseDurationMs(value: String): Long {
            val candidate = value.trim()
            if (candidate.isBlank()) return 0L

            candidate.toLongOrNull()?.let { seconds ->
                return seconds.coerceAtLeast(0L) * 1_000L
            }

            val parts =
                candidate
                    .split(':')
                    .mapNotNull { it.toLongOrNull() }

            if (parts.isEmpty()) return 0L

            val seconds =
                when (parts.size) {
                    3 -> parts[0] * 3_600L + parts[1] * 60L + parts[2]
                    2 -> parts[0] * 60L + parts[1]
                    1 -> parts[0]
                    else -> 0L
                }

            return seconds.coerceAtLeast(0L) * 1_000L
        }

        private fun stableId(value: String): String =
            UUID.nameUUIDFromBytes(
                value.toByteArray(StandardCharsets.UTF_8),
            ).toString()
    }
}

internal class PodcastStateRepository(
    context: Context,
) {
    private val preferences =
        context.getSharedPreferences(
            "sable_media_podcast_state",
            Context.MODE_PRIVATE,
        )

    fun loadSavedEpisodeIds(): Set<String> =
        preferences
            .getStringSet(KEY_SAVED, emptySet())
            ?.toSet()
            .orEmpty()

    fun loadPlayedEpisodeIds(): Set<String> =
        preferences
            .getStringSet(KEY_PLAYED, emptySet())
            ?.toSet()
            .orEmpty()

    fun toggleSaved(
        current: Set<String>,
        episodeId: String,
    ): Set<String> {
        val updated =
            current.toMutableSet().apply {
                if (!add(episodeId)) {
                    remove(episodeId)
                }
            }.toSet()

        preferences
            .edit()
            .putStringSet(KEY_SAVED, updated)
            .apply()

        return updated
    }

    fun markPlayed(
        current: Set<String>,
        episodeId: String,
    ): Set<String> {
        if (episodeId in current) return current

        val updated = current + episodeId
        preferences
            .edit()
            .putStringSet(KEY_PLAYED, updated)
            .apply()
        return updated
    }

    companion object {
        private const val KEY_SAVED = "saved_episode_ids"
        private const val KEY_PLAYED = "played_episode_ids"
    }
}
