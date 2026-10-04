package fw;

public interface Api {
    void a();
    default int d() { return 1; }
    static int st() { return 2; }
}
