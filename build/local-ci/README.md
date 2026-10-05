# Local CI

The canonical operator entry point is now device/release/function based:

```bash
bash build/sable.sh panther R9 ci core
bash build/sable.sh panther R9 ci full
bash build/sable.sh panther R9 ci release
```

Direct `build/local-ci/run.sh` invocation remains the implementation-level interface.

SableOS CI executes directly on the controlled build machine. GitHub Actions is
not part of the qualification path.

This is intentionally **not** a GitHub self-hosted runner. The development
storage remains unencrypted and the existing INFRA4 policy continues to forbid
remote Actions runner activation. Local CI is started by the developer from the
canonical clone, so GitHub cannot remotely execute pull-request code on the
build host.

## Profiles

```bash
bash build/local-ci/run.sh core
bash build/local-ci/run.sh full
bash build/local-ci/run.sh release
```

`core` runs repository policy/layout, host-tool verification, shell/Python
syntax, product/build-driver static gates, the active Media and Messages
source/architecture gates, Rust correctness, Android compile/tests/lint,
quality/coverage tasks and deterministic supply-chain evidence. The Python
syntax pass scans the complete maintained Python set in one batch and reports
all parser failures before failing STATIC, rather than stopping at the first
file. Applicator `--self-test` executions are also aggregated so STATIC
reports every failing active applicator before returning failure. The remaining
source/product contract checks use the same aggregation rule, so one STATIC run
reports all failing maintained contracts before the stage exits. Failed contract
names are repeated in the final
`SABLE_LOCAL_CI_STATIC_CONTRACT_FAILURE_NAMES=<comma-separated names>` marker
for concise triage.

`full` adds Rust dependency policy, Gitleaks, MobSFScan and separate pinned
Reader, Text Reader and Mail qualification. Reader is the publication product;
Text Reader is independently flavored, tested, linted, assembled and APK-verified
as `org.sableos.textreader`. It is the pre-image source/build/security CI
profile and does not authorize a Panther image build by itself.

STATIC no-stale checks run in pre-staging mode. They still reject retired source,
product modules and legacy workspace trees, but they do not require the existing
Android workspace to already contain the APK inventory produced by the source
being qualified. Exact `vendor/sable` inventory is re-enabled after the
release-candidate path stages the source-bound bundle.

The source-bound Launcher visual acceptance seal is intentionally not part of
`full`. Visual acceptance is an image-authorization gate and is required by the
`release` profile and the full Panther product-composition path. This allows
new source to compile and pass CI before a fresh visual review without weakening
the rule that no image build proceeds from stale visual acceptance.

For R9 Panther work, the canonical pre-image sequence is:

```bash
bash build/sable.sh panther R9 ci full
bash build/sable.sh panther R9 qualify physical-ux
```

The first command proves the full source/build/security CI profile. The second
proves the source-bound Panther module/product-composition path while keeping
`FULL_TARGET_FILES_BUILD_AUTHORIZED=NO`. Do not enter the release build /
target-files path until both pass for the same source commit.

## One host toolchain

Build and CI use the same canonical host-tool profile:

```text
build/config/r8-host-tools.env
/srv/data/sable-host-tools
```

The canonical host gate covers Android SDK/NDK, Rust/Cargo/Rustup, Rust Android
target/components, JDKs, Gradle state and the security/coverage toolchain.
Local CI is verification-only for host tooling: it must not download pinned
CLI tools, run `rustup component add`, create Python virtual environments or
run `pip install`.

The native security tools are version-locked by
`build/supply-chain-lock.json` and exposed through
`/srv/data/sable-host-tools/security/bin`. MobSFScan uses one shared
host executable and a pinned source checkout for provenance.

Before changing the host, inventory what is already available:

```bash
bash build/host/audit-r8-host-tools.sh
```

To centralize exact existing tools from stable PATH locations or prior local-CI
cache state without network access or package installation:

```bash
HOST_TOOL_CENTRALIZATION_AUTHORIZED=YES \
  bash build/host/centralize-r8-security-tools.sh
```

If the audit shows genuinely missing canonical prerequisites, bootstrap them
once into `/srv/data/sable-host-tools`. This is host maintenance, not CI:

```bash
HOST_TOOL_BOOTSTRAP_AUTHORIZED=YES \
HOST_PACKAGE_INSTALL_AUTHORIZED=YES \
NETWORK_FETCH_AUTHORIZED=YES \
  bash build/host/bootstrap-r8-host-tools.sh
```

The bootstrap installs only missing Rust coverage components into the pinned
Rust toolchain and creates one canonical MobSFScan runtime under the pinned
MobSFScan source root. It records an installation manifest and immediately
runs the canonical host verification gate.

Then verify the single shared toolchain:

```bash
bash build/host/verify-r8-host-tools.sh
```

Only after that gate passes may duplicate local-CI tool caches be removed:

```bash
HOST_TOOL_CLEANUP_AUTHORIZED=YES \
  bash build/host/cleanup-r8-host-tool-duplicates.sh
```

Network authorization in local CI applies only to pinned source/upstream
retrieval such as Reader, Text Reader and Mail when those source caches are
missing. It does not authorize host-tool installation.

`release` runs `full`, requires the source-bound Launcher visual acceptance
seal, and only then enters the Panther release-candidate driver. Do not use the
`release` profile for pre-image compile qualification while visual acceptance is
pending; use `ci full` followed by `qualify physical-ux`.

Evidence defaults to:

```text
/srv/data/sable-build/sableos/local-ci-evidence/<run-id>/
```

Every run also generates and prints a terminal-safe final summary:

```text
/srv/data/sable-build/sableos/local-ci-evidence/<run-id>/LOCAL_CI_SUMMARY.txt
```

The summary is emitted on both PASS and FAIL and appears after the normal CI
output so terminal scrollback limits do not hide the qualification markers that
matter most. It includes source/profile/device identity, stage PASS/FAIL state,
high-value contract/regression markers, Titan 2 N1I Android-16 markers when
applicable, full/release security markers, and the evidence/summary paths. The
summary is intentionally concise and does not replace `local-ci.log`; the full
log remains the authoritative detailed evidence.

The log transport is closed and fully drained before the summary parser runs, so
`LOCAL_CI_SUMMARY.txt` is generated only from a complete `local-ci.log`.
Dirty-source failures are inside the same final-summary lifecycle. If log capture
or summary generation fails after the CI work itself would otherwise return zero,
the final CI exit status is nonzero rather than reporting a false success.

`build/local-ci/test-final-summary-lifecycle.sh` extracts the production
`emit_final_summary()` function and regression-tests dirty-source summary
generation, complete tee drain, preservation of an existing nonzero exit, and
summary-generation failure propagation. CI policy runs this host-only test.


A successful `full` or `release` run also writes a source-bound local
attestation under `.git/sable-local-ci/<commit>.pass`. The committed pre-push
hook requires that attestation before a governed update of `main`.

## Cost boundary

The repository contains no executable files under `.github/workflows`.
GitHub is used for source hosting, PR review and issue tracking only. No hosted
Actions job, artifact upload, scheduled scan or self-hosted Actions runner is
part of CI.

The old workflow definitions remain recoverable from Git history if a future
infrastructure decision restores hosted CI.
