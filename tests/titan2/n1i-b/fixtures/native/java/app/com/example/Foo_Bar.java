package com.example;

public class Foo_Bar {
    public static native int over(int a, String s);          // overloaded long-name export
    public static native int over(long a);                   // no export for this overload
}
