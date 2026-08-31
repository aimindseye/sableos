# Panther P1B Android 17 host bring-up status

Status: **IN PROGRESS / GRAPHENEOS-COMPATIBILITY CONTRACT CLOSURE / NO PRODUCT BUILD OR FLASH**

This document records the active Pixel 7 (`panther`) Android 17 host bring-up which follows `PANTHER_P0`, `PANTHER_P0R1`, and `PANTHER_P1A`.

It is an evidence/status record, not a declaration that `PANTHER-P1B / V0-HOST` is closed. The current work has been limited to making the audited Pixel-generation toolchain operate in a separate pure-AOSP Android 17 workspace while preserving Sable's decision that GrapheneOS is a reference/security source rather than the Sable OS substrate.

## Active target and workspace

```text
device: Pixel 7 / panther
Android release: 17 / SDK 37
stock Pixel input: CP2A.260705.006
workspace: /srv/data/aosp_panther17_workspace
```

The factory input used by the generator is sealed as:

```text
vendor/adevtool/dl/panther-cp2a.260705.006-factory-ed94a24e.zip
sha256=ed94a24e693a28f236e87c9e03436871c2dd6b03b4b56c5839598115d0372b0b
```

Core source pins repeatedly retained across the current host gates:

```text
manifest=29ace668ae756c7b8917c57abb440f6518844b0c
adevtool=5019450d9235c48a987250c890e346b416f8dfd4
arsclib=a67388430c8319f4c7066626e340b5c4d7f27882
frameworks_base=94b4c163b7dfe5ce3607f7bb8456f9573f7de57d
apksig=179f60df00d242f6bb22acf828b0884eac2d5f72
vendor_state=d69d029d7fe3745049e80ad64ad1967a9cac8e5f
```

These are repository commit seals. The full resolved AOSP project-manifest closure required by P1B remains part of the later host-baseline closure and is not implied solely by the manifest-repository SHA above.

## GrapheneOS relationship

The compatibility work does **not** adopt GrapheneOS as the operating-system substrate.

The current model is:

```text
pure AOSP Android 17 workspace
        |
        +-- pinned stock Pixel 7 factory input
        +-- audited/pinned adevtool + arsclib generation references
        +-- narrowly imported host-tool contracts required by those tools
        |
        X  no wholesale GrapheneOS manifest/platform adoption
        X  no GrapheneOS application inheritance
        X  no automatic GrapheneOS policy/product-hook inheritance
```

The host patches are reviewed compatibility contracts needed because current GrapheneOS `adevtool` / `arsclib` expect host-tool extensions that are absent from pure AOSP. They are not a change to the Sable substrate decision recorded by ADR-0003 and P1A.

## Host runtime closure

Adevtool branch 17 requires Node 24 or later and prepends the Android 17 JDK 21 prebuilt for its child tools.

The isolated host Node runtime is:

```text
/srv/data/sable-host-tools/node-v24.20.0-linux-x64
node=v24.20.0
npm=11.19.0
archive sha256=2f2c0da162318f0de47665410c7c8c2ed3d36c8f3105de4bbc61176c70a7cbf2
```

The Android workspace JDK used by adevtool is:

```text
prebuilts/jdk/jdk21/linux-x86/bin/java
OpenJDK 21.0.4
```

The host runtime correction was kept isolated; the host system Java/Node installation was not globally replaced.

## AAPT2 compatibility contracts proven before the current blocker

### `aapt2_proto_java`

Pure AOSP lacked the host Java proto module required by the Graphene-derived host dependency graph. A minimal host module was added in `tools/aapt2/Android.bp` and the host dependency build advanced.

### Stringified resource configuration

GrapheneOS commit:

```text
e32622a9af583b1cf73555fb985b49e0f73223f7
aapt2: add stringified resource configuration to Configuration.proto
```

The required contract spans:

```text
tools/aapt2/Configuration.proto
tools/aapt2/cmd/Convert.h
tools/aapt2/format/proto/ProtoSerialize.cpp
```

After the patch, the controlled adevtool host-dependency build succeeded, including `aapt2`, `arsclib`, and `arsclib.jar`.

### `dump brief-package-info`

GrapheneOS commits:

```text
7b672d6832764cf122456a9ae383445dcfe88c73
aapt2: add "dump brief-package-info" command

255257eb3a8ccaef7787e462ee27da6cf9b37538
aapt2: add library element to brief-package-info
```

