package org.sableos.media

import android.content.Context
import android.net.Uri
import android.provider.DocumentsContract
import java.util.ArrayDeque

internal class AudioFolderScanner(
    private val context: Context,
) {
    fun scan(treeUri: Uri): List<Uri> {
        val resolver = context.contentResolver
        val rootId =
            runCatching {
                DocumentsContract.getTreeDocumentId(treeUri)
            }.getOrNull() ?: return emptyList()

        val root =
            DocumentsContract.buildDocumentUriUsingTree(
                treeUri,
                rootId,
            )

        val pending = ArrayDeque<Uri>()
        val audio = mutableListOf<Uri>()
        pending.add(root)

        while (pending.isNotEmpty() && audio.size < MAX_AUDIO_FILES) {
            val directory = pending.removeFirst()
            val directoryId =
                runCatching {
                    DocumentsContract.getDocumentId(directory)
                }.getOrNull() ?: continue

            val children =
                DocumentsContract.buildChildDocumentsUriUsingTree(
                    treeUri,
                    directoryId,
                )

            runCatching {
                resolver.query(
                    children,
                    arrayOf(
                        DocumentsContract.Document.COLUMN_DOCUMENT_ID,
                        DocumentsContract.Document.COLUMN_MIME_TYPE,
                    ),
                    null,
                    null,
                    null,
                )
            }.getOrNull()?.use { cursor ->
                val idIndex =
                    cursor.getColumnIndex(
                        DocumentsContract.Document.COLUMN_DOCUMENT_ID,
                    )
                val mimeIndex =
                    cursor.getColumnIndex(
                        DocumentsContract.Document.COLUMN_MIME_TYPE,
                    )

                while (
                    cursor.moveToNext() &&
                    audio.size < MAX_AUDIO_FILES
                ) {
                    if (idIndex < 0 || mimeIndex < 0) continue

                    val documentId = cursor.getString(idIndex) ?: continue
                    val mimeType = cursor.getString(mimeIndex).orEmpty()
                    val documentUri =
                        DocumentsContract.buildDocumentUriUsingTree(
                            treeUri,
                            documentId,
                        )

                    if (
                        mimeType ==
                        DocumentsContract.Document.MIME_TYPE_DIR
                    ) {
                        pending.add(documentUri)
                    } else if (mimeType.startsWith("audio/")) {
                        audio.add(documentUri)
                    }
                }
            }
        }

        return audio
    }

    companion object {
        private const val MAX_AUDIO_FILES = 2_000
    }
}
