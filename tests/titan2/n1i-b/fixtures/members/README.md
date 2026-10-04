# N1I-B2 member-resolver fixtures (synthetic)

Built at test time by `tests/titan2/n1i-b/test-members.py` with `javac -source 8 -target 8` and `dx`.

| directory    | role at runtime                                                   |
|--------------|-------------------------------------------------------------------|
| `core/`      | minimal `java.lang` stubs: the boot "core" jar                    |
| `fw-compile/`| the API the app was compiled against (never on a runtime path)    |
| `fw-stock/`  | boot framework jar, stock side                                    |
| `fw-c3a/`    | boot framework jar, C3A side (no `mtkOnly`, no `MtkThing`)        |
| `apex/`      | boot-classpath APEX fragment                                      |
| `svc/`       | services.jar stand-in: never app-visible                          |
| `libreq/`    | required shared library `com.example.req`                         |
| `libopt/`    | optional shared library `com.example.opt`                         |
| `app/`       | app classes.dex, including an app-local duplicate of `fw.Dup`     |
| `app2/`      | app classes2.dex                                                  |

The intentional differences between `fw-compile` and the runtime jars create one case per resolver
result; each call in `app/app/Main.java` is commented with the result it must produce.
