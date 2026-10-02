# Titan 2 N1D C3B Compatibility Peel R2

Status: **R2 compatibility peel active on PR #234; E1 systemimage reached final ext4 packaging and exposed one PHH root-label mismatch; bounded retry fix admitted**

Date: 2026-10-02

## Purpose

C3B remains the actual SableOS baseline. R2 corrects the E1 execution model so
known C3A build compatibility is not rediscovered one failure at a time.

C3A proved that the pinned GrapheneOS / Treble topology can compile. C3B still
does **not** inherit the RestlessOS runtime or its 369-patch control stack.
Instead, R2 audits the complete repository-owned C3A compatibility-fix set and
admits only the smallest safe structural subset required by the C3B engineering
graph.

The full Restless control stack remains:

```text
trebledroid          198
trebledroid-staging  121
rom                    29
personal               17
release-builds           4
                       ---
                       369
```

It is control provenance, not a C3B admission list.

## R2 admission model

```text
C3A sealed control
      |
repository-owned C3A compatibility-fix audit
      |
classify before the next build
      |
+ build-environment fixes already admitted
+ narrow Graphene/Treble build-graph fixes
+ security-positive ADB-authentication fix
- Restless runtime/product/OEM/cellular policy
      |
one C3B systemimage attempt
```

The complete pinned 369-patch control corpus inventory is:

```text
build/titan2/n1d-c3a-control-patch-inventory-r2.tsv
```

Every Restless control patch is deny-by-default in that inventory and the count is bound to the five C3A tiers (198 + 121 + 29 + 17 + 4 = 369). No Restless patch is admitted verbatim by R2.

The focused semantic decision ledger for the 9 platform/build fixes, the 2 previously proven Soong host-layout fixes and the failure-derived PHH root-folder packaging fix is:

```text
build/titan2/n1d-c3b-compatibility-peel-r2.tsv
```

The legacy HIDL vibrator restoration is also explicitly rejected in the full inventory because C3B quarantines the non-Titan LGE consumer instead.

## Newly admitted E1 compatibility

R2 retains two Sable-owned build/make patches and now adds one failure-derived
PHH scaffold packaging patch. None is a verbatim admission of a Restless patch
and none increments the runtime patch allowlist.

### Graphene/Treble build graph

```text
patches/android-16-n1d-trebledroid/c3b-compat/
  0001-build-make-graphene-treble-graph.patch
```

It performs only these proven graph corrections:

```text
webview        -> TrichromeWebView
Browser2       -> TrichromeChrome
Camera2        -> removed from GSI dependency graph
messaging      -> removed from GSI dependency graph
QuickSearchBox -> removed from GSI dependency graph

aosp_shared_system_image -> disabled
  reason: Cuttlefish-only module; global Soong verification is unrelated to
          the active Treble system image
```

It deliberately does **not** inherit the broad application-removal policy from
the Restless Graphene-GSI patch. Sable application and product composition
remain E2-owned.

### ADB authentication

```text
patches/android-16-n1d-trebledroid/c3b-compat/
  0002-build-make-preserve-adb-auth.patch
```

The generic GSI `ro.adb.secure=0` override is removed. This is a
security-positive admission consistent with the existing C3B rule that
unauthenticated/default ADB is not acceptable.

### PHH root-folder SELinux label alignment

The E1 systemimage build completed compilation and reached final ext4 image
construction before `e2fsdroid` failed while looking up a label for
`/bt_firmware`.

The pinned PHH `board-base.mk` creates:

```text
bt_firmware sec_storage efs persist
```

but the C3B hardening deliberately removes `device/phh/treble/sepolicy`.
The dropped PHH file-context set is the sole owner of the legacy
`/bt_firmware` and `/sec_storage` labels. Re-enabling the broad PHH policy or
inventing new SELinux types would widen C3B security scope.

The bounded repair is:

```text
patches/android-16-n1d-trebledroid/scaffold-compat/
  0003-device-phh-drop-unlabeled-root-extra-folders.patch

before: BOARD_ROOT_EXTRA_FOLDERS += bt_firmware sec_storage efs persist
after:  BOARD_ROOT_EXTRA_FOLDERS += efs persist
```

`/efs` is already label-owned by platform sepolicy and `/persist` by the
generic arm64 GSI board policy, so they are retained. The two PHH-only unlabeled
root folders are removed. This is build/image-layout compatibility evidence,
not physical-runtime qualification; Titan runtime validation remains NO.

## Explicitly rejected or deferred

R2 makes these decisions before another build:

```text
Remove llkd                         REJECT
Exclude AOSP APN list               REJECT
OPlus my_manifest workaround        REJECT_NON_TITAN
init.vndk-nodef runtime behavior    DEFER_EVIDENCE
VNDK 28 SEPolicy build-side change  DEFER_ATOMIC_PAIR
LogViewer removal                    DEFER_E2
```

The APN decision is intentional. Titan N1C evidence says APN ownership should
be deduplicated while retaining a final `apns-conf.xml`; the Restless
remove-the-APN-list policy is therefore not imported into C3B.

VNDK 28 compatibility remains atomic: the build-side
`PLATFORM_SEPOLICY_COMPAT_VERSIONS` change cannot enter without the matching
28.0 CIL policy.

## Existing C3B admissions retained

R2 retains, without widening them:

```text
PHH base security/control reductions     14
Soong host-layout build fixes             2
scaffold compatibility patches            3
  non-Titan LGE vibrator quarantines      2
  unlabeled PHH root-folder quarantine    1
new build/make compatibility patches      2
runtime patch allowlist                    0
Restless patches applied verbatim          0
```

The LGE quarantine remains narrowly scoped to the non-Titan
`vendor.lge.hardware.vibrator@1.0` / `vibrator-lge` graph.

## Cellular boundary

R2 does not attempt to fix cellular runtime behavior. It specifically avoids
copying Restless product/runtime assumptions into that problem.

C3B continues to require:

```text
AOSP phone stack                    SOURCE_BUILT
stock telephony APK import          NO
stock MTK JAR/SO import             NO
full stock vendor copy              NO
stock vendor/kernel/firmware        PRESERVE
PHH MTK IMS default                 false
APN-only explanation                NO
LTE-only explanation                NO
MTK indication handling             INVESTIGATE
IMS/QNS/IWLAN                       INVESTIGATE
```

A later physical-runtime phase may admit a bounded cellular/IMS correction only
from Titan evidence.

## Next build rule

After exact-head static qualification, retry exactly one fresh `systemimage`
build with the failure-derived root-folder compatibility patch. Do not run
another patch-by-patch Restless replay.

The build driver applies the complete admitted R2 set before invoking Soong:

```text
3 scaffold compatibility patches
  2 non-Titan LGE quarantines
  1 PHH unlabeled-root-folder quarantine
2 Soong host-layout fixes
2 build/make R2 compatibility patches
```

The existing PHH base hardening is already staged by the prep driver.

Still prohibited:

```text
network fetch during build
TrebleApp build
target-files
OTA
dist
device contact
flash
signing
physical runtime
release
```

The runtime patch allowlist remains exactly zero.
