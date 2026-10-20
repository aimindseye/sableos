package org.sableos.tools.ui

import android.app.AlertDialog
import android.content.ActivityNotFoundException
import android.content.Intent
import android.media.MediaPlayer
import android.media.MediaRecorder
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.provider.AlarmClock
import android.text.InputType
import android.view.Gravity
import android.view.View
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import org.sableos.tools.core.Command
import java.io.File
import java.io.IOException
import java.text.DateFormat
import java.util.Date
import java.util.Locale

/** Private Notes inside the existing Sable Tools package: no exported content provider or network sync. */
class NotesController(private val host: ToolHost) : ToolController {
    private val ctx = host.activity
    private val store = PrivateNotes(ctx.filesDir)
    private val body = Ui.column(ctx)
    private val scroll = ScrollView(ctx).apply { addView(body) }

    override fun view(): View = scroll.also { showList() }

    private fun showList() {
        body.removeAllViews()
        body.addView(Ui.body(ctx, "Stored only in Sable Tools private app data. Use Enter to open a note."))
        body.addView(Ui.row(ctx, "+ New note") { edit(store.create()) })
        val notes = store.list()
        if (notes.isEmpty()) body.addView(Ui.body(ctx, "No notes yet."))
        notes.take(MAX_VISIBLE).forEach { id ->
            val title = try {
                store.read(id).lineSequence().firstOrNull().orEmpty().take(TITLE_LIMIT).ifBlank { "Untitled note" }
            } catch (_: IOException) {
                "Unreadable note"
            }
            body.addView(Ui.row(ctx, title) { edit(id) })
        }
        if (notes.size > MAX_VISIBLE) body.addView(Ui.body(ctx, "Showing the most recent $MAX_VISIBLE notes."))
    }

    private fun edit(id: String) {
        val original = try { store.read(id) } catch (_: IOException) {
            host.toast("Could not read note")
            return
        }
        body.removeAllViews()
        body.addView(Ui.row(ctx, "← Notes") { showList() })
        val editor = EditText(ctx).apply {
            hint = "Note text"
            inputType = InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_FLAG_MULTI_LINE or
                InputType.TYPE_TEXT_FLAG_CAP_SENTENCES
            setSingleLine(false)
            minLines = 8
            gravity = Gravity.TOP
            setText(original)
            contentDescription = "Edit note"
        }
        body.addView(editor)
        body.addView(Ui.row(ctx, "Save note") {
            try {
                store.write(id, editor.text.toString())
                showList()
            } catch (_: IOException) {
                host.toast("Note save failed or exceeds 64 KiB")
            }
        })
        body.addView(Ui.row(ctx, "Discard changes") { showList() })
        if (original.isNotEmpty()) {
            body.addView(Ui.row(ctx, "Delete note") {
                AlertDialog.Builder(ctx).setTitle("Delete this note?")
                    .setMessage("This cannot be undone.")
                    .setNegativeButton("Cancel", null)
                    .setPositiveButton("Delete") { _, _ ->
                        if (!store.delete(id)) host.toast("Delete failed")
                        showList()
                    }.show()
            })
        }
        editor.requestFocus()
    }

    override fun info() = "Text notes only; 64 KiB maximum per note, app-private files, no cloud or sharing."

    private companion object {
        const val TITLE_LIMIT = 60
        const val MAX_VISIBLE = 40
    }
}

/** Microphone permission is obtained by ToolActivity at tool entry. Backgrounding stops capture and playback. */
class VoiceRecorderController(private val host: ToolHost) : ToolController {
    private val ctx = host.activity
    private val root = Ui.column(ctx)
    private val scroll = ScrollView(ctx).apply { addView(root) }
    private val directory = File(ctx.filesDir, "recordings")
    private var recorder: MediaRecorder? = null
    private var player: MediaPlayer? = null
    private var pending: File? = null
    private var status = Ui.body(ctx, "Idle")

    override fun view(): View = scroll.also { render() }

    private fun render() {
        root.removeAllViews()
        root.addView(Ui.body(ctx, "Recordings stay inside Sable Tools. Capture stops when this screen is left."))
        status = Ui.body(ctx, if (recorder == null) "Not recording" else "Recording — microphone in use")
        root.addView(status)
        root.addView(Ui.row(ctx, if (recorder == null) "Start recording" else "Stop and save") {
            if (recorder == null) begin() else end()
            render()
        })
        root.addView(Ui.row(ctx, "Stop playback") { stopPlayback() })
        val files = directory.listFiles { file -> file.isFile && file.name.matches(CLIP_PATTERN) }
            ?.sortedByDescending { it.lastModified() }.orEmpty()
        if (files.isEmpty()) root.addView(Ui.body(ctx, "No recordings yet."))
        files.take(MAX_VISIBLE).forEach { clip ->
            root.addView(Ui.row(ctx, "Play ${clip.name}") { play(clip) })
            root.addView(Ui.row(ctx, "Delete ${clip.name}") {
                AlertDialog.Builder(ctx).setTitle("Delete recording?")
                    .setNegativeButton("Cancel", null)
                    .setPositiveButton("Delete") { _, _ ->
                        stopPlayback()
                        if (!clip.delete()) host.toast("Delete failed")
                        render()
                    }.show()
            })
        }
        if (files.size > MAX_VISIBLE) root.addView(Ui.body(ctx, "Showing latest $MAX_VISIBLE recordings."))
    }

