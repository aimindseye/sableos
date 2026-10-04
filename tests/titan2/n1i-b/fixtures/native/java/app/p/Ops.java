package p;

public class Ops {
    public native int nativeInstance(int x);                  // Java_p_Ops_nativeInstance export
    public static native String nativeStatic(String s);      // Java_p_Ops_nativeStatic export
    public native void nativeUnmapped();                      // no export, no registration evidence
}
