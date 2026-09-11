# Portable SableOS development

The SableOS repository is the canonical location for Sable-owned source, tests and build orchestration. GrapheneOS/AOSP and Pixel proprietary vendor inputs remain external upstream inputs.

## Standard new-machine layout

Use `/srv/data/sableos` by default, or override `SABLEOS_ROOT` (for example `SABLEOS_ROOT=/sableos`).

```text
/srv/data/sableos/repo
/srv/data/sableos/upstream/panther/grapheneos-2026081300
/srv/data/sableos/build/panther/grapheneos-2026081300
/srv/data/sableos/evidence/panther
/srv/data/sableos/host-tools
```

Clone this repository into `repo`, then use `build/panther/bootstrap.sh` to create the exact GrapheneOS 2026081300 upstream checkout. Follow `docs/BUILD_PANTHER_GRAPHENE_2026081300.md` for signed-tag verification and Pixel vendor provisioning.

After the canonical SableStart snapshot is complete, use `build/panther/sync-sablestart.sh`, run the host/static gates, and use `build/panther/build-sablestart.sh` for the module-only build. Use `build/panther/build-target-files.sh` for the full Panther target-files set when separately authorized.

## Current portability gap

The repository already contains the build layout, orchestration, tests, R3 live-data model/repository, launcher repository, manifest, module definition and root UI source. The following known files still need full-text transfer from the validated workspace:

```text
src/com/sable/start/ui/SableMetroPreviewActivity.kt
res/values/strings.xml
src/com/sable/start/SableStartActivity.kt
src/com/sable/start/bridge/SableStartNative.kt
src/com/sable/start/model/AppEntry.kt
rust/src/lib.rs
```

The first five have known expected hashes recorded in `src/android/packages/apps/SableStart/PORTABILITY_STATUS.md`. The Rust file was omitted by the earlier narrow capture and must be hash-bound during the complete-tree capture. The full module capture is authoritative and may reveal additional resources or source assets.

On the validated machine, run `build/panther/capture-sablestart.sh` against the current `packages/apps/SableStart` directory, review the Git diff, then run `build/panther/verify-sablestart-snapshot.sh`. The verifier recursively compares both module trees and requires zero missing files, zero extra source files and zero hash mismatches before portability is closed.

The sync script deliberately refuses to run while required source is missing. Only after the recursive verifier passes should the snapshot be merged to `main` and described as reproducible on another machine.
