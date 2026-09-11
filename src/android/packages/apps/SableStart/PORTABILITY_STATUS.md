# SableStart portable snapshot status

R3 source files currently committed in full under this directory:

```text
Android.bp
AndroidManifest.xml
src/com/sable/start/platform/LauncherAppsRepository.kt
src/com/sable/start/platform/LiveSurfaceRepository.kt
src/com/sable/start/live/LiveSurfaceModels.kt
src/com/sable/start/ui/SableStartRoot.kt
```

The exact R3 `SableMetroPreviewActivity.kt` is captured and hash-bound in the validated workspace, but its full text has not yet been transferred into this repository snapshot. Expected hash:

```text
src/com/sable/start/ui/SableMetroPreviewActivity.kt
  sha256=12db1f5a6fc6584dd462395d5f30f44d8980c4edd92b901bb52f9cb921eca1a2
```

Exact unchanged baseline files also still awaiting full-text capture/transfer:

```text
res/values/strings.xml
  sha256=1d3cf2ca93d0d8cbafad5692ff199c127fc61293ab8454d4a1646e5bd21feabe

src/com/sable/start/SableStartActivity.kt
  sha256=9c3b34bfa79c374eae3d54edb0ad4f69f2ae7572a47af34362f386f5e4777ab6

src/com/sable/start/bridge/SableStartNative.kt
  sha256=3b889631b757674aa9343cd4a329697edf99dc57623d640aa13c2aade79425e0

src/com/sable/start/model/AppEntry.kt
  sha256=5da0f28b726910a9095ce28d5f7f07c3839ea3c9b497c0033e6c6ac01274e8fe
```

`build/panther/sync-sablestart.sh` deliberately refuses to sync until the complete module is present. Do not claim the repository alone can reconstruct the complete SableStart module until these five files are committed.
