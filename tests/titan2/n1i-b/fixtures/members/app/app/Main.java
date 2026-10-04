package app;

/** Synthetic app. Every call below is one member-resolution case; see test-members.py. */
public class Main {
    public void cases() throws Throwable {
        fw.Base b = new fw.Base();              // invoke-direct <init>()V: RESOLVED
        b.m(1);                                 // invoke-virtual: RESOLVED
        fw.Base.sm();                           // invoke-static: RESOLVED
        int sf = fw.Base.sfield;                // sget: RESOLVED
        b.changed(1);                           // DESCRIPTOR_MISMATCH (runtime has changed(J)V)
        fw.Base.flip();                         // STATIC_INSTANCE_MISMATCH (method became instance)
        int ff = fw.Base.fflip;                 // STATIC_INSTANCE_MISMATCH (field became instance)
        b.gone();                               // METHOD_MISSING
        int g = b.goneField;                    // FIELD_MISSING
        fw.Removed.r();                         // CLASS_MISSING
        b.wasPublic();                          // ACCESS_VIOLATION (private at runtime)
        b.becameProtected();                    // ACCESS_VIOLATION (protected, caller not a subclass)
        fw.WasClass wc = null;
        wc.w();                                 // ICCE_KIND (invoke-virtual on an interface)
        fw.WasIface wi = null;
        wi.i();                                 // ICCE_KIND (invoke-interface on a class)
        fw.Child c = new fw.Child();            // RESOLVED
        c.m(2);                                 // inherited method (declared in Base)
        int iv = c.v;                           // inherited field (declared in Base)
        int dv = c.d();                         // invoke-virtual reaching an interface default method
        fw.Api api = c;
        int ad = api.d();                       // invoke-interface default method
        int st = fw.Api.st();                   // invoke-static on interface
        new fw.Child(5);                        // METHOD_MISSING: Child(I) absent, Base(I) not inherited
        b.mtkOnly();                            // stock RESOLVED / C3A METHOD_MISSING
        fw.MtkThing.x();                        // stock RESOLVED / C3A CLASS_MISSING
        ax.ApexApi.call();                      // APEX boot-classpath fragment: RESOLVED
        svc.SystemThing.x();                    // services.jar only: CLASS_MISSING
        lr.ReqLib.r();                          // required shared library
        lo.OptLib.o();                          // optional shared library
        String who = fw.Dup.who();              // boot fw.Dup wins over the app copy
        String only = fw.Dup.appOnly();         // METHOD_MISSING: the app copy is shadowed by boot
        fw.AppPeer.peek(b);                     // RESOLVED; the pkgm() call inside it is an ACCESS_VIOLATION
        b.fin2 = 3;                             // ACCESS_VIOLATION: final field written outside its class
    }
}
