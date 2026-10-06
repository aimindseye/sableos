# Titan 2 N1I-C2 Cellular MVP Implementation R1

Status: **one collision-filtered build retry permitted after full static qualification; no device contact or flash**

## Objective

Build one Android 16 Cellular MVP candidate containing the already-reviewed
Titan 2 compatibility subsystem. This is not a dependency-minimization
experiment.

The authoritative mutation set is the sealed 41-entry V5 manifest, with the
36 proprietary stock files frozen by the successful materialization run.

## Frozen stock authority

Artifact:

```text
/srv/data/sable-build/titan2/artifacts/n1i-c2-cellular-mvp-stock/
  20261005T231205Z
```

Materialization evidence:

```text
/srv/sable-build/evidence/titan2/n1i-c2-cellular-mvp-materialization/
  20261005T231205Z
```

Expected:

```text
STOCK_FILE_COUNT=36
CORE_FILE_COUNT=3
NATIVE_FILE_COUNT=33
NATIVE_HASH_COUNT=33
MUTATION_COUNT=41
```

The implementation driver verifies both seals before staging anything and
rechecks that the 33 materialized native targets equal the canonical
`product/titan2/n1i-c1/a4-native-superset.txt` set exactly.

## Product composition

C2 inherits the complete C1 OEM IMS island and the existing C3A/Restless
compatibility substrate.

It is intended to satisfy, together:

1. the exact 33 materialized A4 system/system_ext native compatibility targets.
   The first C2 packaging attempt proved that installing all 33 wholesale is
   invalid: the retained Kati graph contains five exact duplicate final targets,
   including `/system/lib64/android.hardware.drm-V1-ndk.so` (M029). The sealed
   C1 forensic probe independently proves that **all 33 targets are absent from
   C1**, so C1 is an authority boundary and not a native-provider source for
   this set. The collision-qualified plan therefore imports exactly 28 frozen
   stock natives and preserves the existing Android 16 platform provider for
   exactly five reviewed collisions. Those five are recorded in
   `product/titan2/n1i-c2/platform-native-provider.tsv`: M008 radio AIDL,
   M017 graphics-common AIDL, M029 DRM AIDL, M038 `libheif`, and M039
   `libsuspend`. Any unexpected C1 presence, owner drift, extra collision,
   unclaimed target, or ambiguous state still fails closed;
2. the reviewed two-argument TelephonyMetrics no-op overload;
3. `ro.telephony.block_binder_thread_on_incoming_calls=false` for the Titan
   product so the already-present legacy incoming-call path is active;
4. a Titan-only guard around the generic PHH `mtkmal` branch that otherwise
   disables IMS/ePDG and reboots;
5. the Sable Titan cellular integration/readiness package;
6. the bounded healer code, disabled by default.

No full stock `system`, `system_ext`, `product`, framework JAR set, or
vendor partition is imported.

## PHH guard

The generic non-Titan behavior remains present:

```text
setprop persist.mtk_ims_support 0
setprop persist.mtk_epdg_support 0
reboot
```

C2 installs:

```text
/system_ext/etc/sable/titan2-cellular-mvp
```

and the PHH patch skips that generic branch only while this marker exists.
Other GSI targets therefore retain the old behavior.

The required Android-source baseline is pinned to:

```text
device/phh/treble/phh-on-boot.sh
git_blob=9f65610762fec239638bb269b8c72d6cabfc6d7e

patch git_blob=d78f41da30514920ff2165d8fe6dea15d0bb5d76
```

## Incoming-call compatibility

No second telephony source patch is introduced.

The Restless source already contains the property-controlled legacy path. Its
source baseline is pinned to:

```text
ImsPhoneCallTracker.java
git_blob=5f97183b6f8c80859adf3f4922b3f9f56687bab5
```

C2 selects it with:

```text
ro.telephony.block_binder_thread_on_incoming_calls=false
```

## Integration / healer behavior

The one-shot boot probe runs after `sys.boot_completed=1` using the normal
shell permission surface.

It:

- queries device/carrier MMTEL ImsService binding;
- verifies the expected `com.mediatek.ims` provider;
- observes the single vendor-UA service identified by the sealed manifest;
- records the selected MTK IMS overlay state;
- writes structured state under `/data/local/tmp/sable-titan2-cellular`;
- waits for a bounded 12 × 5 seconds.

