package app;

public class Sub extends fw.Base implements fw.Api {
    public void m(int x) {
        super.m(x);                             // invoke-super on a class: RESOLVED
        pm();                                   // protected member from a subclass: RESOLVED
    }
    public int d() { return fw.Api.super.d(); }   // invoke-super on an interface: RESOLVED
    public void a() {}
}
