# Canonical SableOS source and build layout

Status: adopted for new work on 2026-09-11.

## Goal

Sable-owned source must live in the SableOS repository. Android/GrapheneOS workspaces are
disposable upstream substrates, not the canonical location of Sable code.

The previous pattern of creating milestone-specific directories such as
`/srv/data/sableos_panther_graphene_2026081300_workspace` is useful for forensic
qualification, but it is poor as the permanent developer interface. It encourages
source drift, makes another-machine reproduction harder, and obscures which files
belong to Sable versus upstream.

## Standard local layout

The default root is `/srv/data/sableos`, overridable with `SABLEOS_ROOT`.

```text
/srv/data/sableos/
├── repo/                         # clone of aimindseye/sableos; canonical Sable source
├── upstream/
│   └── panther/
│       └── grapheneos-2026081300/ # repo-synced GrapheneOS checkout
├── build/
│   └── panther/
│       └── grapheneos-2026081300/ # OUT_DIR; generated build products only
├── evidence/
│   └── panther/                  # build logs, manifests, hashes, qualification evidence
└── host-tools/                   # pinned host tools such as Node when required
```

Inside the Git repository:

```text
sableos/
├── src/                          # Sable-owned product/platform source
│   └── android/packages/apps/SableStart/
├── build/
│   ├── config/                   # immutable-ish target configuration
│   ├── panther/                  # bootstrap/sync/build entry points
│   └── gates/                    # qualification gates
├── tests/
│   └── sablestart/
├── patches/                      # bounded deltas to upstream projects
├── docs/
└── CURRENT_STATUS.md
```

## Source of truth

`main` in `aimindseye/sableos` is the source of truth for Sable-owned source,
tests, build orchestration and documentation.

The upstream GrapheneOS checkout is recreated from its signed release tag. Generated
build output never becomes source of truth and is never committed.

For Sable-owned modules, edit the Git repository first, test there, then sync into
the upstream workspace with an explicit source-mutation authorization.

## Recommended flow

```text
GitHub main
   -> clone /srv/data/sableos/repo
   -> bootstrap exact GrapheneOS tag
   -> provision vendor inputs
   -> sync Sable-owned source into upstream tree
   -> host/static gates
   -> module Soong gate
   -> full product build when authorized
   -> package/image/device gates
   -> merge validated change back to main
```

A build result is evidence, not source.

## Why this is better

- one stable path across machines;
- clear ownership boundary between Sable and GrapheneOS;
- portable Sable-owned source;
- reproducible upstream bootstrap;
- generated output cannot silently become canonical;
- tests live beside the source they qualify;
- evidence has a stable location;
- feature branches can be deleted after merge without losing validated source.
