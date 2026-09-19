package org.sableos.media

import android.content.Context
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.provider.OpenableColumns
import org.json.JSONArray
import org.json.JSONObject

internal data class LocalAudioItem(
    val uri: String,
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

        return runCatching {
            val array = JSONArray(raw)
            buildList {
                for (index in 0 until array.length()) {
                    val item = array.optJSONObject(index) ?: continue
                    val uri = item.optString("uri")
                    val title = item.optString("title")

                    if (uri.isBlank() || title.isBlank()) continue

                    add(
                        LocalAudioItem(
                            uri = uri,
                            title = title,
                            artist = item.optString("artist", "Unknown artist"),
                            album = item.optString("album", "Local audio"),
                            durationMs = item.optLong("durationMs", 0L),
                        ),
                    )
                }
            }
        }.getOrDefault(emptyList())
    }

    fun addUris(
        current: List<LocalAudioItem>,
        uris: List<Uri>,
    ): List<LocalAudioItem> {
        val byUri = current.associateBy { it.uri }.toMutableMap()

        uris.forEach { uri ->
            val item = inspect(uri)
            byUri[item.uri] = item
        }

        val updated =
            byUri.values
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

        context.contentResolver
            .query(
                uri,
                arrayOf(OpenableColumns.DISPLAY_NAME),
                null,
                null,
                null,
            )
            ?.use { cursor ->
                if (cursor.moveToFirst()) {
                    val index = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                    if (index >= 0) {
                        fallbackName = cursor.getString(index)?.ifBlank { fallbackName }
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
                title = title,
                artist = artist,
                album = album,
                durationMs = duration,
            )
        } catch (_: RuntimeException) {
            LocalAudioItem(
                uri = uri.toString(),
                title = fallbackName ?: "Local audio",
                artist = "Unknown artist",
                album = "Local audio",
                durationMs = 0L,
            )
        } finally {
            runCatching { retriever.release() }
        }
    }

    private fun persist(items: List<LocalAudioItem>) {
        val array = JSONArray()

        items.forEach { item ->
            array.put(
                JSONObject()
                    .put("uri", item.uri)
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
