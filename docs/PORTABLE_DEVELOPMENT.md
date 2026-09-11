# Portable SableOS development

The SableOS repository is the canonical location for Sable-owned source, tests and build orchestration. GrapheneOS/AOSP and Pixel proprietary vendor inputs remain external upstream inputs.

## Standard new-machine layout

Use `/srv/data/sableos` by default, or override `SABLEOS_ROOT`.

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

The repository already contains the build layout, orchestration, tests, R3 live-data model/repository, launcher repository, manifest, module definition and root UI source. Five exact source files still need full-text transfer from the validated workspace before the repository alone can reconstruct SableStart:

```text
src/com/sable/start/ui/SableMetroPreviewActivity.kt
res/values/strings.xml
src/com/sable/start/SableStartActivity.kt
src/com/sable/start/bridge/SableStartNative.kt
src/com/sable/start/model/AppEntry.kt
```

Their expected hashes are recorded in `src/android/packages/apps/SableStart/PORTABILITY_STATUS.md`. The sync script deliberately refuses to run while the snapshot is incomplete.

Use `build/panther/capture-sablestart.sh` on the validated workspace to capture the complete module, review the resulting Git diff and hashes, and commit the remaining files to `main`. Once those five files are present, another machine can reconstruct the full SableStart module from this repository plus the exact upstream GrapheneOS and vendor inputs.
