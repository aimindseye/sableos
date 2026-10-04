# N1I-B2 native rederivation fixtures (synthetic)

Built at test time by `tests/titan2/n1i-b/test-native.py`.

* `java/java/lang/{System,Runtime}.java` extend the member-resolver core stubs with loader entry points.
* `java/app/p/Loaders.java` holds one System.load/loadLibrary call shape per data-flow case;
  `moved()` is overwritten with a crafted const-string -> move-object/from16 -> move-object chain.
* Native methods: `p.Ops` (Java_* exports in `../elf/synth.c`), `com.example.Foo_Bar` (overloaded
  long name), `com.example.synth.NativeBridge` (only JNI_OnLoad + strings: candidate only).
* `elf/vend.c` needs `libvendoronly.so` (vendor partition only) and `libgone.so` (absent everywhere).
* The APK packages lib/arm64-v8a/{libsynth,libvend}.so and an x86_64 copy that must be ignored.
* `libdep.so` is placed in the apex directory: a platform/APEX provider.
