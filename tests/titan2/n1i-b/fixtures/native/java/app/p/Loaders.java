package p;

/** Synthetic System.load/loadLibrary call shapes for the native data-flow self-test. */
public class Loaders {
    static String pick() { return null; }
    static void use(String s) {}

    static void constant() { System.loadLibrary("synth"); }                 // CONSTANT synth
    static void unrelatedString() {                                           // UNRESOLVED: arg is computed,
        String decoy = "decoylib";                                            // even though a string constant
        use(decoy);                                                           // sits in the same method
        System.loadLibrary(pick());
    }
    static void overwritten() {                                               // UNRESOLVED: constant overwritten
        String n = "synth";
        use(n);
        n = pick();
        System.loadLibrary(n);
    }
    static void parameter(String n) { System.loadLibrary(n); }               // UNRESOLVED: parameter
    static void branch(boolean f) { System.loadLibrary(f ? "vend" : "synth"); }  // UNRESOLVED: two definitions
    static void runtime() { Runtime.getRuntime().loadLibrary("rtlib"); }     // CONSTANT rtlib (virtual, arg 1)
    static void absolute() { System.load("/system/lib64/libabs.so"); }       // CONSTANT absolute path
    static void moved() {                                                    // body replaced by a crafted
        System.loadLibrary("vend");                                          // const-string / move-object /
        System.loadLibrary("vend");                                          // move-object/from16 chain
        System.loadLibrary("vend");
        System.loadLibrary("vend");                                          // (padding: the crafted body
        System.loadLibrary("vend");                                          //  also holds a wide-clobber case
        System.loadLibrary("vend");                                          //  and a dead-code case)
        System.loadLibrary("vend");
    }
}
