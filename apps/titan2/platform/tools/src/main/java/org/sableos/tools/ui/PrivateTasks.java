package org.sableos.tools.ui;

import java.io.File;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.charset.CharacterCodingException;
import java.nio.ByteBuffer;
import java.nio.charset.CodingErrorAction;
import java.nio.file.Files;
import java.nio.file.LinkOption;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.UUID;

/** A local-first task store owned by the existing Sable Tools app, with no provider or network. */
public final class PrivateTasks {
    public static final int MAX_TASKS = 250;
    public static final int MAX_TITLE_BYTES = 2048;
    private static final int MAX_DIRECTORY_ENTRIES = 2000;
    private static final int MAX_FILE_BYTES = 4096;
    private static final String UUID_PATTERN = "[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}";
    private final Path root;

    public static final class Task {
        public final String id;
        public final String title;
        public final boolean complete;
        public final long modifiedMillis;
        Task(String id, String title, boolean complete, long modifiedMillis) {
            this.id = id;
            this.title = title;
            this.complete = complete;
            this.modifiedMillis = modifiedMillis;
        }
    }

    public PrivateTasks(File appFiles) throws IOException {
        if (appFiles == null) throw new IOException("No app-private storage");
        Path parent = appFiles.toPath();
        if (Files.isSymbolicLink(parent) || !Files.isDirectory(parent, LinkOption.NOFOLLOW_LINKS)) {
            throw new IOException("Unsafe app-private storage");
        }
        root = parent.resolve("tasks");
        if (Files.isSymbolicLink(root)) throw new IOException("Symlink task directory");
        if (!Files.exists(root, LinkOption.NOFOLLOW_LINKS)) Files.createDirectory(root);
        if (!Files.isDirectory(root, LinkOption.NOFOLLOW_LINKS)) throw new IOException("Not a task directory");
    }

    private Path leaf(String id) {
        if (id == null || !id.matches(UUID_PATTERN)) throw new IllegalArgumentException("Invalid task id");
        return root.resolve("task-" + id + ".txt");
    }

    private static String validateTitle(String s) {
        if (s == null) throw new IllegalArgumentException("Missing task title");
        // Check raw input first; trim() would otherwise silently erase control characters.
        for (int i = 0; i < s.length(); i++) {
            char c = s.charAt(i);
            if (Character.isISOControl(c)) throw new IllegalArgumentException("Unsafe control in title");
        }
        String title = s.trim();
        if (title.isEmpty() || title.getBytes(StandardCharsets.UTF_8).length > MAX_TITLE_BYTES) {
            throw new IllegalArgumentException("Task title must be 1 to 2048 UTF-8 bytes");
        }
        for (int i = 0; i < title.length(); i++) {
            char c = title.charAt(i);
            if (Character.isISOControl(c)) throw new IllegalArgumentException("Unsafe control in title");
            if (Character.isHighSurrogate(c)) {
                if (i + 1 >= title.length() || !Character.isLowSurrogate(title.charAt(i + 1))) {
                    throw new IllegalArgumentException("Unpaired high surrogate");
                }
                i++;
            } else if (Character.isLowSurrogate(c)) {
                throw new IllegalArgumentException("Unpaired low surrogate");
            }
        }
        return title;
    }

    private void write(String id, String title, boolean complete) throws IOException {
        Path dest = leaf(id);
        if (Files.isSymbolicLink(dest)) throw new IOException("Symlink task file");
        if (Files.exists(dest, LinkOption.NOFOLLOW_LINKS) &&
            !Files.isRegularFile(dest, LinkOption.NOFOLLOW_LINKS)) throw new IOException("Unsafe task file");
        byte[] data = ("v1\n" + (complete ? "1" : "0") + "\n" + title).getBytes(StandardCharsets.UTF_8);
        if (data.length > MAX_FILE_BYTES) throw new IOException("Task data oversized");
        Path tmp = Files.createTempFile(root, ".new-task-", ".tmp");
        try {
            Files.write(tmp, data);
            try {
                Files.move(tmp, dest, StandardCopyOption.ATOMIC_MOVE, StandardCopyOption.REPLACE_EXISTING);
            } catch (java.nio.file.AtomicMoveNotSupportedException e) {
                Files.move(tmp, dest, StandardCopyOption.REPLACE_EXISTING);
            }
        } finally {
            Files.deleteIfExists(tmp);
        }
    }

    public Task add(String label) throws IOException {
        String title = validateTitle(label);
        if (list().size() >= MAX_TASKS) throw new IOException("Task limit reached");
        String id = UUID.randomUUID().toString();
        if (Files.exists(leaf(id), LinkOption.NOFOLLOW_LINKS)) throw new IOException("Task ID collision");
        write(id, title, false);
        return read(id);
    }

    public Task read(String id) throws IOException {
        Path file = leaf(id);
        if (Files.isSymbolicLink(file) || !Files.isRegularFile(file, LinkOption.NOFOLLOW_LINKS)) {
            throw new IOException("Task does not exist or unsafe file");
        }
        if (Files.size(file) > MAX_FILE_BYTES) throw new IOException("Task data oversized");
        String s;
        try {
            s = StandardCharsets.UTF_8.newDecoder()
                .onMalformedInput(CodingErrorAction.REPORT)
                .onUnmappableCharacter(CodingErrorAction.REPORT)
                .decode(ByteBuffer.wrap(Files.readAllBytes(file))).toString();
        } catch (CharacterCodingException ex) {
            throw new IOException("Invalid task encoding", ex);
        }
        String[] fields = s.split("\n", 3);
        if (fields.length != 3 || !"v1".equals(fields[0]) ||
            !("0".equals(fields[1]) || "1".equals(fields[1]))) throw new IOException("Invalid task data");
        try {
            String title = validateTitle(fields[2]);
            if (!title.equals(fields[2])) throw new IOException("Noncanonical task title");
            return new Task(id, title, "1".equals(fields[1]), Files.getLastModifiedTime(file).toMillis());
        } catch (IllegalArgumentException ex) {
            throw new IOException("Invalid task title", ex);
        }
    }

    public Task setComplete(String id, boolean complete) throws IOException {
        Task old = read(id);
        if (old.complete != complete) write(id, old.title, complete);
        return read(id);
    }

    public boolean delete(String id) throws IOException {
        Path file = leaf(id);
        if (Files.isSymbolicLink(file)) throw new IOException("Symlink task file");
        if (Files.exists(file, LinkOption.NOFOLLOW_LINKS) &&
            !Files.isRegularFile(file, LinkOption.NOFOLLOW_LINKS)) throw new IOException("Unsafe task file");
        return Files.deleteIfExists(file);
    }

    public List<Task> list() throws IOException {
        File[] entries = root.toFile().listFiles();
        if (entries == null) throw new IOException("Task storage unavailable");
        if (entries.length > MAX_DIRECTORY_ENTRIES) throw new IOException("Too many task directory entries");
        List<Task> tasks = new ArrayList<>();
        for (File file : entries) {
            String name = file.getName();
            if (!name.matches("task-" + UUID_PATTERN + "\\.txt")) continue;
            if (tasks.size() >= MAX_TASKS) throw new IOException("Task limit exceeded");
            tasks.add(read(name.substring(5, 41)));
        }
        tasks.sort(Comparator.comparing((Task t) -> t.complete)
            .thenComparing(Comparator.comparingLong((Task t) -> t.modifiedMillis).reversed())
            .thenComparing(t -> t.id));
        return tasks;
    }
}
