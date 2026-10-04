package q;

/** Lives in classes2.dex of the multidex fixture. */
public class Second extends p.Base {
    public Second() { super(2); }
    public int value(int x) { return x * 2; }
}
