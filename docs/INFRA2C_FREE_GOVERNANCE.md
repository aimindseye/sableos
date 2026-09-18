# INFRA2C-FREE governance

SableOS keeps the canonical implementation repository private. On GitHub Free,
private repositories do not provide the same server-side branch protection and
ruleset enforcement available on paid private-repository plans.

INFRA2C-FREE therefore provides layered local prevention plus hosted detection.
It is deliberately documented as weaker than server-side branch protection.

## C1 — canonical clone push guard

The canonical AI-G732 clone retains its normal fetch URL but has a local push
URL of `/dev/null`, `push.default=nothing`, and the
`C1_FREE_ORIGIN_PUSH_DISABLED_V1` marker.

This prevents ordinary pushes through the `origin` remote while preserving
fetches. A controlled gate can still use the explicit canonical SSH URL.

## C2 — committed pre-push governance hook

`.githooks/pre-push` is committed with executable mode and enabled in the
canonical clone through `core.hooksPath=.githooks`.

For `refs/heads/main`, the hook denies deletion, creation, ordinary pushes,
wrong old/new authorities, non-fast-forward updates, and governed pushes that
contain more than the single main ref update.

A governed main update must provide:

```text
SABLEOS_GOVERNED_MAIN_PUSH=YES
SABLEOS_EXPECTED_MAIN_OLD_SHA=<exact current main>
SABLEOS_EXPECTED_MAIN_NEW_SHA=<exact qualified target>
```

and must use the explicit canonical SSH URL.

## C3 — controlled main mutation gate

C3 is the only intended operational path for moving `main`. It is created and
run only after the exact candidate head has completed hosted CI qualification.

## C4 — hosted post-push main integrity detection

`.github/workflows/main-integrity.yml` runs on every push to `main`.

It uses full-history checkout and rejects evidence of a non-fast-forward main
transition. It also reruns the repository CI trust policy and requires the
committed governance files to remain present.

This is detection after GitHub accepts a push. It is not a substitute for
server-side branch protection.

## Limitations

A writer can intentionally bypass local hooks with `--no-verify`, change local
Git configuration, use another clone, or invoke GitHub through another write
path.

```text
GITHUB_SERVER_SIDE_MAIN_PROTECTION=NO
LOCAL_ACCIDENTAL_PUSH_PROTECTION=YES
COMMITTED_LOCAL_PRE_PUSH_GOVERNANCE=YES
CONTROLLED_MAIN_MUTATION_GATE=REQUIRED
POST_PUSH_MAIN_INTEGRITY_DETECTION=YES
```
