package fw;

/** App class that shares the package NAME fw with the boot classpath but not its class loader. */
public class AppPeer {
    public static void peek(Base b) { b.pkgm(); }   // ACCESS_VIOLATION: different runtime package
}
