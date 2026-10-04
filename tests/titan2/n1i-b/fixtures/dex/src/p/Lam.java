package p;

import java.lang.invoke.MethodHandle;

public class Lam {
    interface F { int f(int x); }
    static int lambda(int y) { F g = x -> x + y; return g.f(2); }
    static Object poly(MethodHandle mh) throws Throwable { return mh.invoke("a"); }
    static Object polyRange(MethodHandle mh) throws Throwable { return mh.invoke("a", "b", "c", "d", "e", "f"); }
    static int bigLambda(int a, int b, int c, int d, int e, int f) {
        F g = x -> x + a + b + c + d + e + f; return g.f(1);
    }
}
