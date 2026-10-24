package org.sableos.tools.ui;

import static org.junit.Assert.*;
import java.io.File;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Comparator;
import org.junit.Test;

/** Regression tests run by :tools:testDebugUnitTest in the existing Sable Tools product. */
public final class PrivateTasksTest {
    @Test public void persistsCompletionAndReopen() throws Exception {
        Path root=Files.createTempDirectory("sable-tasks-");
        try {
            PrivateTasks store = new PrivateTasks(root.toFile());
            PrivateTasks.Task task=store.add("  Call Mom  ");
            assertEquals("Call Mom", task.title);
            assertFalse(task.complete);
            assertTrue(store.setComplete(task.id,true).complete);
            assertTrue(new PrivateTasks(root.toFile()).read(task.id).complete);
            assertFalse(store.setComplete(task.id,false).complete);
            assertEquals(1,store.list().size());
            assertTrue(store.delete(task.id));
            assertTrue(store.list().isEmpty());
        } finally { cleanup(root); }
    }

    @Test public void invalidTitlesAndTraversalFailClosed() throws Exception {
        Path root=Files.createTempDirectory("sable-tasks-");
        try {
            PrivateTasks store=new PrivateTasks(root.toFile());
            expectInvalid(() -> store.add(""));
            expectInvalid(() -> store.add("a\nb"));
            expectInvalid(() -> store.add("x".repeat(2049)));
            expectInvalid(() -> store.read("../../system"));
            assertTrue(store.list().isEmpty());
        } finally { cleanup(root); }
    }

    @Test public void taskSymlinksAreNeverFollowed() throws Exception {
        Path root=Files.createTempDirectory("sable-tasks-");
        Path other=Files.createTempFile("unrelated-task-", ".txt");
        try {
            PrivateTasks store=new PrivateTasks(root.toFile());
            String id=store.add("Test").id;
            Path leaf=root.resolve("tasks/task-"+id+".txt");
            Files.delete(leaf);
            Files.createSymbolicLink(leaf,other);
            expectInvalid(() -> store.read(id));
            expectInvalid(() -> store.setComplete(id,true));
            expectInvalid(() -> store.delete(id));
            assertTrue(Files.isRegularFile(other));
        } finally { cleanup(root); Files.deleteIfExists(other); }
    }

    private interface Checked { void run() throws Exception; }
    private static void expectInvalid(Checked action) throws Exception {
        try { action.run(); fail("unsafe operation was accepted"); }
        catch (IOException | IllegalArgumentException expected) { /* fail closed */ }
    }
    private static void cleanup(Path root) throws IOException {
        try (var walk=Files.walk(root)) {
            for (Path p:walk.sorted(Comparator.reverseOrder()).toList()) Files.deleteIfExists(p);
        }
    }
}
