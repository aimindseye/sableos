# SableOS build entry points

New development should use these stable repository entry points instead of
milestone-specific ad hoc commands.

```text
build/config/panther-grapheneos-2026081300.env
build/panther/bootstrap.sh
build/panther/capture-sablestart.sh
build/panther/verify-sablestart-snapshot.sh
build/panther/sync-sablestart.sh
build/panther/build-sablestart.sh
build/panther/build-target-files.sh
build/gates/sablestart-r3-prebuild.sh
build/gates/sablestart-r3b-soong.sh
```

The capture helper copies the complete SableStart module tree (including Rust and binary/resource assets) while excluding common build/cache directories. The snapshot verifier recursively compares the repository copy with the validated upstream workspace before portability is considered closed.

See `docs/BUILD_LAYOUT.md` and `docs/PORTABLE_DEVELOPMENT.md`.

Authorization remains explicit. Bootstrap requires `NETWORK_FETCH_AUTHORIZED=YES`, sync requires `SOURCE_MUTATION_AUTHORIZED=YES`, and builds require `BUILD_AUTHORIZED=YES`.
