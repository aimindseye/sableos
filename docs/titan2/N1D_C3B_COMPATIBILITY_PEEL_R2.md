# Titan 2 N1D C3B Compatibility Peel R2

Status: **R2 compatibility peel active on PR #234; next action is one exact-head systemimage attempt**

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

The authoritative decision ledger is:

```text
build/titan2/n1d-c3b-compatibility-peel-r2.tsv
```

## Newly admitted E1 compatibility

R2 adds two Sable-owned patches. Neither is a verbatim admission of a Restless
patch and neither increments the runtime patch allowlist.

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
non-Titan LGE vibrator quarantines        2
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

After exact-head static qualification, perform exactly one fresh
`systemimage` build. Do not run another patch-by-patch Restless replay.

The build driver applies the complete admitted R2 set before invoking Soong:

```text
2 scaffold/LGE quarantines
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
