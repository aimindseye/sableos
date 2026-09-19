package org.sableos.media

import android.content.Context
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.provider.DocumentsContract
import android.provider.OpenableColumns
import org.json.JSONArray
import org.json.JSONObject

internal data class LocalAudioItem(
    val uri: String,
    val sourceKey: String,
    val title: String,
    val artist: String,
    val album: String,
    val durationMs: Long,
)

internal class LocalAudioRepository(
    private val context: Context,
) {
    private val preferences =
        context.getSharedPreferences(
            "sable_media",
            Context.MODE_PRIVATE,
        )

    fun loadItems(): List<LocalAudioItem> {
        val raw = preferences.getString(KEY_LOCAL_AUDIO, null) ?: return emptyList()

        val decoded =
            runCatching {
                val array = JSONArray(raw)
                buildList {
                    for (index in 0 until array.length()) {
                        val item = array.optJSONObject(index) ?: continue
                        val uri = item.optString("uri")
                        val title = item.optString("title")

                        if (uri.isBlank() || title.isBlank()) continue

                        val parsedUri = Uri.parse(uri)
                        val sourceKey =
                            item.optString("sourceKey")
                                .takeIf { it.isNotBlank() }
                                ?: sourceKeyFor(
                                    uri = parsedUri,
                                    fallbackName = title,
                                    fallbackSize = -1L,
                                    durationMs = item.optLong("durationMs", 0L),
                                )

                        add(
                            LocalAudioItem(
                                uri = uri,
                                sourceKey = sourceKey,
                                title = title,
                                artist = item.optString("artist", "Unknown artist"),
                                album = item.optString("album", "Local audio"),
                                durationMs = item.optLong("durationMs", 0L),
                            ),
                        )
                    }
                }
            }.getOrDefault(emptyList())

        val deduplicated =
            decoded
                .distinctBy { it.sourceKey }
                .sortedBy { it.title.lowercase() }

        if (deduplicated != decoded) {
            persist(deduplicated)
        }

        return deduplicated
    }

    fun addUris(
        current: List<LocalAudioItem>,
        uris: List<Uri>,
    ): List<LocalAudioItem> {
        val bySource =
            current
                .associateBy { it.sourceKey }
                .toMutableMap()

        uris.forEach { uri ->
            val item = inspect(uri)

            // Keep the first persisted URI for the same physical document. This
            // preserves existing favorites/playlists when the same file is later
            // encountered through a tree URI or another picker path.
            if (item.sourceKey !in bySource) {
                bySource[item.sourceKey] = item
            }
        }

        val updated =
            bySource.values
                .sortedBy { it.title.lowercase() }

        persist(updated)
        return updated
    }

    fun remove(
        current: List<LocalAudioItem>,
        uri: String,
    ): List<LocalAudioItem> {
        val updated = current.filterNot { it.uri == uri }
        persist(updated)
        return updated
    }

    private fun inspect(uri: Uri): LocalAudioItem {
        var fallbackName =
            uri.lastPathSegment
                ?.substringAfterLast('/')
                ?.ifBlank { null }
        var size = -1L

        context.contentResolver
            .query(
                uri,
                arrayOf(
                    OpenableColumns.DISPLAY_NAME,
                    OpenableColumns.SIZE,
                ),
                null,
                null,
                null,
            )
            ?.use { cursor ->
                if (cursor.moveToFirst()) {
                    val nameIndex = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                    if (nameIndex >= 0) {
                        fallbackName =
                            cursor.getString(nameIndex)
                                ?.ifBlank { fallbackName }
                    }

                    val sizeIndex = cursor.getColumnIndex(OpenableColumns.SIZE)
                    if (sizeIndex >= 0 && !cursor.isNull(sizeIndex)) {
                        size = cursor.getLong(sizeIndex)
                    }
                }
            }

        val retriever = MediaMetadataRetriever()

        return try {
            retriever.setDataSource(context, uri)

            val title =
                retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_TITLE)
                    ?.trim()
                    ?.takeIf { it.isNotBlank() }
                    ?: fallbackName
                    ?: "Local audio"

            val artist =
                retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_ARTIST)
                    ?.trim()
                    ?.takeIf { it.isNotBlank() }
                    ?: "Unknown artist"

            val album =
                retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_ALBUM)
                    ?.trim()
                    ?.takeIf { it.isNotBlank() }
                    ?: "Local audio"

            val duration =
                retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)
                    ?.toLongOrNull()
                    ?: 0L

            LocalAudioItem(
                uri = uri.toString(),
                sourceKey =
                    sourceKeyFor(
                        uri = uri,
                        fallbackName = fallbackName ?: title,
                        fallbackSize = size,
                        durationMs = duration,
                    ),
                title = title,
                artist = artist,
                album = album,
                durationMs = duration,
            )
        } catch (_: RuntimeException) {
            val title = fallbackName ?: "Local audio"

            LocalAudioItem(
                uri = uri.toString(),
                sourceKey =
                    sourceKeyFor(
                        uri = uri,
                        fallbackName = title,
                        fallbackSize = size,
                        durationMs = 0L,
                    ),
                title = title,
                artist = "Unknown artist",
                album = "Local audio",
                durationMs = 0L,
            )
        } finally {
            runCatching { retriever.release() }
        }
    }

    private fun sourceKeyFor(
        uri: Uri,
        fallbackName: String,
        fallbackSize: Long,
        durationMs: Long,
    ): String {
        val documentId =
            runCatching {
                DocumentsContract.getDocumentId(uri)
            }.getOrNull()

        if (!documentId.isNullOrBlank()) {
            return "document:${uri.authority.orEmpty()}:$documentId"
        }

        return buildString {
            append("fallback:")
            append(uri.authority.orEmpty())
            append(':')
            append(fallbackName.lowercase())
            append(':')
            append(fallbackSize)
            append(':')
            append(durationMs)
        }
    }

    private fun persist(items: List<LocalAudioItem>) {
        val array = JSONArray()

        items.forEach { item ->
            array.put(
                JSONObject()
                    .put("uri", item.uri)
                    .put("sourceKey", item.sourceKey)
                    .put("title", item.title)
                    .put("artist", item.artist)
                    .put("album", item.album)
                    .put("durationMs", item.durationMs),
            )
        }

        preferences
            .edit()
            .putString(KEY_LOCAL_AUDIO, array.toString())
            .apply()
    }

    companion object {
        private const val KEY_LOCAL_AUDIO = "local_audio_items"
    }
}
