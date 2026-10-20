package org.sableos.tools.ui;

import java.io.File;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.StandardCopyOption;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.UUID;

/** App-private file notes, no cloud sync, content provider or external storage.
 * Reused from the previously validated Wave 2 PrivateNotes implementation;
 * the package is relocated into the existing Sable Tools Android app.
 */
public final class PrivateNotes {
    private final File root;
    public PrivateNotes(File appFiles) {
        this.root = new File(appFiles, "notes");
        if (!root.isDirectory() && !root.mkdirs()) throw new IllegalStateException("Notes storage unavailable");
    }
    private File leaf(String id) {
        if (id == null || !id.matches("[a-f0-9-]{36}")) throw new IllegalArgumentException("Invalid note id");
        return new File(root, "note-" + id + ".txt");
    }
    public String create() { return UUID.randomUUID().toString(); }
    public String read(String id) throws IOException {
        File file = leaf(id);
        if (!file.isFile()) return "";
        if (file.length() > 128 * 1024) throw new IOException("Note exceeds size limit");
        return new String(Files.readAllBytes(file.toPath()), StandardCharsets.UTF_8);
    }
    public void write(String id, String body) throws IOException {
        if (body == null || body.getBytes(StandardCharsets.UTF_8).length > 64 * 1024) throw new IOException("Note exceeds size limit");
        File target = leaf(id);
        File tmp = File.createTempFile("note-", ".tmp", root);
        boolean done = false;
        try {
            Files.write(tmp.toPath(), body.getBytes(StandardCharsets.UTF_8));
            try { Files.move(tmp.toPath(), target.toPath(), StandardCopyOption.ATOMIC_MOVE, StandardCopyOption.REPLACE_EXISTING); }
            catch (java.nio.file.AtomicMoveNotSupportedException e) { Files.move(tmp.toPath(), target.toPath(), StandardCopyOption.REPLACE_EXISTING); }
            done = true;
        } finally { if (!done) tmp.delete(); }
    }
    public boolean delete(String id) { return leaf(id).delete(); }
    public List<String> list() {
        File[] names = root.listFiles((dir, name) -> name.startsWith("note-") && name.endsWith(".txt") && name.length() == 45);
        List<File> notes = new ArrayList<>();
        if (names != null) for (File name : names) if (name.isFile()) notes.add(name);
        notes.sort(Comparator.comparingLong(File::lastModified).reversed());
        List<String> ids = new ArrayList<>();
        for (File f : notes) ids.add(f.getName().substring(5, 41));
        return ids;
    }
}