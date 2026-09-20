# INFRA2C-FREE governance

SableOS keeps the canonical implementation repository private. On GitHub Free,
private repositories do not provide the same server-side branch protection and
ruleset enforcement available on paid private-repository plans.

The project now uses **local-direct CI** on the controlled build machine. GitHub
is source/PR/issue hosting only; GitHub Actions is not a qualification path.

## C1 — canonical clone push guard

The canonical build-machine clone retains its normal fetch URL but uses local
push controls. Ordinary direct updates of `main` are denied by the committed
pre-push hook. A controlled gate must use the explicit canonical SSH URL.

## C2 — committed pre-push governance hook

`.githooks/pre-push` is committed with executable mode and enabled in the
canonical clone through `core.hooksPath=.githooks`.

For `refs/heads/main`, the hook denies deletion, creation, ordinary pushes,
wrong old/new authorities, non-fast-forward updates, governed pushes containing
more than the single main ref update, and pushes without source-bound local CI
evidence.

A governed main update must provide:

```text
SABLEOS_GOVERNED_MAIN_PUSH=YES
SABLEOS_EXPECTED_MAIN_OLD_SHA=<exact current main>
SABLEOS_EXPECTED_MAIN_NEW_SHA=<exact qualified target>
```

and must use the explicit canonical SSH URL.

The exact candidate commit must also have:

```text
.git/sable-local-ci/<commit>.pass
```

created by a successful:

```bash
bash build/local-ci/run.sh full
```

or:

```bash
bash build/local-ci/run.sh release
```

The attestation must contain `SABLE_LOCAL_CI=PASS`, the exact source commit,
and a `full` or `release` profile.

## C3 — controlled main mutation gate

C3 is the only intended operational path for moving `main`. The exact
candidate head must complete local full qualification first.

## C4 — GitHub Actions disabled

The previous hosted post-push integrity workflow has been retired for cost
containment. No executable `.yml` or `.yaml` file is permitted under
`.github/workflows`.

This removes the old hosted post-push detection layer. The project accepts that
trade-off explicitly and compensates with source-bound local qualification plus
the committed pre-push guard.

## Limitations

A writer can intentionally bypass local hooks with `--no-verify`, change local
Git configuration, use another clone, or invoke GitHub through another write
path. Local-direct CI does not provide server-side branch protection.

```text
GITHUB_ACTIONS_CI=DISABLED
GITHUB_SERVER_SIDE_MAIN_PROTECTION=NO
LOCAL_DIRECT_CI=REQUIRED
LOCAL_FULL_CI_ATTESTATION_FOR_MAIN=REQUIRED
COMMITTED_LOCAL_PRE_PUSH_GOVERNANCE=YES
CONTROLLED_MAIN_MUTATION_GATE=REQUIRED
```
