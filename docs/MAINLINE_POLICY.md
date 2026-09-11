# Mainline and branch policy

`main` is the only canonical SableOS product-development line.

## Rules

1. Every product/source/documentation change enters `main` through a pull request.
2. Feature and validation branches are temporary transport, not archival storage.
3. A branch may be deleted after its PR is merged once any unique evidence that must
   be retained has been committed to `main`.
4. Never continue active development from an old validation branch.
5. Before a release or large milestone, compare every remaining branch to `main`.
   Do not merge a branch merely because it is "ahead"; old branches can contain
   obsolete commits that were independently superseded on main.
6. Tags, signed release manifests, evidence hashes and validation documents are the
   durable historical record. Long-lived branches are not.
7. `main` should be protected in GitHub settings with pull-request review/status
   checks and force-push/deletion disabled when the repository policy permits it.

## Branch audit on 2026-09-11

The repository default branch is `main`.

Observed branch state before this update:

```text
docs/mediatek-brax3-titan2-20260910  ahead 0, behind 1   fully integrated
sablectl-v0.1-clean                  ahead 0, behind 17  fully integrated
sablectl-v0.1                        ahead 1, diverged   obsolete; do not merge blindly
panther-d4-r0-roadmap                ahead 3, diverged  content spot-check matches main; audit before deletion
panther-d3-validated-20260907        ahead 17, diverged validated files spot-check match main; audit before deletion
```

The `panther-d4-r0-roadmap` copy of `docs/PANTHER_D4_R0_PLAN.md` and the
`panther-d3-validated-20260907` copy of
`docs/BUILD_PANTHER_GRAPHENE_2026081300.md` were spot-checked and have the same
blob IDs as `main`. The remaining divergent commits should be treated as an audit
queue, not merged wholesale.

## Preferred branch naming

```text
m1/<feature>-YYYYMMDD
fix/<area>-YYYYMMDD
docs/<topic>-YYYYMMDD
release/<milestone>
```

Keep branches short-lived. The PR merge commit or squash commit on `main` is the
canonical handoff.
