# Titan 2 N1D C3 product composition R1

Status: **C3A sealed; C3B E1 active engineering composition**

Date: 2026-10-02

## Current architecture

C3 is split into two deliberately different roles.

~~~text
C3A
  historical public-functional Restless/TrebleDroid build control
  sealed systemimage evidence
  not the Sable baseline

C3B E1
  active non-release engineering baseline
  pinned GrapheneOS Android 16
  minimal pinned Treble build scaffold
  exact Sable security reduction of the pinned PHH base
  zero Restless runtime patches
  generated Treble engineering identity

C3B E2
  Sable product identity and source-module admission
  Launcher3-hosted Sable Start
  product/partition ownership
  parallel-product source integration
~~~

The earlier handcrafted product "sable_titan2_n1d_arm64" remains retired.
Live C3A work proved that the direct handcrafted
"generic_system_arm64 + gsi_release" graph did not match the pinned GrapheneOS
source graph. E1 therefore keeps the proven Treble generator topology while
removing unwanted PHH runtime/security policy before generation.

## C3A sealed control

C3A used:

~~~text
1,033 sealed Graphene projects
-   54 exact Restless remove.xml projects
=  979 retained Graphene projects
+   12 pinned public Treble/PHH additions
=  991 managed C3A projects
+   369 pinned Restless control patches
+   generate.sh rom
->  treble_arm64_bvN-bp4a-user
->  systemimage
~~~

The successful sealed image is:

~~~text
SYSTEM_SHA256=4c292b9876a43f8df515a163a197e92d71deba598767790681f999ea3c554c16
SYSTEM_BYTES=3146977280
N1D_C3A_CONTROL_EVIDENCE=PASS
N1D_C3A_RELEASE_ELIGIBLE=NO
~~~

C3A remains evidence. It is not flashed and is not the current product lane.

## C3B E1 source graph

E1 creates a separate clean Android workspace from the same pinned GrapheneOS
Android 16 manifest:

~~~text
GrapheneOS tag:      2026061600
manifest commit:     5d82aa9610855bc0b43b9eb7ca4470d30455cfeb
base projects:       1033
Graphene removals:   0
~~~

It adds only five pinned scaffold projects:

~~~text
device/phh/treble
prebuilts/vndk/v28
prebuilts/vndk/v29
vendor/interfaces
vendor/lptools
~~~

Result:

~~~text
1033 + 5 = 1038 managed C3B E1 projects
~~~

The C3A Restless 54-project removal set is not inherited.

The following C3A additions are not part of the E1 scaffold:

~~~text
packages/apps/QcRilAm
prebuilts/vndk/v30
treble_app
vendor/apn
vendor/hardware_overlay
vendor/magisk
vendor/vndk-tests
~~~

The exact decision ledger is:

~~~text
build/titan2/n1d-c3b-scaffold-decisions.tsv
~~~

## PHH base hardening

E1 does not rely on a later product fragment to undo PHH base content.
Android product inheritance is resolved after inheritance tags are recorded, so
post-inheritance filtering is not treated as an authoritative removal
mechanism.

Instead E1 modifies the exact pinned "device/phh/treble/base.mk" before product
generation with:

~~~text
build/titan2/apply-n1d-c3b-phh-base-hardening.py
~~~

The hardening is content-addressed:

~~~text
device/phh/treble commit:
39ba82ef89ff5bf6b22ca8f147dbf317bffa20ed

base.mk input blob:
a29e402009d449150f1216e5d517ec0c9b36bfbd

base.mk hardened blob:
58edfb8713e9a1392daaf5bbf0d07778efd6d669

hardening transforms:
14
~~~

The hardening removes broad PHH runtime/security policy that is not accepted as
Sable policy for the first engineering image, including:

