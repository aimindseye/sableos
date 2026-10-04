package fw;

/** Boot-classpath copy. The app ships its own fw.Dup, which must be shadowed by this one. */
public class Dup { public static String who() { return "boot"; } }
