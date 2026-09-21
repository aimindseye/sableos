# Canonical SableOS source and build layout

Status: canonical local build layout, updated 2026-09-19.

## Principles

Sable-owned source, build orchestration and qualification contracts live in
`aimindseye/sableos`. GrapheneOS/AOSP workspaces and build outputs are generated
substrates. Host tools are versioned build inputs and therefore have their own
stable root outside any one build workspace.

Do not create milestone-specific host-tool trees or ad hoc /tmp build drivers for
normal R8 builds.

## Standard ai-g732 layout

```text
/srv/data/
├── sable-build/
│   ├── sableos/
│   │   └── repo/                         # aimindseye/sableos checkout
│   ├── workspaces/
│   │   └── r8-a4-panther-base-2026081300/ # GrapheneOS/AOSP Panther substrate
│   ├── sources/
│   │   └── r8-upstreams/                 # pinned Reader/TextReader/Mail source caches
│   ├── artifacts/
│   │   └── panther/
│   └── evidence/
│       └── panther/
└── sable-host-tools/
    ├── android/
    │   └── r8/
    │       └── sdk/                       # SDK 36, build-tools 36.0.0, NDK 30.0.16248370
    ├── rust/
    │   └── 1.98.1/
    │       ├── cargo/
    │       └── rustup/
    ├── gradle/                            # canonical GRADLE_USER_HOME
    └── node-v24.20.0-linux-x64/           # vendor-tool Node reference
```

The canonical host-tool path is `/srv/data/sable-host-tools`. Build scripts must
source `build/config/r8-host-tools.env`; they must not discover or hard-code the
legacy `/srv/data/sable-build/host-tools/r8-final-v1` path.

## Repository build contract

```text
build/config/r8-host-tools.env
build/config/r8-release.env
build/host/verify-r8-host-tools.sh
build/host/migrate-r8-final-v1-host-tools.sh
build/panther/run-r8-release-candidate.sh
build/panther/render-r8-build-driver.sh
build/gates/r8-build-driver-contract.sh
.github/workflows/r8-build-driver.yml
```

GitHub Actions renders a source-commit-bound build driver, syntax-checks and
contract-checks it, hashes it, and uploads it as an artifact. Local execution on
`ai-g732` uses that artifact. The generated driver verifies that the local
repository HEAD exactly matches its embedded GitHub commit before any build work.

The repository runner owns SDK/NDK/Rust/JDK/Gradle environment setup. A caller
does not export those paths manually.

## Source of truth

`main` is the source of truth for:

- Sable-owned Android/Rust source;
- product module/package selection;
- upstream source pins;
- host-tool versions and canonical paths;
- build orchestration;
- CI build-driver generation;
- qualification gates and documentation.

Build outputs, Gradle caches, Android workspaces and downloaded upstream source
caches are never canonical source.

## Normal flow

```text
GitHub PR
  -> ai-g732 checks out exact source commit
  -> bash build/sable.sh panther R9 ci full
  -> host-tool / policy / Rust / Android / security gates
  -> first-party APK build
  -> Reader/Text Reader/Mail composition
  -> source-bound nine-APK freeze
  -> bash build/sable.sh panther R9 qualify physical-ux
  -> Panther source/product preparation
  -> exact vendor/sable inventory gate
  -> Launcher3-hosted SableStart Soong preflight
  -> Dialer/Contacts presentation verification
  -> combined Launcher3/application/Settings/SystemUI module gate
  -> fresh source-bound visual acceptance
  -> only then final Panther target-files build
  -> artifact audit
  -> separately authorized device deployment
```

A successful build is evidence, not source.


## Production SableStart qualification

SableStart no longer owns a standalone HOME runtime. Its presentation source is
hosted by upstream Launcher3/Quickstep, with Android's Launcher3 mechanisms
remaining authoritative.

Repository CI compiles the production presentation source through
`sablestart-presentation-check` and builds the visual-review harness, but those
Gradle modules are not product HOME implementations.

On `ai-g732`, the authoritative compiler check is Soong. The qualification
path applies and verifies the Sable presentation inside Launcher3 and runs
`m Launcher3QuickStep` as the focused HOME preflight before the combined
Dialer/Contacts/application/Settings/SystemUI module gate.

`build/panther/build-sablestart.sh` is obsolete and must remain absent. The
canonical preparation and qualification entry points are
`prepare-r8-final-ui.sh`, `build-r8-final-ui.sh`, and
`qualify-r9-physical-ux.sh`.

## Canonical vendor/sable workspace inventory

After R8 staging, `vendor/sable` is fail-closed. Only these directories are
permitted:

```text
vendor/sable/r8/
vendor/sable/r8/prebuilt/
```

The only permitted files are `Android.bp`, `r8-product.mk`,
`manifest.tsv`, `SHA256SUMS.txt`, `SABLEOS_SOURCE_COMMIT.txt`, and the
nine canonical Sable APKs. Extra files, directories, symlinks or blueprints are
qualification failures.
