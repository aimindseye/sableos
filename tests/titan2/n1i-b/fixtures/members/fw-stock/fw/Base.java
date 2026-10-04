package fw;

/** Synthetic runtime API, stock side. */
public class Base {
    public int v;
    public static int sfield;
    public int fflip;                       // was static at compile time
    public final int fin = 1;
    public final int fin2 = 0;              // became final
    public Base() {}
    public Base(int x) {}
    public void m(int x) {}
    public static void sm() {}
    public void changed(long x) {}          // descriptor changed
    public void flip() {}                   // was static at compile time
    private void wasPublic() {}             // access narrowed
    protected void becameProtected() {}     // access narrowed
    protected void pm() {}
    void pkgm() {}
    public void mtkOnly() {}                // stock-only member
}
