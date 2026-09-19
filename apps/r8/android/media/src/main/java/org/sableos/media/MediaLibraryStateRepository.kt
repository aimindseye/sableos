package org.sableos.media

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject
import java.util.UUID

internal data class MediaPlaylist(
    val id: String,
    val name: String,
    val itemUris: List<String>,
)

internal class MediaLibraryStateRepository(
    context: Context,
) {
    private val preferences =
        context.getSharedPreferences(
            "sable_media",
            Context.MODE_PRIVATE,
        )

    fun loadFavoriteAudioUris(): Set<String> =
        preferences
            .getStringSet(KEY_FAVORITE_AUDIO, emptySet())
            ?.toSet()
            .orEmpty()

    fun toggleFavoriteAudio(
        current: Set<String>,
        uri: String,
    ): Set<String> {
        val updated =
            current.toMutableSet().apply {
                if (!add(uri)) {
                    remove(uri)
                }
            }.toSet()

        preferences
            .edit()
            .putStringSet(KEY_FAVORITE_AUDIO, updated)
            .apply()

        return updated
    }

    fun loadFavoriteStationIds(): Set<String> =
        preferences
            .getStringSet(KEY_FAVORITE_STATIONS, emptySet())
            ?.toSet()
            .orEmpty()

    fun toggleFavoriteStation(
        current: Set<String>,
        stationId: String,
    ): Set<String> {
        val updated =
            current.toMutableSet().apply {
                if (!add(stationId)) {
                    remove(stationId)
                }
            }.toSet()

        preferences
            .edit()
            .putStringSet(KEY_FAVORITE_STATIONS, updated)
            .apply()

        return updated
    }

    fun loadPlaylists(): List<MediaPlaylist> {
        val raw = preferences.getString(KEY_PLAYLISTS, null) ?: return emptyList()

        return runCatching {
            val array = JSONArray(raw)

            buildList {
                for (index in 0 until array.length()) {
                    val item = array.optJSONObject(index) ?: continue
                    val id = item.optString("id")
                    val name = item.optString("name")
                    val urisArray = item.optJSONArray("itemUris") ?: JSONArray()

                    if (id.isBlank() || name.isBlank()) continue

                    val uris =
                        buildList {
                            for (uriIndex in 0 until urisArray.length()) {
                                val uri = urisArray.optString(uriIndex)
                                if (uri.isNotBlank()) add(uri)
                            }
                        }

                    add(
                        MediaPlaylist(
                            id = id,
                            name = name,
                            itemUris = uris,
                        ),
                    )
                }
            }
        }.getOrDefault(emptyList())
    }

    fun savePlaylist(
        current: List<MediaPlaylist>,
        editingId: String?,
        name: String,
        itemUris: Set<String>,
    ): List<MediaPlaylist> {
        val normalizedName =
            name.trim().ifBlank { "Playlist" }

        val playlist =
            MediaPlaylist(
                id = editingId ?: UUID.randomUUID().toString(),
                name = normalizedName,
                itemUris = itemUris.toList(),
            )

        val updated =
            if (editingId == null) {
                current + playlist
            } else {
                current.map { existing ->
                    if (existing.id == editingId) {
                        playlist
                    } else {
                        existing
                    }
                }
            }.sortedBy { it.name.lowercase() }

        persistPlaylists(updated)
        return updated
    }

    fun deletePlaylist(
        current: List<MediaPlaylist>,
        playlistId: String,
    ): List<MediaPlaylist> {
        val updated = current.filterNot { it.id == playlistId }
        persistPlaylists(updated)
        return updated
    }

    fun pruneMissingAudio(
        current: List<MediaPlaylist>,
        validUris: Set<String>,
    ): List<MediaPlaylist> {
        val updated =
            current.map { playlist ->
                playlist.copy(
                    itemUris =
                        playlist.itemUris.filter { uri ->
                            uri in validUris
                        },
                )
            }

        if (updated != current) {
            persistPlaylists(updated)
        }

        return updated
    }

    private fun persistPlaylists(playlists: List<MediaPlaylist>) {
        val array = JSONArray()

        playlists.forEach { playlist ->
            array.put(
                JSONObject()
                    .put("id", playlist.id)
                    .put("name", playlist.name)
                    .put(
                        "itemUris",
                        JSONArray().apply {
                            playlist.itemUris.forEach(::put)
                        },
                    ),
            )
        }

        preferences
            .edit()
            .putString(KEY_PLAYLISTS, array.toString())
            .apply()
    }

    companion object {
        private const val KEY_FAVORITE_AUDIO = "favorite_audio_uris"
        private const val KEY_FAVORITE_STATIONS = "favorite_station_ids"
        private const val KEY_PLAYLISTS = "playlists"
    }
}
