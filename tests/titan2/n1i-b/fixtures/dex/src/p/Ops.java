package p;

/** Synthetic opcode-coverage fixture. Compiled with javac --release 8, dexed with dx. */
public class Ops extends Base implements Iface {
    public static boolean sz; public static byte sb; public static char sc; public static short ss;
    public static int si; public static long sj; public static float sf; public static double sd;
    public static Object so;
    public boolean iz; public byte ib; public char ic; public short is; public int ii; public long ij;
    public float iff; public double id; public Object io;
    private int priv;
    protected int prot;

    public Ops() { super(1); }

    public int arith(int a, int b, long c, long d, float e, float f, double g, double h) {
        int x = a + b; x = a - b; x *= b; x /= (b | 1); x %= (b | 1); x &= b; x |= b; x ^= b;
        x <<= b; x >>= b; x >>>= b; x = -x; x = ~x;
        long y = c + d; y = c - d; y *= d; y /= (d | 1); y %= (d | 1); y &= d; y |= d; y ^= d;
        y <<= a; y >>= a; y >>>= a; y = -y; y = ~y;
        float z = e + f; z = e - f; z *= f; z /= f; z %= f; z = -z;
        double w = g + h; w = g - h; w *= h; w /= h; w %= h; w = -w;
        int l8 = a + 7; l8 = a * 9; l8 = a / 3; l8 = a % 5; l8 = a & 0x3f; l8 = a | 0x11; l8 = a ^ 0x22;
        l8 = a << 3; l8 = a >> 2; l8 = a >>> 1; l8 = 9 - a;
        int l16 = a + 1000; l16 = a * 1001; l16 = a / 1002; l16 = a % 1003; l16 = a & 0x7ff0;
        l16 = a | 0x1234; l16 = a ^ 0x4321; l16 = 1000 - a;
        long cv = a; float cf = a; double cd = a; int ci = (int) c; float cf2 = c; double cd2 = c;
        int fi = (int) e; long fl = (long) e; double fd = e; int di = (int) g; long dl = (long) g;
        float df = (float) g; byte bb = (byte) a; char cc = (char) a; short sh = (short) a;
        int cmp = (e < f ? 1 : 0) + (e > f ? 1 : 0) + (g < h ? 1 : 0) + (g > h ? 1 : 0) + (c < d ? 1 : 0);
        long big = 0x123456789abcdefL; long w32 = 100000L; long w16 = 7L; long wh = 0x4000000000000000L;
        int k32 = 0x12345678; int kh = 0x40000000; int k16 = 1234; int k4 = 3;
        return x + (int) y + (int) z + (int) w + l8 + l16 + (int) cv + (int) cf + (int) cd + ci + (int) cf2
            + (int) cd2 + fi + (int) fl + (int) fd + di + (int) dl + (int) df + bb + cc + sh + cmp
            + (int) (big + w32 + w16 + wh) + k32 + kh + k16 + k4;
    }

    public int branches(int a, Object o) {
        int r = 0;
        if (a == 0) r++; if (a != 1) r++; if (a < 2) r++; if (a >= 3) r++; if (a > 4) r++; if (a <= 5) r++;
        if (a == r) r++; if (a != r) r++; if (a < r) r++; if (a >= r) r++; if (a > r) r++; if (a <= r) r++;
        switch (a) { case 1: r += 10; break; case 2: r += 20; break; case 3: r += 30; break; case 4: r += 40; break; default: r--; }
        switch (a) { case 1: r += 1; break; case 1000: r += 2; break; case 100000: r += 3; break; default: r -= 2; }
        if (o instanceof String) r += ((String) o).length();
        Class<?> k = Ops.class;
        synchronized (this) { r += k.hashCode(); }
        try { r /= a; } catch (ArithmeticException ex) { r = -1; } finally { r++; }
        if (a > 99) throw new IllegalStateException("x");
        return r;
    }

    public long arrays(int n) {
        int[] ia = {1, 2, 3, 4, 5}; long[] la = {1L, 2L, 3L}; byte[] ba = {1, 2, 3}; char[] ca = {'a', 'b'};
        short[] sa = {1, 2}; boolean[] za = {true, false}; float[] fa = {1f, 2f}; double[] da = {1d, 2d};
        Object[] oa = new Object[n]; int[][] mm = new int[n][n];
        ia[0] = ia[1]; la[0] = la[1]; ba[0] = ba[1]; ca[0] = ca[1]; sa[0] = sa[1]; za[0] = za[1];
        fa[0] = fa[1]; da[0] = da[1]; oa[0] = oa.length > 1 ? oa[1] : null; mm[0][0] = n;
        return ia[0] + la[0] + ba[0] + ca[0] + sa[0] + (za[0] ? 1 : 0) + (long) fa[0] + (long) da[0] + mm.length + oa.length;
    }

    public void fields() {
        sz = !sz; sb++; sc++; ss++; si++; sj++; sf++; sd++; so = this;
        iz = !iz; ib++; ic++; is++; ii++; ij++; iff++; id++; io = so; priv++; prot++;
    }

    public int calls(Iface f, Base b) {
        int r = f.value(1) + b.value(2) + super.value(3) + many(1, 2, 3, 4, 5, 6) + staticMany(1, 2, 3, 4, 5, 6, 7);
        r += f.dflt();
        return r + Integer.valueOf(r).hashCode();
    }

    @Override public int value(int x) { return x + 1; }

    private int many(int a, int b, int c, int d, int e, int f) { return a + b + c + d + e + f; }

    static int staticMany(int a, int b, int c, int d, int e, int f, int g) { return a + b + c + d + e + f + g; }

    public String concat(String a, int b) { return a + b + "s" + 'c'; }

    public native int nativeInstance(int x);

    public static native String nativeStatic(String s);
}
