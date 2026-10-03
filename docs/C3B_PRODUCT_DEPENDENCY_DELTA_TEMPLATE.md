# Dependency delta template

Copy into the PR body (the renderer prints it). A PR with no new dependency states `DEPENDENCY_DELTA=NONE`.
Nothing is installed on the controlled host by a product-lane script.

```text
DEPENDENCY_DELTA=NONE_OR_EXPLICIT
HOST_PACKAGE_INSTALL_REQUIRED=NO_OR_EXPLICIT
NETWORK_FETCH_REQUIRED=NO_OR_EXPLICIT
NEW_MAVEN_DEPENDENCIES=NONE_OR_EXPLICIT
NEW_RUST_CRATES=NONE_OR_EXPLICIT
NEW_NATIVE_LIBRARIES=NONE_OR_EXPLICIT
NEW_ANDROID_SDK_COMPONENTS=NONE_OR_EXPLICIT
DEPENDENCY_VERIFICATION_METADATA=NOT_CHANGED | OPERATOR_BOOTSTRAP_REQUIRED
```

For every new dependency record:

| field | value |
|---|---|
| exact name | |
| exact version or commit | |
| upstream/source | |
| licence | |
| reason required | |
| could an existing SableOS dependency satisfy it? | |

Dependency-verification metadata is generated for this repository's own dependency graph; canonical metadata is not copied.
If it cannot be generated in the authoring environment, declare `DEPENDENCY_VERIFICATION_METADATA=OPERATOR_BOOTSTRAP_REQUIRED`.