The vendor UA is **observe-only**. C2 does not force-start it.

The healer is present but disabled unless this explicit file exists:

```text
/data/local/tmp/sable-titan2-cellular-healer.enable
```

When explicitly enabled, its only permitted actions are:

- set the device IMS service to `com.mediatek.ims` if it is not already so;
- issue `cmd phone ims enable -s 0`;
- wait once and re-probe.

It has a 300-second cooldown and refuses to act when telecom state indicates an
active/emergency call.

It contains no generic RIL restart, kill loop, airplane-mode toggle, permissive
SELinux fallback, property hold loop, vendor-UA force-start, or reboot.

## Build discipline

The canonical read-only collision preflight is:

```text
build/titan2/run-n1i-c2-native-install-preflight.sh
```

It binds the sealed C1 image, the frozen C2 native materialization and the
retained failed-build Kati install graph. Its output is sealed evidence:
`NATIVE_BASELINE_PROBE.tsv`, `INSTALL_COLLISIONS.tsv`,
`NATIVE_COMPOSITION.tsv`, `native-packages.mk`, and
`native-admission.txt`.

The canonical operator build entry point is:

```bash
bash build/sable.sh titan2 N1I build --tmux
```

`build/sable.sh` dispatches through the Titan 2 adapter to the internal C2
driver `build/titan2/run-n1i-c2-cellular-mvp.sh`. Direct operator use of the
release-specific driver is not the canonical build path.

The driver starts with `NATIVE_ADMISSION_INTEGRATED=NO`. During an authorized
candidate run it must execute the complete read-only native-install preflight
**before app build, Android-source mutation, staging of the source delta, or
`make systemimage`**. Only a sealed
`PASS_CANDIDATE_ADMISSION_READY` result may transition that in-memory state to
`YES`.

The generated `native-packages.mk` contains only frozen-stock targets that the
preflight classifies as `IMPORT_FROZEN_STOCK`. For the current sealed
authority that is exactly 28 modules. C1-native reuse is exactly zero. The five
reviewed duplicate targets classify as `USE_ANDROID_PLATFORM_PROVIDER` only
when the retained Kati graph proves exactly two owners: the reviewed Sable
candidate and the exact expected Android 16 platform module. C2 `Android.bp`
therefore defines only the 28 imported Sable native modules. The five duplicate
Sable provider modules are absent from the Soong file entirely, because merely
defining them is enough for Kati to create conflicting final-target rules. The
five reviewed Android owner module names are instead added explicitly to
`PRODUCT_PACKAGES`, and the driver verifies those exact provider modules are
selected before `systemimage`. This leaves one build-side owner per target
while guaranteeing all five provider outputs are installed.

The driver requires both:

```text
--authorize-source-mutation
--authorize-build
```

and operator retry authorization remains conditional on the full static
qualification suite. The canonical native preflight is then executed by the
driver before any Android-source mutation, source-delta staging, or
`make systemimage`. A failed or ambiguous preflight aborts the run before
mutation and before the build.

Before mutation an authorized candidate run requires:

- exact SableOS source commit and clean worktree;
- the shared build-regression contract, including the native-install ownership
  invariant and singleton-driver invariant;
- a sealed native admission derived from the exact C1 baseline and the exact
  retained failed Kati graph;
- generated `native-packages.mk` containing exactly 28 admitted imports;
  the known M029 `android.hardware.drm-V1-ndk.so` duplicate-target failure is
  an executable regression fixture and must classify as
  `USE_ANDROID_PLATFORM_PROVIDER`;
- exact C3A managed-project authority;
- exact materialization and mutation-manifest seals;
- exact TelephonyMetrics, ImsPhoneCallTracker and PHH base blobs;
- exact PHH patch blob;
- fresh C2 output directory;
- implementation contract PASS.

The driver contains exactly one `systemimage` invocation and may build exactly one
collision-filtered C2 candidate after the complete static qualification suite
passes. The in-driver native preflight remains a mandatory execution gate before
source mutation and before that single build. Any native presence in sealed C1,
provider-owner drift, collision outside the exact five-entry Android provider
authority, or target that cannot be classified in one pass aborts before
mutation/build. The previous Kati error is therefore converted into pre-build
regression memory rather than rediscovered during packaging.