The rebuilt host `aapt2` accepted the previously failing command against the exact factory-image APK:

```text
dump brief-package-info --sdk-version 37
```

The protobuf output decoded successfully and the original `unknown option '--sdk-version'` failure was cleared.

The retained eight-file AAPT2 source delta at that point was:

```text
tools/aapt2/Android.bp
tools/aapt2/BriefPackageInfo.proto
tools/aapt2/Configuration.proto
tools/aapt2/cmd/Convert.h
tools/aapt2/cmd/Dump.cpp
tools/aapt2/cmd/Dump.h
tools/aapt2/format/proto/ProtoSerialize.cpp
tools/aapt2/format/proto/ProtoSerialize.h
```

## ApkSigner `print-certs` compatibility closure

Adevtool's sepolicy processing requires:

```text
apksigner print-certs --min-sdk-version 37 --max-sdk-version 37
```

Pure-AOSP `apksigner` did not provide that command.

The exact GrapheneOS apksig compatibility commit was identified and applied:

```text
ba4d984e1a360d427307d669d2f789212130e9e8
add print-certs apksigner command for adevtool
```

Exact six-file source scope:

```text
Android.bp
src/apksigner/java/com/android/apksigner/ApkSignerTool.java
src/main/java/com/android/apksig/ApkVerifier.java
src/main/java/com/android/apksig/internal/apk/Flags.java
src/main/java/com/android/apksig/internal/apk/v2/V2SchemeVerifier.java
src/main/java/com/android/apksig/internal/apk/v3/V3SchemeVerifier.java
```

The host `apksigner` rebuild succeeded. A first direct test failed because it was launched under an unrelated Java 17 shell environment; this was a test-harness/runtime mismatch rather than an apksig repair failure.

The corrected test mirrored adevtool's JDK 21 runtime and passed:

```text
print_certs_rc=0
stderr=EMPTY
stdout=568c50114b56d8a167865b4afd28078f14e3fe0268ad894ee65479cd8e1f8dbf
```

The rebuilt jar seal retained by the subsequent controlled generator preflight was:

```text
out_adevtool_deps/host/linux-x86/framework/apksigner.jar
sha256=6b96559764325d085a6bad6be109cc3053791d63826f84dc0e74032db136a196
```

## Controlled `generate-all` progress

All generator retries use:

```text
ADEVTOOL_SKIP_DEP_BUILD=1
vendor/adevtool/bin/run generate-all -d panther -v
```

They do **not** use `--updateSpec` or `--noVerify`, and the existing partial vendor output is not manually deleted. Adevtool itself recreates the output directory at normal generation start.

The generator has advanced through:

```text
Extracting properties
Enumerating files
Processing sepolicy
Processing overlays
Marking apps as presigned
Copying blobs
Extracting vintf manifests
Extracting firmware
```

This proves that the earlier Node, AAPT2 proto-module, stringified configuration, brief-package-info, and apksigner `print-certs` blockers have been crossed without regression.

The generator has **not** yet reached FileTreeSpec verification or the final `Generated vendor module at ...` success marker.

Therefore the current `vendor/google_devices/panther` directory remains partial evidence, not a completed generated vendor module.

Latest sealed partial state before the proto-adevtool repair closure:

```text
vendor_files=2907
vendor_dirs=119
size=983M
version_check_file=ABSENT
FileTreeSpec verification=NOT_PROVEN
generated vendor module=NOT_PROVEN
```

## Current AAPT2 / arsclib compatibility boundary

The next generator blocker was:

```text
arsclib --json-stdin
  -> aapt2 convert --for-adevtool --output-format proto-adevtool
  -> Invalid value for flag --output-format: proto-adevtool
```

Current GrapheneOS `arsclib` explicitly expects the optimized `proto-adevtool` conversion mode.

Diagnostic gate `PANTHER-P1B-2F8AA` closed with:

```text
PANTHER_P1B2F8AA_PROTO_ADEVTOOL_CLOSURE=PASS
PRIMARY_CAUSE=GRAPHENE_AAPT2_PROTO_ADEVTOOL_CONTRACT_MISSING_FROM_PURE_AOSP
REQUIRED_UPSTREAM=f18597e43abd313efb82d349c0cd425dd6ca3389
```

Exact upstream commit:

