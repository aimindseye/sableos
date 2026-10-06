# Titan 2 N1I-C2 Cellular MVP Implementation R1

Status: **build retry blocked pending sealed native install preflight admission; no device contact or flash**

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
   The first C2 build proved that installing all 33 wholesale is invalid:
   Kati rejected a duplicate final install destination at
   `/system/lib64/android.hardware.drm-V1-ndk.so` (M029). Before any retry,
   the read-only native-install preflight compares every frozen target against
   the exact sealed C1 image and the retained failed Kati graph. A byte-identical
   C1 target is a reuse candidate and must **not** be reinstalled by a Sable
   prebuilt; only a C1-absent target whose single graph owner is the exact Sable
   module is an import candidate. C1-present/different, C1-absent/colliding, or
   owner-identity mismatch states fail closed;
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

The canonical build driver remains:

```text
build/titan2/run-n1i-c2-cellular-mvp.sh
```

The driver starts with `NATIVE_ADMISSION_INTEGRATED=NO`. During an authorized
candidate run it must execute the complete read-only native-install preflight
**before app build, Android-source mutation, staging of the source delta, or
`make systemimage`**. Only a sealed
`PASS_CANDIDATE_ADMISSION_READY` result may transition that in-memory state to
`YES`.

The generated `native-packages.mk` contains only frozen-stock targets that the
preflight classifies as `IMPORT_FROZEN_STOCK`. Targets classified
`REUSE_C1_IDENTICAL` remain in the 33-target compatibility authority but are
not added as C2 install modules, so the existing platform/C1 owner supplies the
exact same bytes without a duplicate Kati rule.

The driver requires both:

```text
--authorize-source-mutation
--authorize-build
```

but operator retry authorization is a separate review decision. Before granting
that retry, the canonical preflight is run standalone and its complete 33-target
composition is reviewed.

Before mutation an authorized candidate run requires:

- exact SableOS source commit and clean worktree;
- the shared build-regression contract, including the native-install ownership
  invariant and singleton-driver invariant;
- a sealed native admission derived from the exact C1 baseline and the exact
  retained failed Kati graph;
- generated `native-packages.mk` containing only admitted imports;
  the known M029 `android.hardware.drm-V1-ndk.so` duplicate-target failure is
  an executable regression fixture and must classify as
  `REUSE_C1_IDENTICAL`;
- exact C3A managed-project authority;
- exact materialization and mutation-manifest seals;
- exact TelephonyMetrics, ImsPhoneCallTracker and PHH base blobs;
- exact PHH patch blob;
- fresh C2 output directory;
- implementation contract PASS.

The driver contains exactly one `systemimage` invocation. Build retry remains
unauthorized at this document state until a standalone preflight result is
reviewed. If any of the 33 targets is C1-different, has an unexpected install
owner, or cannot be classified in one pass, the retry remains blocked and the
full blocker set is resolved together. The previous Kati error is therefore
converted into pre-build regression memory rather than rediscovered during
packaging.

After the build it verifies:

- all 33 native outputs exist at the exact partition paths and retain their
  frozen SHA-256;
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
  mutation ID, including M004/M005/M006/M040/M041 rather than leaving those
  rows at proposal status;
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
SOURCE_MUTATION_AUTHORIZED=NO
BUILD_AUTHORIZED=NO
N1I_C2_BUILD_RETRY_AUTHORIZED=NO_PENDING_STANDALONE_PREFLIGHT_REVIEW
NETWORK_FETCH_AUTHORIZED=NO
DEVICE_CONTACT_AUTHORIZED=NO
REBOOT_AUTHORIZED=NO
FLASH_AUTHORIZED=NO
```

Only after the sealed native preflight is reviewed and its exact admission is
committed may a later transition authorize
`SOURCE_MUTATION_AUTHORIZED=YES_EXACT_C2_SET` and
`BUILD_AUTHORIZED=YES_ONE_CELLULAR_MVP_SYSTEMIMAGE`.

A successful build does **not** authorize flashing. The resulting image must
first pass post-build linkage/content qualification and then enter the governed
Titan flashing lane separately.