After the build it verifies:

- all 33 native outputs exist at the exact partition paths;
- the 28 imported native outputs retain their frozen stock SHA-256;
- the five reviewed Android 16 platform-provider outputs are present in the
  completed product image and their actual SHA-256 values are sealed into
  `ANDROID_PLATFORM_PROVIDER_OUTPUTS.tsv`; no C1 hash is used because the
  sealed C1 image contains none of these five targets;
- OEM IMS package/shared UID remain correct and the built APK certificate
  equals the platform certificate;
- both MediaTek boot JARs remain present;
- incoming-call property is present in the built system;
- integration script/init/config/marker are installed;
- built `phh-on-boot.sh` contains the Titan marker guard while retaining the
  non-Titan disable behavior;
- the Telephony MTK IMS RRO is actually present in the product output as
  `treble-overlay-telephony-mtk-ims.apk` with package
  `me.phh.treble.overlay.mtkims_telephony`;
- a 41-row implementation receipt records the realization of every frozen
  mutation ID, including M004/M005/M006/M040/M041; M008/M017/M029/M038/M039
  are explicitly recorded as `IMPLEMENTED_ANDROID_PLATFORM_PROVIDER`, while
  the 28 imported natives are recorded against their frozen-stock authority;
- system image remains within the reviewed logical-group ceiling
  `3263168512` bytes.

The driver reverses the two source patches, restores `rom.mk`, removes the
temporary `vendor/sable/titan2` staging tree and verifies the original source
blobs before sealing the artifact. An EXIT trap performs the same bounded
restore on failure and reports whether emergency restoration succeeded. The implementation receipt and frozen
mutation manifest are both copied into the final artifact so post-build and
flash qualification can bind to the same 41-entry authority.

## Execution boundary

Current collision-reconciliation phase:

```text
SOURCE_MUTATION_AUTHORIZED=YES_EXACT_C2_SET_AFTER_STATIC_GATE
BUILD_AUTHORIZED=YES_ONE_CELLULAR_MVP_SYSTEMIMAGE_AFTER_STATIC_GATE
N1I_C2_BUILD_RETRY_AUTHORIZED=YES_AFTER_STATIC_GATE_WITH_BOUND_NATIVE_PREFLIGHT
NETWORK_FETCH_AUTHORIZED=NO
DEVICE_CONTACT_AUTHORIZED=NO
REBOOT_AUTHORIZED=NO
FLASH_AUTHORIZED=NO
```

The authorization above is not unconditional: the driver must first complete
the bound read-only native preflight and produce
`PASS_CANDIDATE_ADMISSION_READY`. If that preflight fails, source mutation and
the system-image build remain unexecuted.

A successful build does **not** authorize flashing. The resulting image must
first pass the canonical read-only post-build linkage/content qualifier:

```bash
bash build/titan2/qualify-n1i-c2-postbuild-linkage.sh \
  --source-commit <40-hex-build-source> \
  --out-dir <source-scoped-C2-out> \
  --artifact-dir <sealed-C2-artifact-dir> \
  --expected-system-sha <build-reported-sha256> \
  --expected-system-bytes <build-reported-bytes>
```

This qualifier independently verifies the sealed artifact and 41-row receipt,
re-hashes all 33 final native targets (28 frozen-stock imports plus five Android
platform providers), rechecks IMS identity/signature and C2 content, and reuses
the sealed C1 Java/APEX runtime-linkage model against the exact C2
`PRODUCT_OUT`.

The fatal C1 member resolver remains unchanged. C2 accepts either
`PASS_ALL_RESOLVED` or the already-approved MVP full-classification case:
exactly eight unresolved IMS APK rows, all confined to
`kotlinx.coroutines.debug.internal.AgentPremain*` references to
`java.lang.instrument` / `sun.misc`, with zero unresolved members in the two
imported MediaTek boot JARs, zero TelephonyMetrics residual failure, zero
non-AgentPremain inbound DEX references, and
`BROAD_RUNTIME_FAILURE_SUPPRESSION=NO`. Any other unresolved shape is fatal.

The qualifier performs no build, network fetch, source mutation, device
contact, reboot, or flash. Only
`N1I_C2_POSTBUILD_LINKAGE_QUALIFICATION=PASS` advances the image to merge
review and the separately governed Titan flash-qualification lane.
