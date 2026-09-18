# SableStart portable snapshot status

Status: **portable snapshot closed for the current qualified R6 source set**.

The canonical SableOS repository now contains the complete build-required
SableStart source set needed by `build/panther/sync-sablestart.sh`.

The six files which were previously missing from the canonical snapshot were
recovered from the tracked SableStart Git checkout at:

```text
repository: sableos-project/packages_apps_SableStart
commit: f705e875b3339ac1019429cac6df157257746660
commit subject: R6: declare launcher package visibility
```

The ai-g732 Panther workspace proved each file was tracked and byte-identical
to that exact Git commit before capture.

## Captured build-required files

```text
res/values/strings.xml
  git_blob=109c783128ea904931f55b1809234fda57d757b6
  sha256=1d3cf2ca93d0d8cbafad5692ff199c127fc61293ab8454d4a1646e5bd21feabe

rust/src/lib.rs
  git_blob=55cb820c620c280ad6a6b952557c472fb6e72bc6
  sha256=27601dea645045b1688d40f301590613fb677aca51e4b980ec6878c3b09e90af

src/com/sable/start/SableStartActivity.kt
  source_component_blob=c78afae6e49655e61b2946b298225b75039de9ca
  source_component_sha256=405c13177866b84cedbf51c204ba5c192d8e090470651c311c4e66f116ff72d5
  canonical_ui1_sha256=1f14cfd6ff38b81dd17e0e8202ce9e5b4b098906af8d600be3f2df2a06e2ee66
  note=adapted forward to the UI1 SableStartRoot(repository) and slim LauncherAppsRepository contract

src/com/sable/start/bridge/SableStartNative.kt
  git_blob=da028fc0c8ddb7796df1e45b8c3dd5afcb7f6e5e
  sha256=3b889631b757674aa9343cd4a329697edf99dc57623d640aa13c2aade79425e0

src/com/sable/start/model/AppEntry.kt
  git_blob=1166e74fddb94232bf3a594101eb7bbff61587e8
  sha256=5da0f28b726910a9095ce28d5f7f07c3839ea3c9b497c0033e6c6ac01274e8fe

src/com/sable/start/ui/SableMetroPreviewActivity.kt
  git_blob=4d2209fd04b69bd8b46a86cd323991b16562d62e
  sha256=dde4196f82ea4357cfdef5a78fe0d9824971d93e52ee6886923c6be245f1f249
```

The earlier portability-note hashes for `SableStartActivity.kt` and
`SableMetroPreviewActivity.kt` were stale relative to the later qualified R6
component commit above. They have been superseded by the identities recorded
here.

## Current canonical source

The canonical snapshot also retains the current Sable-owned UI1/R3 source
already present in this repository, including:

```text
Android.bp
AndroidManifest.xml
src/com/sable/start/platform/LauncherAppsRepository.kt
src/com/sable/start/platform/LiveSurfaceRepository.kt
src/com/sable/start/live/LiveSurfaceModels.kt
src/com/sable/start/ui/SableStartRoot.kt
```

Those files are not overwritten from the historical component checkout when
closing this portability gap.

## Verification

Use:

```bash
bash build/panther/verify-sablestart-snapshot.sh
```

against an intended source workspace before describing a future workspace copy
as identical to the canonical snapshot. Build-required portability is now
closed for the current captured source set; historical README/docs files from
the nested component checkout are not required product build inputs.


## UI1 compatibility adaptation

The recovered R6 `SableStartActivity.kt` was tracked and byte-identical to
component commit `f705e875b3339ac1019429cac6df157257746660`, but that Activity
targets the component repository's later callback/list-state API
(`SableStartRoot(apps, onLaunchApp)`, Boolean `launch`, and launcher callback
registration).

Canonical UI1 intentionally uses the shared-design
`SableStartRoot(repository)` surface and the slim repository contract.
Therefore the canonical Activity is a narrow adapter: it retains native JNI
lifecycle creation/destruction, constructs `LauncherAppsRepository`, and passes
that repository into the UI1 root. This avoids reverting the UI1 refresh while
keeping the recovered R6 source provenance explicit.
