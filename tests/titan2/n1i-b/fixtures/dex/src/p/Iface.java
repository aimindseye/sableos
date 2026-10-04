package p;

public interface Iface {
    int CONST = 7;
    int value(int x);
    default int dflt() { return 42; }
    static int stat() { return 1; }
}