```text
f18597e43abd313efb82d349c0cd425dd6ca3389
aapt2: add optimized proto-adevtool APK conversion format
```

It touches only:

```text
tools/aapt2/cmd/Convert.cpp
tools/aapt2/cmd/Convert.h
```

The diagnostic patch seal is:

```text
sha256=c33e44d4d5ed2a7e3c4edc25f82269bb49d79d5ad3c64235153514b53defd3a2
```

A produced proto-adevtool APK artifact has separately passed file binding, ZIP integrity, CRC, required-entry cardinality, and a fail-closed validator self-test:

```text
/tmp/PANTHER_P1B2F8AB_PROTO_ADEVTOOL.apk
sha256=0fe53f43776333292e49aa4bd44964d3bdc87d1389155d4c322b66baf0f55378
size=43240626
entries=8367
resources.pb count=1
AndroidManifest.xml count=1
ZIP CRC=PASS
```

The validator repair package also passed its manifest and six negative/positive self-tests. This validates the artifact-structure checker, but this document intentionally does **not** promote the entire `PANTHER-P1B-2F8AB` repair gate to PASS without its complete main-gate source/build/runtime output being recorded.

## Current classification

```text
PANTHER_P0=PASS
PANTHER_P0R1=PASS
PANTHER_P1A=PASS

PANTHER_P1B_ANDROID17_WORKSPACE=ACTIVE
PANTHER_P1B_GRAPHENEOS_OS_SUBSTRATE=NO
PANTHER_P1B_GRAPHENEOS_REFERENCE_COMPATIBILITY=BOUNDED_HOST_TOOL_CONTRACTS

PANTHER_P1B_AAPT2_PROTO_MODULE=PASS
PANTHER_P1B_AAPT2_STRINGIFIED=PASS
PANTHER_P1B_AAPT2_BRIEF_PACKAGE_INFO=PASS
PANTHER_P1B_APKSIGNER_PRINT_CERTS=PASS
PANTHER_P1B_AAPT2_PROTO_ADEVTOOL_DIAGNOSTIC=PASS
PANTHER_P1B_AAPT2_PROTO_ADEVTOOL_REPAIR=IN_PROGRESS_NOT_YET_RECORDED_AS_FULL_PASS

PANTHER_P1B_FILETREESPEC_VERIFY=NOT_PROVEN
PANTHER_P1B_VENDOR_MODULE_GENERATED=NOT_PROVEN
PANTHER_P1B_VANILLA_PRODUCT_BUILD=NOT_PERFORMED
PANTHER_V0_PHYSICAL_ACCEPTANCE=NOT_STARTED
```

## S1.8C sequencing guard

Bramble remains frozen and must not be reopened for S1.8C production work.

S1.8C is a **Panther / Android 17** milestone, but it is not the immediate next implementation gate while P1B is still open.

Required sequence:

```text
PANTHER-P1B / V0-HOST
  -> finish audited vendor generation
  -> FileTreeSpec verification
  -> generated-vendor audit / GrapheneOS-hook decoupling
  -> vanilla Panther product build closure

PANTHER-V0
  -> vanilla hardware + Android application compatibility acceptance

S1.7 semantic service port to Panther
  -> qualify Android 17 / GS201 Health AIDL adapter
  -> preserve frozen Sable PowerSnapshot/AIDL V1 semantics
  -> prove authorization and runtime behavior

S1.8 / S1.8C
  -> modern UI framework qualification
  -> first standalone Sable power client
  -> UI consumes frozen semantic service only
```

S1.8C must not bypass the service boundary. The production UI remains forbidden from direct Health HAL access, battery sysfs access, and shell/Binder-command shortcuts.

## Safety boundary retained during current P1B work

```text
Android product build performed: NO
image flash performed: NO
device touched by P1B compatibility gates: NO
--updateSpec used: NO
--noVerify used: NO
manual partial-vendor deletion: NO
GrapheneOS wholesale platform adoption: NO
```

## Next evidence boundary

Close the exact `proto-adevtool` AAPT2 repair using the already reviewed two-file patch and targeted host-AAPT2/runtime validation. Only after that closure should `generate-all` be retried.

If generator success reaches FileTreeSpec verification, treat any mismatch as a separate diagnostic gate rather than using `--updateSpec` automatically.

S1.8C remains blocked until the Panther baseline and S1.7 semantic-service port sequence above is closed.
