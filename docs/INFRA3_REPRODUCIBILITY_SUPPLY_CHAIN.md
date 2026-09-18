# INFRA3 reproducibility and supply-chain controls

INFRA3 moves the R8 application and CI stack from version-pinned-but-runtime-built
tooling toward content-addressed acquisition, deterministic dependency evidence,
SBOM generation, and artifact provenance.

## Closed by the combined INFRA3 branch

### Rust CI utility acquisition

The CI workflows no longer run `cargo install` for:

- `cargo-audit` 0.22.2
- `cargo-deny` 0.20.2
- `cargo-llvm-cov` 0.9.1

`build/supply-chain-lock.json` records the exact upstream release URL and
SHA-256 for each Linux binary archive. `build/install-pinned-tool.py` downloads
only the recorded GitHub HTTPS asset, verifies its content digest before use,
extracts only the expected binary, and verifies its reported version.

A changed or replaced upstream asset fails closed unless its bytes still match
the committed SHA-256.

### Rust dependency authority and SBOM

The existing committed `Cargo.lock` remains the Rust dependency authority.

`build/generate-supply-chain-evidence.py` produces a deterministic CycloneDX
1.6 component inventory from `Cargo.lock`. It deliberately omits timestamps and
random serial numbers so the same source tree produces byte-identical JSON.

The same generator records:

- source commit and tree;
- hashes of critical build and workflow inputs;
- every external GitHub Action reference;
- the pinned tool lock;
- declared Android plugin and dependency coordinates;
- optional built-artifact hashes.

### Android dependency locking and verification bootstrap

`apps/r8/android/build.gradle.kts` activates dependency locking for all project
configurations.

The hosted `Supply-chain reproducibility baseline` workflow resolves the Android
multi-project dependency graph with Gradle 8.13 and writes:

- generated `gradle.lockfile` state;
- SHA-256 `gradle/verification-metadata.xml`;
- a resolved dependency report;
- a manifest of those generated files.

The initial hosted baseline was generated successfully by PR #13 and reviewed
before commit. Artifact `10527427195` had ZIP SHA-256
`a677dad354d556476898e70717ce4b9cde10e05a6beaacfdd5c1641fe0d6133d`.

The reviewed source state contains five module `gradle.lockfile` files plus
`gradle/verification-metadata.xml`. The metadata contains SHA-256 verification
entries and no host-specific `/home` or `/tmp` paths.

Hosted CI now resolves the same dependency graph without bootstrap write flags,
requires Gradle's committed dependency locks and verification metadata, and
proves that the committed supply-chain state is unchanged after resolution.

### APK provenance

The R8 APK seal workflow now emits, alongside the four APKs:

- `R8_APK_SEALS.txt`;
- `R8_SUPPLY_CHAIN_PROVENANCE.json`;
- `R8_RUST_SBOM.cdx.json`;
- `R8_SUPPLY_CHAIN_PROVENANCE.sha256`.

The provenance records the source commit/tree, critical-input hashes and APK
SHA-256 values. This is deterministic build evidence, not a cryptographic
signature or production attestation.

## Remaining INFRA3 closure step

The reviewed Gradle state is now committed in the INFRA3 branch. Final INFRA3
closure requires the updated PR head to pass hosted CI with:

1. checksum-verified Rust tool acquisition, including the corrected
   `cargo-llvm-cov llvm-cov --version` probe contract;
2. committed Gradle dependency locking;
3. committed SHA-256 dependency verification metadata;
4. immutable before/after Gradle supply-chain manifests;
5. APK provenance and deterministic Rust SBOM generation.

INFRA3 does not introduce production signing keys or a trusted self-hosted
runner. Those remain separate roadmap gates.
