package app;

import java.lang.invoke.MethodHandle;

public class Lam {
    interface F { int f(int x); }
    static int lambda(int y) { F g = x -> x + y; return g.f(2); }                 // invoke-custom
    static Object poly(MethodHandle mh) throws Throwable { return mh.invoke("a"); }  // invoke-polymorphic
}