- PHH private sepolicy and generic external hardware-overlay inheritance;
- unauthenticated/default ADB settings;
- PHH rw-system, boot/data and property-handler hooks;
- TWRP/busybox payloads;
- SELinux neverallow bypass;
- PHH MTK SMS helper;
- resetprop/securize/PHH OTA/remove-telephony payloads;
- PHH adbd override;
- TrebleApp privileged permission/sysconfig payloads;
- PHH remote-debug payloads;
- QcRilAm;
- Samsung boot helper and PHH MTK in-call helper.

E1 deliberately retains "Iwlan", "QualifiedNetworksService", and the pinned VNDK
compatibility substrate because they are part of the first build/radio
compatibility baseline. Runtime behavior is still unproven.

This Sable-owned base hardening is baseline policy, not a Restless compatibility
patch admission. Therefore:

~~~text
N1D_C3B_RESTLESS_PATCH_COUNT=0
N1D_C3B_RUNTIME_PATCH_ALLOWLIST_COUNT=0
~~~

## Generator and first engineering identity

The E1 generator config is intentionally composition-neutral:

~~~text
build/titan2/n1d-c3b-engineering.mk
~~~

It does not add Sable applications or final product identity. It exists as the
named Treble generator configuration after base hardening.

The first E1 identity is:

~~~text
generator:       device/phh/treble/generate.sh
config:          sable-c3b-engineering
product:         treble_arm64_bvN
device:          tdgsi_arm64_ab
release config:  bp4a
variant:         userdebug
goal:            systemimage
~~~

Final Sable identity and source-module admission are E2 work.

## Host-layout compatibility

Two C3A-discovered Soong fixes are reused only as build-environment
compatibility fixes for the canonical out-of-tree OUT_DIR:

~~~text
0001-soong-ci-tests-skip-out-of-tree-host-paths.patch
0002-soong-dexpreopt-gen-support-out-of-tree-product-packages.patch
~~~

They remain exact blob-pinned and do not count as C3B runtime patch admission.

## Preparation and parse

Offline preflight:

~~~bash
bash build/titan2/prepare-n1d-c3b-engineering.sh preflight
~~~

Initialize the separate workspace:

~~~bash
bash build/titan2/prepare-n1d-c3b-engineering.sh   init-base   --authorize-network   --authorize-source-mutation
~~~

Synchronize and seal the exact 1,033-project Graphene base:

~~~bash
bash build/titan2/prepare-n1d-c3b-engineering.sh   sync-base   --authorize-network   --authorize-source-mutation
~~~

Stage the five pinned scaffold projects, harden PHH base, and generate the
engineering product:

~~~bash
bash build/titan2/prepare-n1d-c3b-engineering.sh   stage   --authorize-network   --authorize-source-mutation
~~~

Offline verify:

~~~bash
bash build/titan2/prepare-n1d-c3b-engineering.sh verify
~~~

Parse without target compilation:

~~~bash
bash build/titan2/qualify-n1d-c3b-product-parse.sh   --authorize-product-parse
~~~

## First compile

After parse PASS:

~~~bash
bash build/titan2/build-n1d-c3b-systemimage.sh   --authorize-c3b-compile   --authorize-host-layout-source-mutation   --jobs 16
~~~

The build driver accepts no network authorization and invokes exactly one Android
target goal:

~~~text
make systemimage
~~~

It does not authorize target-files, OTA, dist, signing, device contact, flash,
or physical runtime.

## Release and runtime status

E1 is deliberately non-release:

~~~text
N1D_C3B_DEVICE_CONTACT_AUTHORIZED=NO
N1D_C3B_FLASH_AUTHORIZED=NO
N1D_C3B_SIGNING_AUTHORIZED=NO
N1D_C3B_PHYSICAL_RUNTIME_AUTHORIZED=NO
N1D_C3B_RELEASE_ELIGIBLE=NO
~~~

If parse or compile fails, the failure becomes C3B evidence. Do not restore the
C3A stack wholesale. Admit only the smallest reviewed compatibility change
supported by the failure.

E2 begins after the E1 build baseline is understood and owns Sable
product/source-module admission.
