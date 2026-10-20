package org.sableos.tools.ui;

import static org.junit.Assert.*;
import java.io.File;
import java.io.IOException;
import java.nio.file.Files;
import java.util.List;
import org.junit.Test;

/** Host-side tests for the actual app-private store (not a synthetic notes implementation). */
public final class PrivateNotesTest {
    @Test public void createSaveReadListDelete() throws Exception {
        File root = Files.createTempDirectory("sable-personal-notes").toFile();
        try {
            PrivateNotes store = new PrivateNotes(root);
            String id = store.create();
            assertEquals("", store.read(id));
            store.write(id, "Sable private note\nsecond line");
            assertEquals("Sable private note\nsecond line", store.read(id));
            assertEquals(List.of(id), store.list());
            assertTrue(store.delete(id));
            assertTrue(store.list().isEmpty());
        } finally {
            File folder = new File(root, "notes");
            File[] all = folder.listFiles();
            if (all != null) for (File f : all) f.delete();
            folder.delete();
            root.delete();
        }
    }

    @Test public void invalidIdAndOversizeDoNotWrite() throws Exception {
        File root = Files.createTempDirectory("sable-personal-notes").toFile();
        try {
            PrivateNotes store = new PrivateNotes(root);
            try { store.read("../../system"); fail("Traversal accepted"); }
            catch (IllegalArgumentException expected) { /* fail closed */ }
            String id = store.create();
            try { store.write(id, "x".repeat(65537)); fail("Oversize accepted"); }
            catch (IOException expected) { /* fail closed */ }
            assertEquals("", store.read(id));
            assertTrue(store.list().isEmpty());
        } finally {
            File folder = new File(root, "notes");
            File[] all = folder.listFiles();
            if (all != null) for (File f : all) f.delete();
            folder.delete();
            root.delete();
        }
    }
}
