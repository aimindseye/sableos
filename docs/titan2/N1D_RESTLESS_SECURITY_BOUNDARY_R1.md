# Titan 2 N1D Restless/Treble security boundary

Status: **C3A Restless control admitted; C3B Sable runtime remains deny-by-default**

Date: 2026-10-01

## Decision

N1D C3A is rebaselined on the exact successful public RestlessOS/TrebleDroid
build topology. This corrects the earlier rule which prohibited using
`device/phh/treble` as build scaffolding and led to a handcrafted GSI product
that repeatedly entered the wrong Soong `aosp_system_image` dependency graph.

The roles are now separate:

```text
C2 diagnostic control
  pinned published RestlessOS Android 16 GSI
  security claim: NO
  Sable release artifact: NO

C3A build/compatibility control
  pinned GrapheneOS 2026061600 base
  - 54 exact Restless remove.xml projects
  + 12 pinned public TrebleDroid/PHH companion projects
  = 991 managed projects
  + exact RestlessOS 16.0.0-202606230923 patch tiers
  + device/phh/treble/generate.sh rom
  + generated treble_arm64_bvN-bp4a-user
  release eligible: NO

C3B Sable baseline/runtime
  no automatic admission from the C3 control patch stack
  release runtime allowlist starts at 0
  requires separate security/runtime closure
```

## Why the boundary changed

The successful Restless build does not use a small
`generic_system_arm64.mk + gsi_release.mk` product. It adds the TrebleDroid
source scaffold, applies five ordered patch tiers, runs the PHH/Treble generator,
and builds the generated `treble_arm64_bvN` product.

The exact Restless Graphene-GSI build patch also modifies
`build/make/target/product/gsi/Android.bp` to replace/remove the modules that
caused the handcrafted C3 build to fail:

```text
webview        -> TrichromeWebView
Browser2       -> TrichromeChrome
Camera2        -> removed from GSI dependency set
messaging      -> removed from GSI dependency set
QuickSearchBox -> removed from GSI dependency set
```

Therefore PHH/Treble build scaffolding is a required part of the known-good
control topology. Its presence is no longer treated as a security acceptance.

## Exact control patch stack

The control build applies the pinned Restless release tiers in this order:

```text
trebledroid          198
trebledroid-staging  121
rom                    29
personal               17
release-builds           4
                       ---
                       369
```

Those 369 patches are **control-build inputs**, not Sable release approvals.

The Sable release runtime patch allowlist remains:

```text
N1D_C3_RUNTIME_PATCH_ALLOWLIST_COUNT=0
```

Future Sable runtime admission is evidence-driven and patch-specific.

## PHH runtime security posture

The generated product inherits `device/phh/treble/base.mk`, which contains
universal-GSI compatibility behavior unsuitable as an unquestioned Sable
release baseline. Examples include SELinux neverallow bypass configuration,
unauthenticated/default ADB behavior, PHH root/securize/OTA/remote-debug tools,
legacy VNDK support, broad OEM compatibility payloads, and unrelated device
workarounds.

For the C3A control build:

```text
N1D_C3_PHH_BASE_RUNTIME_SECURITY_TRUST=NO
N1D_C3_PHH_INSECURE_DEFAULTS_REQUIRE_AUDIT=YES
N1D_C3_RELEASE_ELIGIBLE=NO
```

The release boundary remains fail-closed:

```text
SELINUX_IGNORE_NEVERALLOWS release allowed: NO
ro.adb.secure=0 release allowed: NO
PHH remote debug release allowed: NO
PHH su release allowed: NO
vendor/magisk release allowed: NO
PHH OTA release allowed: NO
```

## Public-source boundary

The C3A control is a public functional reproduction, not a bit-identical Restless release. The rebaseline uses only public source. The Restless private vendor repository
is deliberately omitted. The optional Pixel GSans include remains unresolved
because the source is absent and is not required to generate the control
product.

All Treble companion projects are pinned by exact commit rather than mutable
branch names.

## Authorization boundary

Static contracts and documentation authorize no build, device contact, flash,
or release. Source staging requires explicit source-mutation and network
authorization. The first target build is separately authorized and is limited
to `systemimage`.

The resulting control image must not be flashed or released as SableOS merely
because it compiles.


## C3B radio and runtime inheritance boundary

C3B does not inherit the complete C3A Restless patch stack. The earlier Titan 2
radio evidence remains the policy source:

```text
AOSP phone stack = source-built
stock telephony APK import = NO
stock MTK JAR/SO import = NO
full vendor copy into system = NO
stock vendor/kernel/firmware compatibility strategy = PRESERVE
MTK indication handling = INVESTIGATE
IMS/QNS/IWLAN = INVESTIGATE
persist.sys.phh.ims.mtk default = false
APN-only fix = NO
LTE-only fix = NO
```

A control patch enters C3B only after a reproduced failure and explicit review.
