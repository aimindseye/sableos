package fw;

/** App-local duplicate of a boot class. ART loads the boot copy (parent-first). */
public class Dup {
    public static String who() { return "app"; }
    public static String appOnly() { return "app"; }
}
