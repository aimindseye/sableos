package org.sableos.tools.ui

import android.app.AlertDialog
import android.text.InputType
import android.view.View
import android.widget.EditText
import android.widget.ScrollView
import java.io.IOException
import org.sableos.tools.core.Command

/** Existing Sable Tools -> Utilities -> Tasks. No background service, exported provider or remote sync. */
class TasksController(private val host: ToolHost) : ToolController {
    private val ctx = host.activity
    private val store = runCatching { PrivateTasks(ctx.filesDir) }.getOrNull()
    private val body = Ui.column(ctx)
    private val scroll = ScrollView(ctx).apply { addView(body) }
    private var showDone = false

    override fun view(): View = scroll.also { render() }

    private fun render() {
        body.removeAllViews()
        body.addView(Ui.body(ctx, "Tasks stay in private Sable Tools storage. No cloud sync or reminders."))
        body.addView(Ui.row(ctx, "+ New task") { newTask() })
        body.addView(Ui.row(ctx, if (showDone) "Hide completed tasks" else "Show completed tasks") {
            showDone = !showDone
            render()
        })
        val storage = store
        if (storage == null) {
            body.addView(Ui.body(ctx, "Tasks storage unavailable. No changes made."))
            return
        }
        val tasks = try { storage.list() } catch (_: IOException) {
            body.addView(Ui.body(ctx, "Tasks unavailable. No changes made."))
            return
        }
        val open = tasks.filterNot { it.complete }
        body.addView(Ui.header(ctx, "Open · ${open.size}"))
        if (open.isEmpty()) body.addView(Ui.body(ctx, "No open tasks."))
        open.take(MAX_VISIBLE).forEach { task ->
            body.addView(Ui.row(ctx, task.title, "Open") { taskActions(task) })
        }
        if (open.size > MAX_VISIBLE) body.addView(Ui.body(ctx, "Showing latest $MAX_VISIBLE open tasks."))
        if (showDone) {
            val done = tasks.filter { it.complete }
            body.addView(Ui.header(ctx, "Completed · ${done.size}"))
            if (done.isEmpty()) body.addView(Ui.body(ctx, "No completed tasks."))
            done.take(MAX_VISIBLE).forEach { task ->
                body.addView(Ui.row(ctx, task.title, "Done") { taskActions(task) })
            }
        }
    }

    private fun newTask() {
        val storage = store ?: return
        val editor = EditText(ctx).apply {
            hint = "Task title"
            inputType = InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_FLAG_CAP_SENTENCES
            setSingleLine(true)
            contentDescription = "New task title"
        }
        AlertDialog.Builder(ctx).setTitle("New task")
            .setView(editor)
            .setNegativeButton("Cancel", null)
            .setPositiveButton("Add") { _, _ ->
                try {
                    storage.add(editor.text.toString())
                    render()
                } catch (_: IOException) {
                    host.toast("Task storage full or unavailable")
                } catch (_: IllegalArgumentException) {
                    host.toast("Enter a short task title without control characters")
                }
            }.show()
    }

    private fun taskActions(task: PrivateTasks.Task) {
        val storage = store ?: return
        val next = if (task.complete) "Reopen" else "Mark complete"
        AlertDialog.Builder(ctx).setTitle(task.title)
            .setItems(arrayOf(next, "Delete…", "Cancel")) { _, item ->
                when (item) {
                    0 -> try {
                        storage.setComplete(task.id, !task.complete)
                        render()
                    } catch (_: IOException) { host.toast("Task update failed") }
                    1 -> confirmDelete(task)
                }
            }.show()
    }

    private fun confirmDelete(task: PrivateTasks.Task) {
        val storage = store ?: return
        AlertDialog.Builder(ctx).setTitle("Delete task?")
            .setMessage(task.title + "\nThis cannot be undone.")
            .setNegativeButton("Cancel", null)
            .setPositiveButton("Delete") { _, _ ->
                try {
                    storage.delete(task.id)
                    render()
                } catch (_: IOException) { host.toast("Task delete failed") }
            }.show()
    }

    override fun onCommand(c: Command): Boolean = false // Text fields own every printable key.
    override fun info() = "App-private tasks; current open tasks always precede explicit completed history. " +
        "No sync, notifications or background service."

    private companion object { const val MAX_VISIBLE = 40 }
}