    private fun begin() {
        if (recorder != null) return
        if (!directory.isDirectory && !directory.mkdirs()) {
            host.toast("Recording storage unavailable")
            return
        }
        val clip = try { File.createTempFile("rec-", ".m4a", directory) } catch (_: IOException) {
            host.toast("Cannot create recording")
            return
        }
        val fresh = try { MediaRecorder(ctx) } catch (_: RuntimeException) {
            clip.delete()
            host.toast("Microphone unavailable")
            return
        }
        try {
            stopPlayback()
            fresh.setAudioSource(MediaRecorder.AudioSource.MIC)
            fresh.setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
            fresh.setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
            fresh.setOutputFile(clip.absolutePath)
            fresh.setMaxDuration(MAX_DURATION_MS)
            fresh.setOnInfoListener { _, what, _ ->
                if (what == MediaRecorder.MEDIA_RECORDER_INFO_MAX_DURATION_REACHED) {
                    end()
                    render()
                }
            }
            fresh.prepare()
            fresh.start()
            recorder = fresh
            pending = clip
        } catch (_: Exception) {
            runCatching { fresh.reset() }
            runCatching { fresh.release() }
            clip.delete()
            host.toast("Microphone unavailable")
        }
    }

    private fun end() {
        val active = recorder ?: return
        recorder = null
        val clip = pending
        pending = null
        val good = runCatching { active.stop() }.isSuccess
        runCatching { active.reset() }
        runCatching { active.release() }
        if (!good) {
            clip?.delete()
            host.toast("Recording was too short or failed")
        }
    }

    private fun play(clip: File) {
        if (recorder != null) return
        stopPlayback()
        val p = MediaPlayer()
        player = p
        try {
            p.setDataSource(clip.absolutePath)
            p.setOnPreparedListener { prepared -> if (player === prepared) prepared.start() }
            p.setOnCompletionListener { stopPlayback() }
            p.setOnErrorListener { _, _, _ -> stopPlayback(); true }
            p.prepareAsync()
        } catch (_: Exception) {
            stopPlayback()
            host.toast("Cannot play recording")
        }
    }

    private fun stopPlayback() {
        val active = player ?: return
        player = null
        runCatching { active.stop() }
        runCatching { active.release() }
    }

    override fun stop() { end(); stopPlayback(); render() }
    override fun info() = "Audio is only recorded while this tool is foregrounded and has microphone permission. Maximum five minutes per clip."

    private companion object {
        val CLIP_PATTERN = Regex("rec-[A-Za-z0-9-]+\\.m4a")
        const val MAX_DURATION_MS = 300_000
        const val MAX_VISIBLE = 30
    }
}

/** App-local clock and elapsed stopwatch. Actual alarms are always delegated to the Android Clock owner. */
class ClockStopwatchController(private val host: ToolHost) : ToolController {
    private val ctx = host.activity
    private val handler = Handler(Looper.getMainLooper())
    private var accumulatedMs = 0L
    private var startedMs = 0L
    private var running = false
    private val current = Ui.reading(ctx)
    private val elapsed = Ui.mono(ctx)
    private val body = Ui.column(ctx)
    private val tick = object : Runnable {
        override fun run() {
            current.text = DateFormat.getTimeInstance(DateFormat.MEDIUM).format(Date())
            val ms = duration()
            elapsed.text = String.format(Locale.getDefault(), "%02d:%02d.%01d", ms / 60000, ms / 1000 % 60, ms % 1000 / 100)
            handler.postDelayed(this, TICK_MS)
        }
    }

    override fun view(): View = ScrollView(ctx).apply {
        body.addView(Ui.body(ctx, "Session stopwatch. Android Clock owns alarms."))
        body.addView(current)
        body.addView(elapsed)
        body.addView(Ui.row(ctx, "Start / pause") { toggle() })
        body.addView(Ui.row(ctx, "Reset stopwatch") { reset() })
        body.addView(Ui.row(ctx, "Set alarm in system Clock") {
            try {
                ctx.startActivity(Intent(AlarmClock.ACTION_SET_ALARM))
            } catch (_: ActivityNotFoundException) {
                host.toast("No installed Clock handles alarms")
            }
        })
        addView(body)
    }

    private fun duration(): Long = accumulatedMs + if (running) SystemClock.elapsedRealtime() - startedMs else 0L
    private fun toggle() {
        if (running) accumulatedMs = duration() else startedMs = SystemClock.elapsedRealtime()
        running = !running
    }
    private fun reset() { accumulatedMs = 0; startedMs = SystemClock.elapsedRealtime(); running = false }
    override fun onCommand(c: Command): Boolean = when (c) {
        Command.Toggle -> { toggle(); true }
        Command.Reset -> { reset(); true }
        else -> false
    }
    override fun start() { handler.removeCallbacks(tick); handler.post(tick) }
    override fun stop() { handler.removeCallbacks(tick) }
    override fun info() = "Stopwatch uses monotonic elapsed time while this process stays alive; no background alarm service."

    private companion object { const val TICK_MS = 200L }
}
