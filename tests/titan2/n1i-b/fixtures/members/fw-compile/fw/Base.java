package fw;

/** Synthetic compile-time API. Runtime variants (fw-stock, fw-c3a) differ on purpose. */
public class Base {
    public int v;
    public static int sfield;
    public int goneField;
    public static int fflip;
    public final int fin = 1;
    public int fin2;
    public Base() {}
    public Base(int x) {}
    public void m(int x) {}
    public static void sm() {}
    public void changed(int x) {}
    public static void flip() {}
    public void gone() {}
    public void wasPublic() {}
    public void becameProtected() {}
    protected void pm() {}
    void pkgm() {}
    public void mtkOnly() {}
}
