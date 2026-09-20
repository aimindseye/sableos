# Local CI

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
syntax, product/build-driver static gates, Rust correctness, Android
compile/tests/lint, quality/coverage tasks and deterministic supply-chain
evidence.

`full` adds Rust dependency policy, Gitleaks, MobSFScan and pinned Reader,
Text Reader and Mail qualification. Cargo security tools and Gitleaks are
installed into the persistent local cache from the committed checksum lock;
MobSFScan is built in a cached Python virtual environment from the exact commit
previously used by the Actions workflow. Upstream checkouts and tool downloads
are network-disabled by default, so the first cache population should be run
explicitly with:

```bash
SABLE_LOCAL_CI_ALLOW_NETWORK=YES bash build/local-ci/run.sh full
```

Subsequent runs can use the persistent
`/srv/data/sable-build/sableos/local-ci-cache` cache offline.

`release` runs `full` and then the source-bound Panther release-candidate
driver.

Evidence defaults to:

```text
/srv/data/sable-build/sableos/local-ci-evidence/<run-id>/
```

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
